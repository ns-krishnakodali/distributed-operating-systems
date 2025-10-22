import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}

import client_worker

// subreddit_id, subreddit_name, users_list
type SubRedditState =
  #(String, String, List(String))

// subreddit_id, post_id, post_text, created_user_id, upvotes, downvotes 
type PostsState =
  #(String, String, String, String, String, Int, Int)

// post_id, parent_comment_id, user_id, upvotes, downvotes 
type CommentsState =
  #(String, String, String, Int, Int)

// user_id_mapping, subreddit_state, posts_state, comments_state
pub type EngineWorkerState =
  #(
    Dict(String, client_worker.ClientWorkerSubject),
    SubRedditState,
    PostsState,
    CommentsState,
  )

pub type EngineWorkerSubject =
  Subject(EngineWorkerMessage)

pub type EngineWorkerMessage {
  Shutdown
}
