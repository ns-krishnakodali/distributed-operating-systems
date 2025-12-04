import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/set.{type Set}
import gleam/time/timestamp

import lib/rsa.{type PrivateKey, type PublicKey}
import log
import utils

pub fn start_and_get_subj() -> ServerWorkerSubject {
  let user_state: Dict(String, UserState) = dict.new()
  let user_profiles_state: Dict(String, UserProfileState) = dict.new()
  let subreddits_state: Dict(String, SubRedditState) = dict.new()
  let posts_state: Dict(String, PostState) = dict.new()
  let comments_state: Dict(String, CommentState) = dict.new()

  let assert Ok(actor) =
    actor.new(#(
      user_state,
      user_profiles_state,
      subreddits_state,
      posts_state,
      comments_state,
    ))
    |> actor.on_message(handle_message)
    |> actor.start

  actor.data
}

fn handle_message(
  state: ServerWorkerState,
  s_message: ServerWorkerMessage,
) -> actor.Next(ServerWorkerState, ServerWorkerMessage) {
  case s_message {
    LogInUser(reply_subj, username, password) -> {
      let #(users_state, ups, srs, ps, cs): ServerWorkerState = state

      case dict.get(users_state, username) {
        Ok(#(u_password, online_status, _, _)) ->
          case u_password == password && !online_status {
            True -> {
              log.info("User " <> username <> " logged in successfully")
              let #(public_key, private_key) = rsa.generate_key_pair()
              process.send(reply_subj, True)

              actor.continue(#(
                dict.insert(users_state, username, #(
                  u_password,
                  True,
                  Some(public_key),
                  Some(private_key),
                )),
                ups,
                srs,
                ps,
                cs,
              ))
            }
            False -> {
              log.warning("User " <> username <> " is already online")
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        Error(_) -> {
          log.warning("Username " <> username <> " does not exist")
          process.send(reply_subj, False)

          actor.continue(state)
        }
      }
    }
    SignUpUser(reply_subj, username, password) -> {
      let #(users_state, user_profiles_state, srs, ps, cs): ServerWorkerState =
        state
      case dict.has_key(users_state, username) {
        True -> {
          log.error("Username " <> username <> " already exists")
          process.send(reply_subj, False)

          actor.continue(state)
        }
        False -> {
          log.info("User " <> username <> " signed up successfully")
          process.send(reply_subj, True)
          let #(public_key, private_key) = rsa.generate_key_pair()

          actor.continue(#(
            dict.insert(users_state, username, #(
              password,
              True,
              Some(public_key),
              Some(private_key),
            )),
            dict.insert(user_profiles_state, username, #(
              set.new(),
              set.new(),
              set.new(),
              dict.new(),
              0,
            )),
            srs,
            ps,
            cs,
          ))
        }
      }
    }
    SignOutUser(reply_subj, username, password) -> {
      let #(users_state, ups, srs, ps, cs): ServerWorkerState = state

      case dict.get(users_state, username) {
        Ok(#(u_password, online_status, _, _)) ->
          case u_password == password && online_status {
            True -> {
              process.send(reply_subj, True)

              actor.continue(#(
                dict.insert(users_state, username, #(
                  u_password,
                  False,
                  None,
                  None,
                )),
                ups,
                srs,
                ps,
                cs,
              ))
            }
            False -> {
              log.warning("User " <> username <> " is already offline")
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        Error(_) -> {
          log.warning("Username " <> username <> " does not exist")
          process.send(reply_subj, False)

          actor.continue(state)
        }
      }
    }
    GetUsers(reply_subj, active_status) -> {
      let users_state = state.0
      let active_usernames: List(UserInfo) =
        dict.to_list(users_state)
        |> list.filter_map(fn(entry) {
          let #(username, #(_, online_status, public_key_option, _)) = entry
          case active_status == online_status {
            True -> {
              case public_key_option {
                Some(public_key) ->
                  Ok(#(
                    username,
                    bit_array.base16_encode(public_key.der),
                    public_key.pem,
                  ))
                None -> Ok(#(username, "", ""))
              }
            }
            False -> Error(Nil)
          }
        })
      process.send(reply_subj, active_usernames)

      actor.continue(state)
    }
    GetUserSubReddits(reply_subj, username) -> {
      let users_state: Dict(String, UserState) = state.0
      case is_user_online(users_state, username) {
        True -> {
          let user_profiles_state: Dict(String, UserProfileState) = state.1
          case dict.get(user_profiles_state, username) {
            Ok(#(subreddits_set, _, _, _, _)) -> {
              process.send(reply_subj, set.to_list(subreddits_set))
            }
            Error(_) -> {
              process.send(reply_subj, [])
            }
          }
        }
        False -> {
          process.send(reply_subj, [])
        }
      }
      actor.continue(state)
    }
    GetUserPosts(reply_subj, username) -> {
      let users_state: Dict(String, UserState) = state.0
      case is_user_online(users_state, username) {
        True -> {
          let user_profiles_state: Dict(String, UserProfileState) = state.1
          case dict.get(user_profiles_state, username) {
            Ok(#(_, posts_set, _, _, _)) -> {
              process.send(reply_subj, set.to_list(posts_set))
            }
            Error(_) -> {
              process.send(reply_subj, [])
            }
          }
        }
        False -> {
          process.send(reply_subj, [])
        }
      }
      actor.continue(state)
    }
    CreateSubReddit(reply_subj, subreddit_name, created_username, rank) -> {
      let #(users_state, user_profiles_state, subreddits_state, ps, cs): ServerWorkerState =
        state

      case is_user_online(users_state, created_username) {
        True -> {
          case dict.has_key(subreddits_state, subreddit_name) {
            True -> {
              log.error("SubReddit " <> subreddit_name <> " already exists")
              process.send(reply_subj, False)

              actor.continue(state)
            }
            False -> {
              case
                update_user_profile_subreddits(
                  user_profiles_state,
                  subreddit_name,
                  created_username,
                  True,
                )
              {
                Ok(updated_user_profile) -> {
                  process.send(reply_subj, True)

                  actor.continue(#(
                    users_state,
                    dict.insert(
                      user_profiles_state,
                      created_username,
                      updated_user_profile,
                    ),
                    dict.insert(subreddits_state, subreddit_name, #(
                      created_username,
                      set.new(),
                      1,
                      rank,
                    )),
                    ps,
                    cs,
                  ))
                }
                Error(err) -> {
                  log.error(err)
                  process.send(reply_subj, False)

                  actor.continue(state)
                }
              }
            }
          }
        }
        False -> {
          log.error("Username " <> created_username <> " unavailable")
          process.send(reply_subj, False)

          actor.continue(state)
        }
      }
    }
    GetSubRedditsInfo(reply_subj) -> {
      let subreddits_state = state.2
      let subreddits_feed: List(SubRedditInfo) =
        dict.to_list(
          dict.map_values(
            subreddits_state,
            fn(_: String, subreddit_state: SubRedditState) {
              let #(_, _, _, rank) = subreddit_state
              rank
            },
          ),
        )
      process.send(reply_subj, subreddits_feed)

      actor.continue(state)
    }
    JoinSubReddit(reply_subj, subreddit_name, username) -> {
      let #(users_state, user_profiles_state, subreddits_state, ps, cs): ServerWorkerState =
        state

      case is_user_online(users_state, username) {
        True -> {
          case dict.has_key(subreddits_state, subreddit_name) {
            True -> {
              log.info(
                "User " <> username <> " joining SubReddit " <> subreddit_name,
              )
              case
                update_user_profile_subreddits(
                  user_profiles_state,
                  subreddit_name,
                  username,
                  True,
                )
              {
                Ok(updated_user_profile) -> {
                  let assert Ok(#(cu, pis, subscribers, rank)) =
                    dict.get(subreddits_state, subreddit_name)
                  process.send(reply_subj, True)

                  actor.continue(#(
                    users_state,
                    dict.insert(
                      user_profiles_state,
                      username,
                      updated_user_profile,
                    ),
                    dict.insert(subreddits_state, subreddit_name, #(
                      cu,
                      pis,
                      subscribers + 1,
                      rank,
                    )),
                    ps,
                    cs,
                  ))
                }
                Error(err) -> {
                  process.send(reply_subj, False)
                  log.error(err)

                  actor.continue(state)
                }
              }
            }
            False -> {
              log.error("SubReddit " <> subreddit_name <> " not found")
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        False -> {
          log.error("Username " <> username <> " unavailable")
          process.send(reply_subj, False)

          actor.continue(state)
        }
      }
    }
    LeaveSubReddit(reply_subj, subreddit_name, username) -> {
      let #(users_state, user_profiles_state, subreddits_state, ps, cs): ServerWorkerState =
        state

      case is_user_online(users_state, username) {
        True -> {
          case dict.has_key(subreddits_state, subreddit_name) {
            True -> {
              log.info(
                "User " <> username <> " leaving SubReddit " <> subreddit_name,
              )
              case
                update_user_profile_subreddits(
                  user_profiles_state,
                  subreddit_name,
                  username,
                  False,
                )
              {
                Ok(updated_user_state) -> {
                  let assert Ok(#(cu, pis, subscribers, rank)) =
                    dict.get(subreddits_state, subreddit_name)
                  process.send(reply_subj, True)

                  actor.continue(#(
                    users_state,
                    dict.insert(
                      user_profiles_state,
                      username,
                      updated_user_state,
                    ),
                    dict.insert(subreddits_state, subreddit_name, #(
                      cu,
                      pis,
                      subscribers - 1,
                      rank,
                    )),
                    ps,
                    cs,
                  ))
                }
                Error(err) -> {
                  log.error(err)
                  process.send(reply_subj, False)

                  actor.continue(state)
                }
              }
            }
            False -> {
              log.error("SubReddit " <> subreddit_name <> " not found")
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        False -> {
          log.error("Username " <> username <> " unavailable")
          process.send(reply_subj, False)

          actor.continue(state)
        }
      }
    }
    PostInSubReddit(reply_subj, subreddit_name, username, post_description) -> {
      let #(users_state, user_profiles_state, subreddits_state, posts_state, cs): ServerWorkerState =
        state

      case is_user_online(users_state, username) {
        True -> {
          case dict.has_key(subreddits_state, subreddit_name) {
            True -> {
              log.info(
                "User "
                <> username
                <> " posting in SubReddit "
                <> subreddit_name,
              )

              let post_id: String =
                utils.generate_hex_string(10, utils.post_prefix)
              case
                update_user_profile_posts(
                  user_profiles_state,
                  post_id,
                  username,
                )
              {
                Ok(updated_user_profile) -> {
                  let assert Ok(#(cu, post_ids_set, subscribers, rank)) =
                    dict.get(subreddits_state, subreddit_name)
                  process.send(reply_subj, True)

                  actor.continue(#(
                    users_state,
                    dict.insert(
                      user_profiles_state,
                      username,
                      updated_user_profile,
                    ),
                    dict.insert(subreddits_state, subreddit_name, #(
                      cu,
                      set.insert(post_ids_set, post_id),
                      subscribers,
                      rank,
                    )),
                    dict.insert(posts_state, post_id, #(
                      subreddit_name,
                      username,
                      post_description,
                      set.new(),
                      1,
                      0,
                    )),
                    cs,
                  ))
                }
                Error(err) -> {
                  log.error(err)
                  process.send(reply_subj, False)

                  actor.continue(state)
                }
              }
            }
            False -> {
              log.error("SubReddit " <> subreddit_name <> " not found")
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        False -> {
          log.error("Username " <> username <> " unavailable")
          process.send(reply_subj, False)

          actor.continue(state)
        }
      }
    }
    GetSubRedditPostsFeed(reply_subj, subreddit_name) -> {
      let subreddits_state: Dict(String, SubRedditState) = state.2
      let posts_state: Dict(String, PostState) = state.3

      let post_details: List(PostInfo) = case
        dict.get(subreddits_state, subreddit_name)
      {
        Ok(subreddit_state) -> {
          let #(_, post_ids_set, _, _) = subreddit_state
          let post_ids_list = set.to_list(post_ids_set)

          list.filter_map(post_ids_list, fn(post_id) {
            case dict.get(posts_state, post_id) {
              Ok(post) -> {
                let #(_, _, post_description, comment_ids_set, _, _) = post
                Ok(#(
                  subreddit_name,
                  post_id,
                  post_description,
                  set.to_list(comment_ids_set),
                ))
              }
              Error(_) -> {
                log.error("Error in getting post details for " <> post_id)
                Error(Nil)
              }
            }
          })
        }
        Error(_) -> {
          log.error("Error in getting subreddit posts feed")
          []
        }
      }
      process.send(reply_subj, post_details)

      actor.continue(state)
    }
    GetPostsFeed(reply_subj) -> {
      let posts_state: Dict(String, PostState) = state.3

      let post_details: List(PostInfo) =
        list.map(dict.to_list(posts_state), fn(entry) {
          let #(post_id, post_state) = entry
          let #(subreddit_name, _, post_description, comment_ids_set, _, _) =
            post_state
          #(
            subreddit_name,
            post_id,
            post_description,
            set.to_list(comment_ids_set),
          )
        })
      process.send(reply_subj, post_details)

      actor.continue(state)
    }
    DownloadPost(reply_subj, post_id, username) -> {
      let users_state: Dict(String, UserState) = state.0
      let posts_state: Dict(String, PostState) = state.3

      let empty_download_post_info: PostDownloadInfo = #("", "", "", "", 0)

      let download_post_info: PostDownloadInfo = case
        is_user_online(users_state, username)
      {
        True -> {
          case dict.get(posts_state, post_id) {
            Ok(#(_, created_username, post_description, _, upvotes, downvotes)) -> {
              let assert Ok(user_info) = dict.get(users_state, username)
              case user_info.3 {
                Some(private_key) -> {
                  case
                    rsa.sign_message(
                      bit_array.from_string(post_id),
                      private_key,
                    )
                  {
                    Ok(signature) -> #(
                      bit_array.base16_encode(signature),
                      post_id,
                      created_username,
                      post_description,
                      upvotes - downvotes,
                    )
                    Error(_) -> {
                      log.error("Failed to sign with RSA key")
                      empty_download_post_info
                    }
                  }
                }
                None -> {
                  log.error("No RSA private key found for user " <> username)
                  empty_download_post_info
                }
              }
            }
            Error(_) -> {
              log.error("Post " <> post_id <> " not found")
              empty_download_post_info
            }
          }
        }
        False -> {
          log.error("Username " <> username <> " unavailable")
          empty_download_post_info
        }
      }
      process.send(reply_subj, download_post_info)

      actor.continue(state)
    }
    UpVotePost(reply_subj, post_id) -> {
      let #(us, user_profiles_state, srs, posts_state, cs): ServerWorkerState =
        state

      case dict.get(posts_state, post_id) {
        Ok(#(srn, created_username, pd, cis, upvotes, downvotes)) -> {
          let updated_post_state: PostState = #(
            srn,
            created_username,
            pd,
            cis,
            upvotes + 1,
            downvotes,
          )

          case
            update_user_profile_karma(user_profiles_state, created_username, 1)
          {
            Ok(updated_user_profile) -> {
              process.send(reply_subj, True)

              actor.continue(#(
                us,
                dict.insert(
                  user_profiles_state,
                  created_username,
                  updated_user_profile,
                ),
                srs,
                dict.insert(posts_state, post_id, updated_post_state),
                cs,
              ))
            }
            Error(err) -> {
              log.error(err)
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        Error(_) -> {
          log.error("Post " <> post_id <> " not found")
          actor.continue(state)
        }
      }
    }
    DownVotePost(reply_subj, post_id) -> {
      let #(us, user_profiles_state, srs, posts_state, cs): ServerWorkerState =
        state

      case dict.get(posts_state, post_id) {
        Ok(#(srn, created_username, pd, cis, upvotes, downvotes)) -> {
          let updated_post_state: PostState = #(
            srn,
            created_username,
            pd,
            cis,
            upvotes,
            downvotes + 1,
          )

          case
            update_user_profile_karma(user_profiles_state, created_username, -1)
          {
            Ok(updated_user_profile) -> {
              process.send(reply_subj, True)

              actor.continue(#(
                us,
                dict.insert(
                  user_profiles_state,
                  created_username,
                  updated_user_profile,
                ),
                srs,
                dict.insert(posts_state, post_id, updated_post_state),
                cs,
              ))
            }
            Error(err) -> {
              log.error(err)
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        Error(_) -> {
          log.error("Post " <> post_id <> " not found")
          actor.continue(state)
        }
      }
    }
    CommentOnPost(
      reply_subj,
      post_id,
      parent_comment_id,
      commented_username,
      comment,
    ) -> {
      let #(users_state, user_profiles_state, srs, posts_state, comments_state): ServerWorkerState =
        state

      case is_user_online(users_state, commented_username) {
        True -> {
          case dict.get(posts_state, post_id) {
            Ok(#(srn, cu, pd, comment_ids_set, uv, dv)) -> {
              log.info(
                "User "
                <> commented_username
                <> " commenting on post "
                <> post_id,
              )

              let comment_id: String =
                utils.generate_hex_string(10, utils.comment_prefix)
              case
                update_user_profile_comments(
                  user_profiles_state,
                  comment_id,
                  commented_username,
                )
              {
                Ok(updated_user_profile) -> {
                  process.send(reply_subj, True)

                  actor.continue(#(
                    users_state,
                    dict.insert(
                      user_profiles_state,
                      commented_username,
                      updated_user_profile,
                    ),
                    srs,
                    dict.insert(posts_state, post_id, #(
                      srn,
                      cu,
                      pd,
                      set.insert(comment_ids_set, comment_id),
                      uv,
                      dv,
                    )),
                    dict.insert(comments_state, comment_id, #(
                      post_id,
                      parent_comment_id,
                      commented_username,
                      comment,
                      1,
                      0,
                    )),
                  ))
                }
                Error(err) -> {
                  log.error(err)
                  process.send(reply_subj, False)

                  actor.continue(state)
                }
              }
            }
            Error(_) -> {
              log.error("Post " <> post_id <> " does not exist")
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        False -> {
          log.error("Username " <> commented_username <> " unavailable")
          process.send(reply_subj, False)

          actor.continue(state)
        }
      }
    }
    GetPostComments(reply_subj, post_id) -> {
      let posts_state: Dict(String, PostState) = state.3
      let comments_state: Dict(String, CommentState) = state.4

      let comments_info: List(CommentInfo) = case
        dict.get(posts_state, post_id)
      {
        Ok(post_state) -> {
          let comment_ids_list = set.to_list(post_state.3)
          list.filter_map(comment_ids_list, fn(comment_id: String) {
            case dict.get(comments_state, comment_id) {
              Ok(#(_, parent_comment_id, _, comment, _, _)) ->
                Ok(#(post_id, comment_id, parent_comment_id, comment))
              Error(_) -> Error(Nil)
            }
          })
        }
        Error(_) -> []
      }
      process.send(reply_subj, comments_info)

      actor.continue(state)
    }
    UpVoteComment(reply_subj, comment_id) -> {
      let #(us, user_profiles_state, srs, ps, comments_state): ServerWorkerState =
        state

      case dict.get(comments_state, comment_id) {
        Ok(#(pid, pci, commented_username, comment, upvotes, downvotes)) -> {
          let updated_comments_state: CommentState = #(
            pid,
            pci,
            commented_username,
            comment,
            upvotes + 1,
            downvotes,
          )

          case
            update_user_profile_karma(
              user_profiles_state,
              commented_username,
              1,
            )
          {
            Ok(updated_user_profile) -> {
              process.send(reply_subj, True)

              actor.continue(#(
                us,
                dict.insert(
                  user_profiles_state,
                  commented_username,
                  updated_user_profile,
                ),
                srs,
                ps,
                dict.insert(comments_state, comment_id, updated_comments_state),
              ))
            }
            Error(err) -> {
              log.error(err)
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        Error(_) -> {
          log.error("Comment " <> comment_id <> " not found")
          actor.continue(state)
        }
      }
    }
    DownVoteComment(reply_subj, comment_id) -> {
      let #(us, user_profiles_state, srs, ps, comments_state): ServerWorkerState =
        state

      case dict.get(comments_state, comment_id) {
        Ok(#(pid, pci, commented_username, comment, upvotes, downvotes)) -> {
          let updated_comments_state: CommentState = #(
            pid,
            pci,
            commented_username,
            comment,
            upvotes,
            downvotes - 1,
          )

          case
            update_user_profile_karma(
              user_profiles_state,
              commented_username,
              -1,
            )
          {
            Ok(updated_user_profile) -> {
              process.send(reply_subj, True)

              actor.continue(#(
                us,
                dict.insert(
                  user_profiles_state,
                  commented_username,
                  updated_user_profile,
                ),
                srs,
                ps,
                dict.insert(comments_state, comment_id, updated_comments_state),
              ))
            }
            Error(err) -> {
              log.error(err)
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        Error(_) -> {
          log.error("Comment " <> comment_id <> " not found")
          actor.continue(state)
        }
      }
    }

    MessageUser(reply_subj, sender_username, receiver_username, message) -> {
      let #(users_state, user_profiles_state, srs, ps, cs) = state
      case is_user_online(users_state, sender_username) {
        // Can send self messages
        True -> {
          case
            dict.get(user_profiles_state, sender_username),
            dict.get(user_profiles_state, receiver_username)
          {
            Ok(#(srs1, pis1, cid1, users_messages1, uk1)),
              Ok(#(srs2, pis2, cid2, users_messages2, uk2))
            -> {
              let updated_user_profiles_state: Dict(String, UserProfileState) =
                user_profiles_state
                |> dict.insert(sender_username, #(
                  srs1,
                  pis1,
                  cid1,
                  update_users_messages(users_messages1, receiver_username, #(
                    message,
                    False,
                    timestamp.to_unix_seconds(timestamp.system_time()),
                  )),
                  uk1,
                ))
                |> dict.insert(receiver_username, #(
                  srs2,
                  pis2,
                  cid2,
                  update_users_messages(users_messages2, sender_username, #(
                    message,
                    True,
                    timestamp.to_unix_seconds(timestamp.system_time()),
                  )),
                  uk2,
                ))
              process.send(reply_subj, True)

              actor.continue(#(
                users_state,
                updated_user_profiles_state,
                srs,
                ps,
                cs,
              ))
            }
            Error(_), _ | _, Error(_) -> {
              log.error(
                "Error sending message from user "
                <> sender_username
                <> " to "
                <> receiver_username,
              )
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        False -> {
          log.error(
            "Cannot find user names {"
            <> sender_username
            <> ", "
            <> receiver_username
            <> "}",
          )
          process.send(reply_subj, False)

          actor.continue(state)
        }
      }
    }
    GetUnreadMessages(reply_subj, username) -> {
      let user_profiles_state: Dict(String, UserProfileState) = state.1
      let users_messages: UsersMessages = case
        dict.get(user_profiles_state, username)
      {
        Ok(user_profile) -> user_profile.3
        Error(_) -> dict.new()
      }

      let user_messages_info: List(UserMessageInfo) =
        dict.to_list(users_messages)
        |> list.filter_map(fn(entry) {
          let #(sender_username, direct_messages_list) = entry
          case list.first(direct_messages_list) {
            Ok(#(message, received, timestamp)) ->
              case received {
                True -> Ok(#(sender_username, message, timestamp))
                False -> Error(Nil)
              }
            Error(_) -> Error(Nil)
          }
        })
      process.send(reply_subj, user_messages_info)

      actor.continue(state)
    }
    Shutdown -> {
      actor.stop()
    }
  }
}

// Helper functions
fn is_user_online(
  users_state: Dict(String, UserState),
  username: String,
) -> Bool {
  case dict.get(users_state, username) {
    Ok(#(_, online_status, _, _)) -> online_status
    Error(_) -> False
  }
}

fn update_user_profile_subreddits(
  user_profiles_state: Dict(String, UserProfileState),
  subreddit_name: String,
  username: String,
  add_sr: Bool,
) -> UserProfileStateResult {
  case dict.get(user_profiles_state, username) {
    Ok(#(subreddit_names_set, pis, cid, um, uk)) -> {
      case set.contains(subreddit_names_set, subreddit_name) {
        True ->
          Error(
            "User "
            <> username
            <> " already joined subreddit "
            <> subreddit_name,
          )
        False -> {
          let updated_subreddits_set: Set(String) = case add_sr {
            True -> set.insert(subreddit_names_set, subreddit_name)
            False -> set.delete(subreddit_names_set, subreddit_name)
          }
          Ok(#(updated_subreddits_set, pis, cid, um, uk))
        }
      }
    }
    Error(_) -> {
      Error("Error updating subreddit ids for user " <> username <> " profile")
    }
  }
}

fn update_user_profile_posts(
  user_profiles_state: Dict(String, UserProfileState),
  post_id: String,
  username: String,
) -> UserProfileStateResult {
  case dict.get(user_profiles_state, username) {
    Ok(#(srs, post_ids_set, cid, mis, uk)) ->
      Ok(#(srs, set.insert(post_ids_set, post_id), cid, mis, uk))
    Error(_) -> {
      Error("Error updating post ids for user " <> username <> " profile")
    }
  }
}

fn update_user_profile_comments(
  user_profiles_state: Dict(String, UserProfileState),
  comment_id: String,
  username: String,
) -> UserProfileStateResult {
  case dict.get(user_profiles_state, username) {
    Ok(#(sns, pis, comment_ids_set, mis, uk)) -> {
      case !set.contains(comment_ids_set, comment_id) {
        True ->
          Ok(#(sns, pis, set.insert(comment_ids_set, comment_id), mis, uk))
        False -> Error("Comment ID " <> comment_id <> " already exists")
      }
    }
    Error(_) -> {
      Error("Error updating comment ids for user " <> username <> " profile")
    }
  }
}

fn update_user_profile_karma(
  user_profiles_state: Dict(String, UserProfileState),
  username: String,
  karma: Int,
) -> UserProfileStateResult {
  case dict.get(user_profiles_state, username) {
    Ok(#(srs, pis, cid, mis, user_karma)) ->
      Ok(#(srs, pis, cid, mis, user_karma + karma))
    Error(_) -> {
      Error("Error updating karma for user " <> username)
    }
  }
}

fn update_users_messages(
  users_messages: UsersMessages,
  username: String,
  direct_message: DirectMessage,
) -> UsersMessages {
  case dict.get(users_messages, username) {
    Ok(direct_messages_list) ->
      dict.insert(users_messages, username, [
        direct_message,
        ..direct_messages_list
      ])
    Error(_) -> dict.insert(users_messages, username, [direct_message])
  }
}

// message, received, timestamp
pub type DirectMessage =
  #(String, Bool, Float)

// sender_username -> direct messages
pub type UsersMessages =
  Dict(String, List(DirectMessage))

// password, online_status, public_key, private_key
pub type UserState =
  #(String, Bool, Option(PublicKey), Option(PrivateKey))

// subreddit_names_set, post_ids_set, comment_ids_set, users_messages, karma
pub type UserProfileState =
  #(Set(String), Set(String), Set(String), UsersMessages, Int)

// created_username, post_ids_set, subscribers, rank
pub type SubRedditState =
  #(String, Set(String), Int, Int)

// subreddit_name, created_username, post_description, comment_ids_set, upvotes, downvotes
pub type PostState =
  #(String, String, String, Set(String), Int, Int)

// post_id, parent_comment_id, commented_username, comment, upvotes, downvotes
pub type CommentState =
  #(String, String, String, String, Int, Int)

// username, der, pem
pub type UserInfo =
  #(String, String, String)

// subreddit_name, rank
pub type SubRedditInfo =
  #(String, Int)

// subreddit_name, post_id, post_description, comment_ids
pub type PostInfo =
  #(String, String, String, List(String))

// signature, post_id, created_username, post_description, karma
pub type PostDownloadInfo =
  #(String, String, String, String, Int)

// post_id, comment_id, parent_comment_id, comment
pub type CommentInfo =
  #(String, String, String, String)

// sender_username, message, timestamp
pub type UserMessageInfo =
  #(String, String, Float)

type UserProfileStateResult =
  Result(UserProfileState, String)

pub type ServerWorkerState =
  #(
    Dict(String, UserState),
    Dict(String, UserProfileState),
    Dict(String, SubRedditState),
    Dict(String, PostState),
    Dict(String, CommentState),
  )

pub type ServerWorkerSubject =
  Subject(ServerWorkerMessage)

pub type ServerWorkerMessage {
  // Users
  LogInUser(Subject(Bool), String, String)
  SignUpUser(Subject(Bool), String, String)
  SignOutUser(Subject(Bool), String, String)
  GetUsers(Subject(List(UserInfo)), Bool)
  GetUserSubReddits(Subject(List(String)), String)
  GetUserPosts(Subject(List(String)), String)

  // SubReddits
  CreateSubReddit(Subject(Bool), String, String, Int)
  GetSubRedditsInfo(Subject(List(SubRedditInfo)))
  JoinSubReddit(Subject(Bool), String, String)
  LeaveSubReddit(Subject(Bool), String, String)

  // Posts
  PostInSubReddit(Subject(Bool), String, String, String)
  GetSubRedditPostsFeed(Subject(List(PostInfo)), String)
  GetPostsFeed(Subject(List(PostInfo)))
  DownloadPost(Subject(PostDownloadInfo), String, String)
  UpVotePost(Subject(Bool), String)
  DownVotePost(Subject(Bool), String)

  // Comments
  CommentOnPost(Subject(Bool), String, String, String, String)
  GetPostComments(Subject(List(CommentInfo)), String)
  UpVoteComment(Subject(Bool), String)
  DownVoteComment(Subject(Bool), String)

  // Messages
  MessageUser(Subject(Bool), String, String, String)
  GetUnreadMessages(Subject(List(UserMessageInfo)), String)
  Shutdown
}
