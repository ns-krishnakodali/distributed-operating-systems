import gleam/bit_array
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/json.{int, string}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/time/timestamp
import glearray.{type Array}
import lib/rsa

import lib/http_client
import log
import server/server_worker.{
  type CommentInfo, type PostInfo, type SubRedditInfo, type UserInfo,
}
import utils

const base_url: String = "http://127.0.0.1:8000"

const prefix_length: Int = 6

const min_subreddits_count: Int = 20

const max_subreddits_count: Int = 100

const min_pc_interaction: Int = 10

const actions_count: Int = 16

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
  process.spawn(spawn_action_simulations)

  Nil
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
      let _ = http_client.post(base_url <> "/sign-up", payload, [])
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
        #(
          "username",
          string(utils.user_prefix <> int.to_string(int.random(num_users) + 1)),
        ),
        #("rank", int(rank)),
      ])
      |> json.to_string
    process.spawn(fn() {
      let _ = http_client.post(base_url <> "/create-subreddit", payload, [])
      process.send(waiting_subj, True)
    })
  })

  wait_till_completion(waiting_subj, num_subreddits)
}

fn simulate_zipf_subscription(num_users: Int) -> Nil {
  let subreddits_feed: List(SubRedditInfo) = get_subreddits(False)
  let total_weight: Float =
    list.fold(
      subreddits_feed,
      0.0,
      fn(acc_rank: Float, subreddit_state: SubRedditInfo) {
        let #(_, rank) = subreddit_state
        acc_rank +. utils.zipf_weight(rank)
      },
    )

  let waiting_subj: Subject(Bool) = process.new_subject()

  list.fold(
    subreddits_feed,
    1,
    fn(next_user_idx, subreddit_info: SubRedditInfo) {
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
            let _ = http_client.post(base_url <> "/join-subreddit", payload, [])
            process.send(waiting_subj, True)
          })
        },
      )

      next_user_idx + current_subreddit_users
    },
  )

  wait_till_completion(waiting_subj, num_users)
}

fn simulate_actions(choice: Option(Int)) -> Nil {
  let action_choice: Int = case choice {
    Some(d_choice) -> d_choice
    // None -> int.random(actions_count) + 1
    None -> int.random(actions_count) + 1
  }
  log.info("Simulating action - " <> int.to_string(action_choice))

  case action_choice {
    1 -> {
      // Login User
      log.info("Action: Logging User")

      let inactive_users: Array(UserInfo) = glearray.from_list(get_users(False))
      let inactive_users_length: Int = glearray.length(inactive_users)
      case inactive_users_length > 0 {
        True -> {
          let random_idx: Int = int.random(inactive_users_length)
          case glearray.get(inactive_users, random_idx) {
            Ok(user_info) -> {
              let #(username, _, _) = user_info
              let payload: String =
                json.object([
                  #("username", string(username)),
                  #("password", string("password")),
                ])
                |> json.to_string
              process.spawn(fn() {
                let _ = http_client.post(base_url <> "/login", payload, [])
              })
              Nil
            }
            Error(_) -> simulate_actions(Some(action_choice))
          }
        }
        False -> Nil
      }
    }
    2 -> {
      // Sign out User
      log.info("Action: Signing out User")

      let active_users: Array(UserInfo) = glearray.from_list(get_users(True))
      let active_users_length: Int = glearray.length(active_users)
      case active_users_length > 0 {
        True -> {
          let random_idx: Int = int.random(glearray.length(active_users))
          case glearray.get(active_users, random_idx) {
            Ok(user_info) -> {
              let #(username, _, _) = user_info
              let payload: String =
                json.object([
                  #("username", string(username)),
                  #("password", string("password")),
                ])
                |> json.to_string
              process.spawn(fn() {
                let _ = http_client.post(base_url <> "/sign-out", payload, [])
              })
              Nil
            }
            Error(_) -> simulate_actions(Some(action_choice))
          }
        }
        False -> Nil
      }
    }
    3 -> {
      // Join SubReddit
      log.info("Action: Joining SubReddit")

      let username: String = get_random_active_username()
      let random_subreddit_info: Result(SubRedditInfo, Nil) =
        get_random_subreddit()
      case random_subreddit_info {
        Ok(random_subreddit) -> {
          let payload: String =
            json.object([
              #("name", string(random_subreddit.0)),
              #("username", string(username)),
            ])
            |> json.to_string
          process.spawn(fn() {
            let _ = http_client.post(base_url <> "/join-subreddit", payload, [])
          })
          Nil
        }
        Error(_) -> simulate_actions(None)
      }
    }
    4 -> {
      // Leave SubReddit
      log.info("Action: Leaving SubReddit")

      let username: String = get_random_active_username()
      case http_client.get(base_url <> "/user-subreddits/" <> username, []) {
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
                          http_client.post(
                            base_url <> "/leave-subreddit",
                            payload,
                            [],
                          )
                      })
                      Nil
                    }
                    Error(_) -> simulate_actions(Some(action_choice))
                  }
                }
                False -> simulate_actions(None)
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
    _ -> {
      case int.random(actions_count) {
        1 | 2 | 3 -> {
          // Message User
          let active_users: Array(UserInfo) =
            glearray.from_list(get_users(True))
          case glearray.length(active_users) > 2 {
            True -> {
              let sender_username: String = get_random_user(active_users).0
              let receiver_username: String = get_random_user(active_users).0

              process.spawn(fn() {
                log.info("Action: Messaging User")

                let payload: String =
                  json.object([
                    #("sender_username", string(sender_username)),
                    #("receiver_username", string(receiver_username)),
                    #(
                      "message",
                      string(
                        utils.message_prefix <> " from " <> sender_username,
                      ),
                    ),
                  ])
                  |> json.to_string
                let _ =
                  http_client.post(base_url <> "/message-user", payload, [])
              })
              Nil
            }
            False -> simulate_actions(Some(action_choice))
          }
        }
        4 | 5 -> {
          // Reply to Messages
          let random_username: String = get_random_active_username()

          case
            http_client.get(
              base_url <> "/unread-messages/" <> random_username,
              [],
            )
          {
            Ok(request_body) -> {
              case
                json.parse(
                  request_body,
                  decode.list({
                    use sender_username <- decode.field(
                      "sender_username",
                      decode.string,
                    )
                    use message <- decode.field("message", decode.string)
                    use timestamp <- decode.field("timestamp", decode.float)
                    decode.success(#(sender_username, message, timestamp))
                  }),
                )
              {
                Ok(unread_messages) -> {
                  let messages_length: Int = list.length(unread_messages)
                  case messages_length > 0 {
                    True -> {
                      case
                        glearray.get(
                          glearray.from_list(unread_messages),
                          int.random(messages_length),
                        )
                      {
                        Ok(message_info) -> {
                          let #(sender_username, _, _) = message_info

                          process.spawn(fn() {
                            log.info("Action: Replying to Messages")

                            let payload: String =
                              json.object([
                                #("sender_username", string(random_username)),
                                #("receiver_username", string(sender_username)),
                                #(
                                  "message",
                                  string(
                                    utils.message_prefix
                                    <> " reply from "
                                    <> random_username,
                                  ),
                                ),
                              ])
                              |> json.to_string
                            let _ =
                              http_client.post(
                                base_url <> "/message-user",
                                payload,
                                [],
                              )
                          })
                          Nil
                        }
                        Error(_) -> simulate_actions(Some(action_choice))
                      }
                    }
                    False -> simulate_actions(Some(action_choice))
                  }
                }
                Error(_) -> Nil
              }
            }
            Error(_) -> simulate_actions(Some(action_choice))
          }
        }
        6 -> {
          // Download Post
          let posts_feed: Array(PostInfo) = glearray.from_list(get_posts(None))
          case glearray.length(posts_feed) > 0 {
            True -> {
              case
                glearray.get(
                  posts_feed,
                  int.random(glearray.length(posts_feed)),
                )
              {
                Ok(random_post_info) -> {
                  let active_users: Array(UserInfo) =
                    glearray.from_list(get_users(True))

                  let random_user_info: UserInfo = get_random_user(active_users)

                  process.spawn(fn() {
                    log.info("Action: Downloading Post")

                    let payload: String =
                      json.object([
                        #("post_id", string(random_post_info.1)),
                        #("username", string(random_user_info.0)),
                      ])
                      |> json.to_string

                    case
                      http_client.post(
                        base_url <> "/download-post",
                        payload,
                        [],
                      )
                    {
                      Ok(response_body) -> {
                        case
                          json.parse(response_body, {
                            use signature <- decode.field(
                              "signature",
                              decode.string,
                            )
                            use post_id <- decode.field(
                              "post_id",
                              decode.string,
                            )
                            use created_username <- decode.field(
                              "created_username",
                              decode.string,
                            )
                            use post_description <- decode.field(
                              "post_description",
                              decode.string,
                            )
                            use karma <- decode.field("karma", decode.int)
                            decode.success(#(
                              signature,
                              post_id,
                              created_username,
                              post_description,
                              karma,
                            ))
                          })
                        {
                          Ok(download_info) -> {
                            let signature: String = download_info.0
                            case signature {
                              "" ->
                                log.error(
                                  "Downloading post "
                                  <> random_post_info.1
                                  <> " failed",
                                )
                              _ -> {
                                let der: BitArray = case
                                  bit_array.base16_decode(random_user_info.1)
                                {
                                  Ok(decoded_der) -> decoded_der
                                  Error(_) -> <<>>
                                }
                                let pem: String = random_user_info.2

                                let assert Ok(decoded_signature) =
                                  bit_array.base16_decode(signature)
                                case
                                  rsa.verify_message(
                                    bit_array.from_string(download_info.1),
                                    rsa.PublicKey(der:, pem:),
                                    decoded_signature,
                                  )
                                {
                                  Ok(status) ->
                                    case status {
                                      True ->
                                        log.info(
                                          "Downloaded post "
                                          <> download_info.1
                                          <> " successfully by "
                                          <> download_info.2,
                                        )
                                      False -> {
                                        log.error(
                                          "Downloading failed for post "
                                          <> download_info.1,
                                        )
                                        simulate_actions(Some(action_choice))
                                      }
                                    }

                                  Error(err) -> {
                                    log.error(
                                      "An issue occurred when downloading the post: "
                                      <> err,
                                    )
                                    simulate_actions(Some(action_choice))
                                  }
                                }
                              }
                            }
                          }
                          Error(_) -> Nil
                        }
                      }
                      Error(_) -> simulate_actions(Some(action_choice))
                    }
                  })
                  Nil
                }
                Error(_) -> simulate_actions(None)
              }
            }
            False -> simulate_actions(None)
          }
        }
        _ -> {
          // Interactive actions
          log.info("Performing interactive actions")

          case utils.random_boolean() {
            True -> {
              let random_subreddit_info: Result(SubRedditInfo, Nil) =
                get_random_subreddit()
              case random_subreddit_info {
                Ok(subreddit_info) -> {
                  let subreddit_name: String = subreddit_info.0

                  // Post in SubReddit
                  process.spawn(fn() {
                    log.info("Action: Posting in SubReddit")

                    let random_username: String = get_random_active_username()
                    let payload: String =
                      json.object([
                        #("name", string(subreddit_name)),
                        #("username", string(random_username)),
                        #(
                          "post_description",
                          string(
                            utils.post_description <> " in " <> subreddit_name,
                          ),
                        ),
                      ])
                      |> json.to_string
                    let _ =
                      http_client.post(
                        base_url <> "/post-subreddit",
                        payload,
                        [],
                      )
                  })

                  // Upvote / Downvote Posts
                  let posts_feed: Array(PostInfo) =
                    glearray.from_list(get_posts(Some(subreddit_name)))
                  case glearray.length(posts_feed) > 0 {
                    True -> {
                      process.spawn(fn() {
                        log.info("Action: Voting a Post")

                        list.each(
                          list.range(
                            0,
                            int.random(int.min(
                              min_pc_interaction,
                              glearray.length(posts_feed),
                            )),
                          ),
                          fn(idx: Int) {
                            case glearray.get(posts_feed, idx) {
                              Ok(post_info) ->
                                vote_post(post_info.1, utils.random_boolean())
                              Error(_) -> simulate_actions(Some(action_choice))
                            }
                          },
                        )
                      })
                      Nil
                    }
                    False -> Nil
                  }
                  Nil
                }
                Error(_) -> simulate_actions(Some(action_choice))
              }
            }
            False -> {
              // Commment on Posts
              process.spawn(fn() {
                log.info("Action: Commenting on Post")

                let random_username: String = get_random_active_username()
                let posts_feed: Array(PostInfo) =
                  glearray.from_list(get_posts(None))

                list.each(
                  list.range(
                    0,
                    int.random(int.min(
                      min_pc_interaction,
                      glearray.length(posts_feed),
                    )),
                  ),
                  fn(post_idx: Int) {
                    case glearray.get(posts_feed, post_idx) {
                      Ok(post_info) -> {
                        let post_id: String = post_info.1
                        let comments: Array(CommentInfo) =
                          glearray.from_list(get_post_comments(post_id))
                        let parent_comment_id: String = case
                          utils.random_boolean()
                        {
                          True ->
                            case
                              glearray.get(
                                comments,
                                int.random(glearray.length(comments)),
                              )
                            {
                              Ok(comment_info) -> comment_info.1
                              Error(_) -> ""
                            }
                          False -> ""
                        }

                        let payload: String =
                          json.object([
                            #("post_id", string(post_id)),
                            #("parent_comment_id", string(parent_comment_id)),
                            #("username", string(random_username)),
                            #(
                              "comment",
                              string(
                                utils.post_description <> " on post " <> post_id,
                              ),
                            ),
                          ])
                          |> json.to_string
                        let _ =
                          http_client.post(
                            base_url <> "/comment-post",
                            payload,
                            [],
                          )
                        Nil
                      }
                      Error(_) -> Nil
                    }
                  },
                )
              })

              // Upvote / Downvote Comments
              process.spawn(fn() {
                log.info("Action: Voting a Comment")

                let posts_info: List(PostInfo) = get_posts(None)
                let posts_comments_feed: Array(PostInfo) =
                  glearray.from_list(
                    list.filter(posts_info, fn(post_info: PostInfo) {
                      !list.is_empty(post_info.3)
                    }),
                  )

                case glearray.length(posts_comments_feed) > 0 {
                  True ->
                    case
                      glearray.get(
                        posts_comments_feed,
                        int.random(glearray.length(posts_comments_feed)),
                      )
                    {
                      Ok(post_info) -> {
                        let comments: Array(String) =
                          glearray.from_list(post_info.3)

                        list.each(
                          list.range(
                            0,
                            int.random(int.min(
                              min_pc_interaction,
                              glearray.length(comments),
                            )),
                          ),
                          fn(idx: Int) {
                            case glearray.get(comments, idx) {
                              Ok(comment_id) ->
                                vote_comment(comment_id, utils.random_boolean())
                              Error(_) -> log.error("Error in voting comment")
                            }
                          },
                        )
                      }
                      Error(_) -> simulate_actions(Some(action_choice))
                    }
                  False -> Nil
                }
              })
              Nil
            }
          }
        }
      }
    }
  }
}

fn spawn_action_simulations() -> Nil {
  process.spawn(fn() { simulate_actions(None) })

  // Sleep 100ms-200ms to prevent server overload
  process.sleep(int.random(50) + 50)
  spawn_action_simulations()
}

fn get_users(active_status: Bool) -> List(UserInfo) {
  let users_url: String = case active_status {
    True -> "/active-users"
    False -> "/inactive-users"
  }

  case http_client.get(base_url <> users_url, []) {
    Ok(request_body) -> {
      case
        json.parse(
          request_body,
          decode.list({
            use username <- decode.field("username", decode.string)
            use der <- decode.field("der", decode.string)
            use pem <- decode.field("pem", decode.string)
            decode.success(#(username, der, pem))
          }),
        )
      {
        Ok(inactive_users) -> inactive_users
        Error(_) -> []
      }
    }
    Error(_) -> []
  }
}

fn get_subreddits(sort: Bool) -> List(SubRedditInfo) {
  case http_client.get(base_url <> "/subreddits", []) {
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

fn get_posts(subreddit_name_option: Option(String)) -> List(PostInfo) {
  let posts_url: String = case subreddit_name_option {
    Some(subreddit_name) -> base_url <> "/subreddit-posts/" <> subreddit_name
    None -> base_url <> "/posts"
  }

  case http_client.get(posts_url, []) {
    Ok(request_body) -> {
      case
        json.parse(
          request_body,
          decode.list({
            use subreddit_name <- decode.field("subreddit_name", decode.string)
            use post_id <- decode.field("post_id", decode.string)
            use post_description <- decode.field(
              "post_description",
              decode.string,
            )
            use comment_ids <- decode.field(
              "comment_ids",
              decode.list(decode.string),
            )
            decode.success(#(
              subreddit_name,
              post_id,
              post_description,
              comment_ids,
            ))
          }),
        )
      {
        Ok(posts) -> posts
        Error(_) -> []
      }
    }
    Error(_) -> []
  }
}

fn get_post_comments(post_id: String) -> List(CommentInfo) {
  case http_client.get(base_url <> "/post-comments/" <> post_id, []) {
    Ok(request_body) -> {
      case
        json.parse(
          request_body,
          decode.list({
            use post_id <- decode.field("post_id", decode.string)
            use comment_id <- decode.field("comment_id", decode.string)
            use parent_comment_id <- decode.field(
              "parent_comment_id",
              decode.string,
            )
            use comment <- decode.field("comment", decode.string)
            decode.success(#(post_id, comment_id, parent_comment_id, comment))
          }),
        )
      {
        Ok(comments) -> comments
        Error(_) -> []
      }
    }
    Error(_) -> []
  }
}

// Random values functions
fn get_random_active_username() -> String {
  let active_users: Array(UserInfo) = glearray.from_list(get_users(True))
  case glearray.get(active_users, int.random(glearray.length(active_users))) {
    Ok(user_info) -> user_info.0
    Error(_) -> get_random_active_username()
  }
}

fn get_random_user(users_info: Array(UserInfo)) -> UserInfo {
  case glearray.get(users_info, int.random(glearray.length(users_info))) {
    Ok(user_info) -> user_info
    Error(_) -> get_random_user(users_info)
  }
}

// Prioritize SubReddits with higher ranking to abide by zipf distrubution
fn get_random_subreddit() -> Result(SubRedditInfo, Nil) {
  let subreddit_feed: Array(SubRedditInfo) =
    glearray.from_list(get_subreddits(True))

  let random_idx: Int = case int.random(4) {
    1 -> int.random(glearray.length(subreddit_feed))
    _ -> int.random(min_subreddits_count)
  }
  glearray.get(subreddit_feed, random_idx)
}

fn vote_post(post_id: String, upvote: Bool) -> Nil {
  let vote_url: String = case upvote {
    True -> "/upvote-post/"
    False -> "/downvote-post/"
  }

  process.spawn(fn() {
    let _ = http_client.post(base_url <> vote_url <> post_id, "", [])
  })
  Nil
}

fn vote_comment(comment_id: String, upvote: Bool) -> Nil {
  let vote_url: String = case upvote {
    True -> "/upvote-comment/"
    False -> "/downvote-comment/"
  }

  process.spawn(fn() {
    let _ = http_client.post(base_url <> vote_url <> comment_id, "", [])
  })
  Nil
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
