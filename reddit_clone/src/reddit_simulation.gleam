import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/json.{int, string}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/time/timestamp
import glearray.{type Array}

import http_utils
import log
import server/server_worker.{type SubRedditInfo}
import utils

const base_url: String = "http://127.0.0.1:8000"

const prefix_length: Int = 6

const min_subreddits_count: Int = 20

const max_subreddits_count: Int = 100

pub fn bootstrap(num_users: Int) -> Nil {
  let start_time: Float = timestamp.to_unix_seconds(timestamp.system_time())

  log.heading("Creating " <> int.to_string(num_users) <> " user accounts")
  create_users(num_users)

  let num_subreddits: Int =
    int.random(max_subreddits_count - min_subreddits_count + 1)
    + min_subreddits_count
  log.heading("Creating " <> int.to_string(num_subreddits) <> " subreddits")
  create_subreddits(num_subreddits, num_users)

  log.heading(
    "Simulating user subscriptions to subreddits using ZIPF distribution",
  )
  simulate_zipf_subscription(num_users)

  log.info(
    "Time taken for creation: "
    <> float.to_string(utils.get_time_difference(start_time)),
  )

  log.heading("Simulalting user actions")
  spawn_action_simulations(num_users)
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

fn simulate_actions(num_users: Int, choice: Option(Int)) -> Nil {
  let action_choice: Int = case choice {
    Some(d_choice) -> d_choice
    None -> int.random(2) + 1
  }
  log.info("Simulating action - " <> int.to_string(action_choice))

  case action_choice {
    1 -> {
      // Join SubReddit
      case get_random_subreddit() {
        Ok(random_subreddit) -> {
          let payload: String =
            json.object([
              #("name", string(random_subreddit.0)),
              #("username", string(get_random_username(num_users))),
            ])
            |> json.to_string
          process.spawn(fn() {
            let _ =
              http_utils.post_request(
                base_url <> "/join-subreddit",
                payload,
                [],
              )
          })
          Nil
        }
        Error(_) -> simulate_actions(num_users, None)
      }
    }
    2 -> {
      // Leave SubReddit
      let username: String = get_random_username(num_users)
      case
        http_utils.get_request(base_url <> "/user-subreddits/" <> username, [])
      {
        Ok(request_body) -> {
          case json.parse(request_body, decode.list(decode.string)) {
            Ok(user_subreddits) -> {
              let subreddits_length: Int = list.length(user_subreddits)
              case subreddits_length > 0 {
                True -> {
                  case
                    glearray.get(
                      glearray.from_list(user_subreddits),
                      int.random(subreddits_length),
                    )
                  {
                    Ok(subreddit_name) -> {
                      let payload: String =
                        json.object([
                          #("name", string(subreddit_name)),
                          #("username", string(username)),
                        ])
                        |> json.to_string
                      process.spawn(fn() {
                        let _ =
                          http_utils.post_request(
                            base_url <> "/leave-subreddit",
                            payload,
                            [],
                          )
                      })
                      Nil
                    }
                    Error(_) -> simulate_actions(num_users, Some(action_choice))
                  }
                }
                False -> simulate_actions(num_users, None)
              }
              log.info(
                "Got user subreddits: "
                <> int.to_string(list.length(user_subreddits)),
              )
            }
            Error(_) -> Nil
          }
        }
        Error(_) -> Nil
      }
    }
    _ -> simulate_actions(num_users, None)
  }
}

fn spawn_action_simulations(num_users) -> Nil {
  process.spawn(fn() { simulate_actions(num_users, None) })
  spawn_action_simulations(num_users)
}

// fn simulate_action() {
// LogInUser
// SignOutUser
// PostInSubreddit
// CommentOnPost
// Vote
// MessageUser
// ReplyUser
// }

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

fn get_random_username(num_users: Int) -> String {
  utils.user_prefix <> int.to_string(int.random(num_users) + 1)
}

fn get_random_subreddit() -> Result(SubRedditInfo, Nil) {
  let subreddit_feed: Array(SubRedditInfo) =
    glearray.from_list(get_subreddits(True))

  let random_idx: Int = case int.random(4) {
    1 -> int.random(glearray.length(subreddit_feed))
    _ -> int.random(min_subreddits_count)
  }
  glearray.get(subreddit_feed, random_idx)
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
