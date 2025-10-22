import gleam/erlang/process.{type Subject}

// user_name, user_id, subreddit_ids, post_ids, comment_ids, post_feed_ids
pub type ClientWorkerState =
  #(String, String, List(String), List(String), List(String), List(String))

pub type ClientWorkerSubject =
  Subject(ClientWorkerMessage)

pub type ClientWorkerMessage {
  Shutdown
}
