import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/order
import gleam/otp/actor
import gleam/set.{type Set}
import gleam/string
import gleam/time/timestamp

import logging
import utils

pub fn start_and_get_subj() -> ServerWorkerSubject {
  let user_state: UsersState = dict.new()
  let user_messages_state: Dict(String, UserMessagesState) = dict.new()
  let user_profiles_state: Dict(String, UserProfileState) = dict.new()
  let subreddits_state: Dict(String, SubRedditState) = dict.new()
  let posts_state: Dict(String, PostState) = dict.new()
  let comment_state: Dict(String, CommentState) = dict.new()

  let assert Ok(actor) =
    actor.new(#(
      user_state,
      user_profiles_state,
      user_messages_state,
      subreddits_state,
      posts_state,
      comment_state,
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
    SignUpUser(reply_subj, username, password) -> {
      let #(users_state, user_profiles_state, ums, srs, ps, cs): ServerWorkerState =
        state
      case dict.has_key(users_state, username) {
        True -> {
          logging.error("Username " <> username <> " already exists")
          process.send(reply_subj, False)

          actor.continue(state)
        }
        False -> {
          process.send(reply_subj, True)

          actor.continue(#(
            dict.insert(users_state, username, #(password, True)),
            dict.insert(user_profiles_state, username, #(
              set.new(),
              set.new(),
              set.new(),
              set.new(),
              0,
              False,
            )),
            ums,
            srs,
            ps,
            cs,
          ))
        }
      }
    }
    CreateSubReddit(reply_subj, subreddit_name, created_username, rank) -> {
      let #(users_state, user_profiles_state, ums, subreddits_state, ps, cs): ServerWorkerState =
        state

      case dict.has_key(users_state, created_username) {
        True -> {
          case dict.has_key(subreddits_state, subreddit_name) {
            True -> {
              logging.error("SubReddit " <> subreddit_name <> " already exists")
              process.send(reply_subj, False)

              actor.continue(state)
            }
            False -> {
              logging.info("Creating SubReddit " <> subreddit_name)
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
                    ums,
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
                  logging.error(err)
                  process.send(reply_subj, False)

                  actor.continue(state)
                }
              }
            }
          }
        }
        False -> {
          logging.error("Username " <> created_username <> " not found")
          process.send(reply_subj, False)

          actor.continue(state)
        }
      }
    }
    JoinSubReddit(reply_subj, subreddit_name, username) -> {
      let #(users_state, user_profiles_state, ums, subreddits_state, ps, cs): ServerWorkerState =
        state

      case dict.has_key(users_state, username) {
        True -> {
          case dict.has_key(subreddits_state, subreddit_name) {
            True -> {
              logging.info(
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
                    ums,
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
                  logging.error(err)

                  actor.continue(state)
                }
              }
            }
            False -> {
              logging.error("SubReddit " <> subreddit_name <> " not found")
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        False -> {
          logging.error("Username " <> username <> " not found")
          process.send(reply_subj, False)

          actor.continue(state)
        }
      }
    }
    LeaveSubReddit(reply_subj, subreddit_name, username) -> {
      let #(users_state, user_profiles_state, ums, subreddits_state, ps, cs): ServerWorkerState =
        state

      case dict.has_key(users_state, username) {
        True -> {
          case dict.has_key(subreddits_state, subreddit_name) {
            True -> {
              logging.info(
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
                    ums,
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
                  logging.error(err)
                  process.send(reply_subj, False)

                  actor.continue(state)
                }
              }
            }
            False -> {
              logging.error("SubReddit " <> subreddit_name <> " not found")
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        False -> {
          logging.error("Username " <> username <> " not found")
          process.send(reply_subj, False)

          actor.continue(state)
        }
      }
    }
    PostInSubReddit(reply_subj, subreddit_name, username, post_description) -> {
      let #(
        users_state,
        user_profiles_state,
        ums,
        subreddits_state,
        posts_state,
        cs,
      ): ServerWorkerState = state

      case dict.has_key(users_state, username) {
        True -> {
          case dict.has_key(subreddits_state, subreddit_name) {
            True -> {
              logging.info(
                "User "
                <> username
                <> " posting in SubReddit "
                <> subreddit_name,
              )

              let post_id: String = utils.generate_hex_string(10, "")
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
                    ums,
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
                      0,
                      0,
                    )),
                    cs,
                  ))
                }
                Error(err) -> {
                  logging.error(err)
                  process.send(reply_subj, False)

                  actor.continue(state)
                }
              }
            }
            False -> {
              logging.error("SubReddit " <> subreddit_name <> " not found")
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        False -> {
          logging.error("Username " <> username <> " not found")
          process.send(reply_subj, False)

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
      let #(
        users_state,
        user_profiles_state,
        ums,
        srs,
        posts_state,
        comments_state,
      ): ServerWorkerState = state

      case dict.has_key(users_state, commented_username) {
        True -> {
          case dict.get(posts_state, post_id) {
            Ok(#(srn, cu, pd, comment_ids_set, uv, dv)) -> {
              logging.info(
                "User "
                <> commented_username
                <> " commenting on post "
                <> post_id,
              )

              let comment_id: String = utils.generate_hex_string(10, "")
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
                    ums,
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
                      0,
                      0,
                    )),
                  ))
                }
                Error(err) -> {
                  logging.error(err)
                  process.send(reply_subj, False)

                  actor.continue(state)
                }
              }

              actor.continue(state)
            }
            Error(_) -> {
              logging.error("Post " <> post_id <> " does not exist")
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        False -> {
          logging.error("Username " <> commented_username <> " not found")
          process.send(reply_subj, False)

          actor.continue(state)
        }
      }
    }
    UpVotePost(reply_subj, post_id) -> {
      let #(us, user_profiles_state, ums, srs, posts_state, cs): ServerWorkerState =
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
                ums,
                srs,
                dict.insert(posts_state, post_id, updated_post_state),
                cs,
              ))
            }
            Error(err) -> {
              logging.error(err)
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        Error(_) -> {
          logging.error("Post " <> post_id <> " not found")
          actor.continue(state)
        }
      }
    }
    DownVotePost(reply_subj, post_id) -> {
      let #(us, user_profiles_state, ums, srs, posts_state, cs): ServerWorkerState =
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
                ums,
                srs,
                dict.insert(posts_state, post_id, updated_post_state),
                cs,
              ))
            }
            Error(err) -> {
              logging.error(err)
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        Error(_) -> {
          logging.error("Post " <> post_id <> " not found")
          actor.continue(state)
        }
      }
    }
    UpVoteComment(reply_subj, comment_id) -> {
      let #(us, user_profiles_state, ums, srs, ps, comments_state): ServerWorkerState =
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
                ums,
                srs,
                ps,
                dict.insert(comments_state, comment_id, updated_comments_state),
              ))
            }
            Error(err) -> {
              logging.error(err)
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        Error(_) -> {
          logging.error("Comment " <> comment_id <> " not found")
          actor.continue(state)
        }
      }
    }
    DownVoteComment(reply_subj, comment_id) -> {
      let #(us, user_profiles_state, ums, srs, ps, comments_state): ServerWorkerState =
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
                ums,
                srs,
                ps,
                dict.insert(comments_state, comment_id, updated_comments_state),
              ))
            }
            Error(err) -> {
              logging.error(err)
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        Error(_) -> {
          logging.error("Comment " <> comment_id <> " not found")
          actor.continue(state)
        }
      }
    }
    DirectMessage(reply_subj, sender_username, receiver_username, message) -> {
      let #(users_state, user_profiles_state, user_messages_state, srs, ps, cs) =
        state
      case
        dict.has_key(users_state, sender_username)
        && dict.has_key(users_state, receiver_username)
      {
        True -> {
          // Order sender and receiver usernames lexicographically to obtain id for users chat
          let user_messages_id = case
            string.compare(sender_username, receiver_username)
          {
            order.Eq -> {
              sender_username <> receiver_username
            }
            order.Lt -> sender_username <> receiver_username
            order.Gt -> receiver_username <> sender_username
          }

          let direct_message: DirectMessage = #(
            sender_username,
            receiver_username,
            message,
            timestamp.to_unix_seconds(timestamp.system_time()),
          )

          let updated_user_messages = case
            dict.get(user_messages_state, user_messages_id)
          {
            Ok(user_messages_list) -> [direct_message, ..user_messages_list]
            Error(_) -> [direct_message]
          }

          case
            update_user_message_ids(
              user_profiles_state,
              sender_username,
              receiver_username,
              user_messages_id,
            )
          {
            Ok(updated_users_profile_state) -> {
              process.send(reply_subj, True)
              actor.continue(#(
                users_state,
                updated_users_profile_state,
                dict.insert(
                  user_messages_state,
                  user_messages_id,
                  updated_user_messages,
                ),
                srs,
                ps,
                cs,
              ))
            }
            Error(err) -> {
              logging.error(err)
              process.send(reply_subj, False)

              actor.continue(state)
            }
          }
        }
        False -> {
          logging.error(
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
    GetSubRedditsFeed(reply_subj) -> {
      let subreddits_state = state.3
      let subreddits_feed =
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
    Shutdown -> {
      actor.stop()
    }
  }
}

// Helper functions
fn update_user_profile_subreddits(
  user_profiles_state: Dict(String, UserProfileState),
  subreddit_name: String,
  username: String,
  add_sr: Bool,
) -> UserProfileStateResult {
  case dict.get(user_profiles_state, username) {
    Ok(#(subreddit_names_set, pis, cid, mis, uk, os)) -> {
      case set.contains(subreddit_names_set, subreddit_name) {
        True ->
          Error(
            "User " <> username <> " alredy joined subreddit " <> subreddit_name,
          )
        False -> {
          let updated_subreddits_set: Set(String) = case add_sr {
            True -> set.insert(subreddit_names_set, subreddit_name)
            False -> set.delete(subreddit_names_set, subreddit_name)
          }
          Ok(#(updated_subreddits_set, pis, cid, mis, uk, os))
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
    Ok(#(srs, post_ids_set, cid, mis, uk, os)) ->
      Ok(#(srs, set.insert(post_ids_set, post_id), cid, mis, uk, os))
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
    Ok(#(sns, pis, comment_ids_set, mis, uk, os)) -> {
      case set.contains(comment_ids_set, comment_id) {
        True -> Error("Comment ID " <> comment_id <> " already exists")
        False ->
          Ok(#(sns, pis, set.insert(comment_ids_set, comment_id), mis, uk, os))
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
    Ok(#(srs, pis, cid, mis, user_karma, os)) ->
      Ok(#(srs, pis, cid, mis, user_karma + karma, os))
    Error(_) -> {
      Error("Error updating karma for user " <> username)
    }
  }
}

fn update_user_message_ids(
  user_profiles_state: Dict(String, UserProfileState),
  username1: String,
  username2: String,
  user_messages_id,
) -> Result(Dict(String, UserProfileState), String) {
  case
    dict.get(user_profiles_state, username1),
    dict.get(user_profiles_state, username2)
  {
    Ok(#(srs1, pis1, cid1, message_ids_set1, uk1, os1)),
      Ok(#(srs2, pis2, cid2, message_ids_set2, uk2, os2))
    -> {
      Ok(
        user_profiles_state
        |> dict.insert(username1, #(
          srs1,
          pis1,
          cid1,
          set.insert(message_ids_set1, user_messages_id),
          uk1,
          os1,
        ))
        |> dict.insert(username2, #(
          srs2,
          pis2,
          cid2,
          set.insert(message_ids_set2, user_messages_id),
          uk2,
          os2,
        )),
      )
    }
    Error(_), _ | _, Error(_) -> {
      Error(
        "Error updating message ids for users "
        <> username1
        <> " and "
        <> username2,
      )
    }
  }
}

// sender_username, receiver_username, message, timestamp
pub type DirectMessage =
  #(String, String, String, Float)

// username -> password, online_status
pub type UsersState =
  Dict(String, #(String, Bool))

// subreddit_names_set, post_ids_set, comment_ids_set, message_ids_set, user_karma, online_status
pub type UserProfileState =
  #(Set(String), Set(String), Set(String), Set(String), Int, Bool)

// list(username, message)
pub type UserMessagesState =
  List(DirectMessage)

// created_username, post_ids_set, subscribers, rank
pub type SubRedditState =
  #(String, Set(String), Int, Int)

// subreddit_name, created_username, post_description, comment_ids_set, upvotes, downvotes
pub type PostState =
  #(String, String, String, Set(String), Int, Int)

// post_id, parent_comment_id, commented_username, comment, upvotes, downvotes
pub type CommentState =
  #(String, String, String, String, Int, Int)

type UserProfileStateResult =
  Result(UserProfileState, String)

pub type ServerWorkerState =
  #(
    UsersState,
    Dict(String, UserProfileState),
    Dict(String, UserMessagesState),
    Dict(String, SubRedditState),
    Dict(String, PostState),
    Dict(String, CommentState),
  )

pub type ServerWorkerSubject =
  Subject(ServerWorkerMessage)

pub type ServerWorkerMessage {
  SignUpUser(Subject(Bool), String, String)
  CreateSubReddit(Subject(Bool), String, String, Int)
  JoinSubReddit(Subject(Bool), String, String)
  LeaveSubReddit(Subject(Bool), String, String)
  PostInSubReddit(Subject(Bool), String, String, String)
  CommentOnPost(Subject(Bool), String, String, String, String)
  UpVotePost(Subject(Bool), String)
  DownVotePost(Subject(Bool), String)
  UpVoteComment(Subject(Bool), String)
  DownVoteComment(Subject(Bool), String)
  DirectMessage(Subject(Bool), String, String, String)
  GetSubRedditsFeed(Subject(List(#(String, Int))))
  Shutdown
}
