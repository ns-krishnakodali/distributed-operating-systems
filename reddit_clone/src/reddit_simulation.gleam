import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/list

import logging
import server_worker.{type ServerWorkerSubject}
import utils

const prefix_length: Int = 6

const min_subreddits_count: Int = 20

const max_subreddits_count: Int = 100

pub fn bootstrap_simulation(num_users: Int) -> Nil {
  logging.log_heading("Starting simulation")
  let server_subj: ServerWorkerSubject = server_worker.start_and_get_subj()

  logging.info("Creating " <> int.to_string(num_users) <> " users")
  create_users(server_subj, num_users)

  let num_subreddits: Int =
    int.random(max_subreddits_count - min_subreddits_count + 1)
    + min_subreddits_count
  logging.info("Creating " <> int.to_string(num_subreddits) <> " subreddits")
  create_subreddits(server_subj, num_subreddits, num_users)

  logging.info(
    "Simulating user subscriptions to subreddits using ZIPF distribution",
  )
  simulate_zipf_subscription(server_subj, num_users)

  process.send(server_subj, server_worker.Shutdown)
}

// Signup <num_users> for simulation
fn create_users(server_subj: ServerWorkerSubject, num_users: Int) -> Nil {
  let waiting_subj: Subject(Bool) = process.new_subject()
  list.each(list.range(1, num_users), fn(user_idx: Int) {
    process.send(
      server_subj,
      server_worker.SignUpUser(
        waiting_subj,
        utils.user_prefix <> int.to_string(user_idx),
        "password",
      ),
    )
  })

  wait_till_completion(waiting_subj, num_users)
}

fn create_subreddits(
  server_subj: ServerWorkerSubject,
  num_subreddits: Int,
  num_users: Int,
) -> Nil {
  let retry_ranks_list: List(Int) =
    list.fold(list.range(1, num_subreddits), [], fn(attempt_ranks, rank) {
      case
        process.call(server_subj, 100, server_worker.CreateSubReddit(
          _,
          utils.generate_hex_string(prefix_length, utils.subreddit_prefix),
          utils.get_random_username(num_users),
          rank,
        ))
      {
        True -> attempt_ranks
        False -> list.append(attempt_ranks, [rank])
      }
    })

  // Attempt creating subreddits from retry ranks list
  case list.length(retry_ranks_list) > 0 {
    True -> {
      list.each(retry_ranks_list, fn(rank: Int) {
        let _ =
          process.call(server_subj, 100, server_worker.CreateSubReddit(
            _,
            utils.generate_hex_string(prefix_length, utils.subreddit_prefix),
            utils.get_random_username(num_users),
            rank,
          ))
      })
    }
    False -> Nil
  }
}

fn simulate_zipf_subscription(
  server_subj: ServerWorkerSubject,
  num_users: Int,
) -> Nil {
  let waiting_subj: Subject(Bool) = process.new_subject()
  let subreddits_feed: List(#(String, Int)) =
    process.call(server_subj, 100, server_worker.GetSubRedditsFeed)

  let total_rank: Float =
    list.fold(
      subreddits_feed,
      0.0,
      fn(acc_rank: Float, subreddit_state: #(String, Int)) {
        let #(_, rank) = subreddit_state
        acc_rank +. 1.0 /. int.to_float(rank)
      },
    )

  echo total_rank
  let _ =
    list.fold(
      subreddits_feed,
      1,
      fn(acc_users: Int, subreddit_state: #(String, Int)) {
        let #(subreddit_name, rank): #(String, Int) = subreddit_state
        let updated_users: Int =
          int.min(
            acc_users
              + float.round(
              { { 1.0 /. { int.to_float(rank) } *. total_rank } }
              *. int.to_float(num_users),
            ),
            num_users + 1,
          )
        echo #(acc_users, updated_users)
        case acc_users < updated_users {
          True -> {
            process.spawn(fn() {
              join_subreddit(
                server_subj,
                waiting_subj,
                subreddit_name,
                acc_users,
                updated_users,
              )
            })
            Nil
          }
          False -> Nil
        }

        updated_users
      },
    )

  wait_till_completion(waiting_subj, num_users)
}

fn join_subreddit(
  server_subj: ServerWorkerSubject,
  waiting_subj: Subject(Bool),
  subreddit_name: String,
  start_idx: Int,
  end_idx: Int,
) {
  list.each(list.range(start_idx, end_idx - 1), fn(idx: Int) {
    process.send(
      server_subj,
      server_worker.JoinSubReddit(
        waiting_subj,
        subreddit_name,
        utils.user_prefix <> int.to_string(idx),
      ),
    )
  })
}

fn wait_till_completion(waiting_subj: Subject(Bool), total_workers: Int) -> Nil {
  case process.receive(waiting_subj, within: 5000) {
    Ok(sent) -> sent
    Error(_) -> False
  }

  case total_workers > 1 {
    True -> wait_till_completion(waiting_subj, total_workers - 1)
    False -> {
      Nil
    }
  }
}
