import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/json.{int, string}
import gleam/list
import gleam/time/timestamp

import http_utils
import log
import utils

const base_url: String = "http://127.0.0.1:8000"

const prefix_length: Int = 6

const min_subreddits_count: Int = 20

const max_subreddits_count: Int = 100

pub fn bootstrap_simulation(num_users: Int) -> Nil {
  let start_time: Float = timestamp.to_unix_seconds(timestamp.system_time())

  log.info("Creating " <> int.to_string(num_users) <> " user accounts")
  create_users(num_users)

  let num_subreddits: Int =
    int.random(max_subreddits_count - min_subreddits_count + 1)
    + min_subreddits_count
  log.info("Creating " <> int.to_string(num_subreddits) <> " subreddits")
  create_subreddits(num_subreddits, num_users)

  log.info(
    "Simulating user subscriptions to subreddits using ZIPF distribution",
  )
  simulate_zipf_subscription(num_users)

  log.info(
    "Time taken for creation: "
    <> float.to_string(utils.get_time_difference(start_time)),
  )
}

// Signup <num_users> for simulation
fn create_users(num_users: Int) -> Nil {
  let waiting_subj: Subject(Bool) = process.new_subject()

  list.each(list.range(1, num_users), fn(user_idx: Int) {
    let payload: String =
      json.object([
        #("username", string(utils.user_prefix <> int.to_string(user_idx))),
        #("password", string("password")),
      ])
      |> json.to_string

    process.spawn(fn() {
      let _ = http_utils.post_request(base_url <> "/sign-up", payload, [])
      process.send(waiting_subj, True)
    })
  })

  wait_till_completion(waiting_subj, num_users)
}

fn create_subreddits(num_subreddits: Int, num_users: Int) -> Nil {
  let waiting_subj: Subject(Bool) = process.new_subject()

  list.each(list.range(1, num_subreddits), fn(rank: Int) {
    let payload: String =
      json.object([
        #(
          "name",
          string(utils.generate_hex_string(
            prefix_length,
            utils.subreddit_prefix,
          )),
        ),
        #("username", string(utils.get_random_username(num_users))),
        #("rank", int(rank)),
      ])
      |> json.to_string
    process.spawn(fn() {
      let _ =
        http_utils.post_request(base_url <> "/create-subreddit", payload, [])
      process.send(waiting_subj, True)
    })
  })

  wait_till_completion(waiting_subj, num_subreddits)
}

fn simulate_zipf_subscription(num_users: Int) -> Nil {
  let subreddits_feed: List(#(String, Int)) = get_subreddits(False)
  let total_weight: Float =
    list.fold(
      subreddits_feed,
      0.0,
      fn(acc_rank: Float, subreddit_state: #(String, Int)) {
        let #(_, rank) = subreddit_state
        acc_rank +. utils.zipf_weight(rank)
      },
    )

  let waiting_subj: Subject(Bool) = process.new_subject()

  list.fold(
    subreddits_feed,
    1,
    fn(next_user_idx, subreddit_info: #(String, Int)) {
      let weight: Float = utils.zipf_weight(subreddit_info.1)

      let current_subreddit_users: Int =
        float.round({ weight /. total_weight } *. int.to_float(num_users))

      list.each(
        list.range(
          next_user_idx,
          int.min(next_user_idx + current_subreddit_users - 1, num_users),
        ),
        fn(user_idx: Int) {
          let payload: String =
            json.object([
              #("name", string(subreddit_info.0)),
              #(
                "username",
                string(utils.user_prefix <> int.to_string(user_idx)),
              ),
            ])
            |> json.to_string
          process.spawn(fn() {
            let _ =
              http_utils.post_request(
                base_url <> "/join-subreddit",
                payload,
                [],
              )
            process.send(waiting_subj, True)
          })
        },
      )

      next_user_idx + current_subreddit_users
    },
  )

  wait_till_completion(waiting_subj, num_users)
}

fn get_subreddits(sort: Bool) -> List(#(String, Int)) {
  case http_utils.get_request(base_url <> "/subreddits", []) {
    Ok(request_body) -> {
      case
        json.parse(
          request_body,
          decode.list({
            use name <- decode.field("name", decode.string)
            use rank <- decode.field("rank", decode.int)
            decode.success(#(name, rank))
          }),
        )
      {
        Ok(subreddits) -> {
          case sort {
            True ->
              list.sort(subreddits, fn(sr1, sr2) { int.compare(sr1.1, sr2.1) })
            False -> subreddits
          }
        }
        Error(_) -> []
      }
    }
    Error(_) -> []
  }
}

fn wait_till_completion(waiting_subj: Subject(Bool), total_workers: Int) -> Nil {
  case process.receive(waiting_subj, within: 1500) {
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
