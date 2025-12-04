import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/otp/actor

pub fn start_and_get_subj() -> StatisticsWorkerSubject {
  let initial_state: StatisticsState = #(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

  let assert Ok(actor) =
    actor.new(initial_state)
    |> actor.on_message(handle_message)
    |> actor.start

  actor.data
}

fn handle_message(
  state: StatisticsState,
  message: StatisticsWorkerMessage,
) -> actor.Next(StatisticsState, StatisticsWorkerMessage) {
  let #(
    num_users,
    num_subreddits,
    num_posts,
    num_authentications,
    num_subscriptions,
    num_post_downloads,
    num_post_upvotes,
    num_post_downvotes,
    num_comment_upvotes,
    num_comment_downvotes,
    num_messages_sent,
  ) = state

  case message {
    IncrementUsers -> {
      let updated_state: StatisticsState = #(
        num_users + 1,
        num_subreddits,
        num_posts,
        num_authentications,
        num_subscriptions,
        num_post_downloads,
        num_post_upvotes,
        num_post_downvotes,
        num_comment_upvotes,
        num_comment_downvotes,
        num_messages_sent,
      )

      actor.continue(updated_state)
    }
    DecrementUsers -> {
      let updated_users: Int = case num_users > 0 {
        True -> num_users - 1
        False -> 0
      }
      let updated_state: StatisticsState = #(
        updated_users,
        num_subreddits,
        num_posts,
        num_authentications,
        num_subscriptions,
        num_post_downloads,
        num_post_upvotes,
        num_post_downvotes,
        num_comment_upvotes,
        num_comment_downvotes,
        num_messages_sent,
      )

      actor.continue(updated_state)
    }
    IncrementPosts -> {
      let updated_state: StatisticsState = #(
        num_users,
        num_subreddits,
        num_posts + 1,
        num_authentications,
        num_subscriptions,
        num_post_downloads,
        num_post_upvotes,
        num_post_downvotes,
        num_comment_upvotes,
        num_comment_downvotes,
        num_messages_sent,
      )

      actor.continue(updated_state)
    }
    DecrementPosts -> {
      let updated_posts: Int = case num_posts > 0 {
        True -> num_posts - 1
        False -> 0
      }
      let updated_state: StatisticsState = #(
        num_users,
        num_subreddits,
        updated_posts,
        num_authentications,
        num_subscriptions,
        num_post_downloads,
        num_post_upvotes,
        num_post_downvotes,
        num_comment_upvotes,
        num_comment_downvotes,
        num_messages_sent,
      )

      actor.continue(updated_state)
    }
    IncrementSubReddits -> {
      let updated_state: StatisticsState = #(
        num_users,
        num_subreddits + 1,
        num_posts,
        num_authentications,
        num_subscriptions,
        num_post_downloads,
        num_post_upvotes,
        num_post_downvotes,
        num_comment_upvotes,
        num_comment_downvotes,
        num_messages_sent,
      )

      actor.continue(updated_state)
    }
    DecrementSubReddits -> {
      let updated_subreddits: Int = case num_subreddits > 0 {
        True -> num_subreddits - 1
        False -> 0
      }
      let updated_state: StatisticsState = #(
        num_users,
        updated_subreddits,
        num_posts,
        num_authentications,
        num_subscriptions,
        num_post_downloads,
        num_post_upvotes,
        num_post_downvotes,
        num_comment_upvotes,
        num_comment_downvotes,
        num_messages_sent,
      )

      actor.continue(updated_state)
    }
    IncrementAuthentications -> {
      let updated_state: StatisticsState = #(
        num_users,
        num_subreddits,
        num_posts,
        num_authentications + 1,
        num_subscriptions,
        num_post_downloads,
        num_post_upvotes,
        num_post_downvotes,
        num_comment_upvotes,
        num_comment_downvotes,
        num_messages_sent,
      )

      actor.continue(updated_state)
    }
    IncrementSubscriptions -> {
      let updated_state: StatisticsState = #(
        num_users,
        num_subreddits,
        num_posts,
        num_authentications,
        num_subscriptions + 1,
        num_post_downloads,
        num_post_upvotes,
        num_post_downvotes,
        num_comment_upvotes,
        num_comment_downvotes,
        num_messages_sent,
      )

      actor.continue(updated_state)
    }
    DecrementSubscriptions -> {
      let updated_state: StatisticsState = #(
        num_users,
        num_subreddits,
        num_posts,
        num_authentications,
        num_subscriptions - 1,
        num_post_downloads,
        num_post_upvotes,
        num_post_downvotes,
        num_comment_upvotes,
        num_comment_downvotes,
        num_messages_sent,
      )

      actor.continue(updated_state)
    }
    IncrementPostDownloads -> {
      let updated_state: StatisticsState = #(
        num_users,
        num_subreddits,
        num_posts,
        num_authentications,
        num_subscriptions,
        num_post_downloads + 1,
        num_post_upvotes,
        num_post_downvotes,
        num_comment_upvotes,
        num_comment_downvotes,
        num_messages_sent,
      )

      actor.continue(updated_state)
    }
    IncrementPostUpvotes -> {
      let updated_state: StatisticsState = #(
        num_users,
        num_subreddits,
        num_posts,
        num_authentications,
        num_subscriptions,
        num_post_downloads,
        num_post_upvotes + 1,
        num_post_downvotes,
        num_comment_upvotes,
        num_comment_downvotes,
        num_messages_sent,
      )

      actor.continue(updated_state)
    }
    IncrementPostDownvotes -> {
      let updated_state: StatisticsState = #(
        num_users,
        num_subreddits,
        num_posts,
        num_authentications,
        num_subscriptions,
        num_post_downloads,
        num_post_upvotes,
        num_post_downvotes + 1,
        num_comment_upvotes,
        num_comment_downvotes,
        num_messages_sent,
      )

      actor.continue(updated_state)
    }
    IncrementCommentUpvotes -> {
      let updated_state: StatisticsState = #(
        num_users,
        num_subreddits,
        num_posts,
        num_authentications,
        num_subscriptions,
        num_post_downloads,
        num_post_upvotes,
        num_post_downvotes,
        num_comment_upvotes + 1,
        num_comment_downvotes,
        num_messages_sent,
      )

      actor.continue(updated_state)
    }
    IncrementCommentDownvotes -> {
      let updated_state: StatisticsState = #(
        num_users,
        num_subreddits,
        num_posts,
        num_authentications,
        num_subscriptions,
        num_post_downloads,
        num_post_upvotes,
        num_post_downvotes,
        num_comment_upvotes,
        num_comment_downvotes + 1,
        num_messages_sent,
      )

      actor.continue(updated_state)
    }
    IncrementMessagesSent -> {
      let updated_state: StatisticsState = #(
        num_users,
        num_subreddits,
        num_posts,
        num_authentications,
        num_subscriptions,
        num_post_downloads,
        num_post_upvotes,
        num_post_downvotes,
        num_comment_upvotes,
        num_comment_downvotes,
        num_messages_sent + 1,
      )

      actor.continue(updated_state)
    }
    GetStatistics(reply_subj) -> {
      let #(
        num_users,
        num_subreddits,
        num_posts,
        num_authentications,
        num_subscriptions,
        num_post_downloads,
        num_post_upvotes,
        num_post_downvotes,
        num_comment_upvotes,
        num_comment_downvotes,
        num_messages_sent,
      ) = state

      let stats_message: String =
        "\n=======================\n"
        <> "Number of Users: "
        <> int.to_string(num_users)
        <> "\n"
        <> "Number of SubReddits: "
        <> int.to_string(num_subreddits)
        <> "\n"
        <> "Number of Posts: "
        <> int.to_string(num_posts)
        <> "\n"
        <> "Number of Authentications: "
        <> int.to_string(num_authentications)
        <> "\n"
        <> "Number of Subscriptions: "
        <> int.to_string(num_subscriptions)
        <> "\n"
        <> "Number of Post Downloads: "
        <> int.to_string(num_post_downloads)
        <> "\n"
        <> "Number of Post Up Votes: "
        <> int.to_string(num_post_upvotes)
        <> "\n"
        <> "Number of Post Down Votes: "
        <> int.to_string(num_post_downvotes)
        <> "\n"
        <> "Number of Comment Up Votes: "
        <> int.to_string(num_comment_upvotes)
        <> "\n"
        <> "Number of Comment Down Votes: "
        <> int.to_string(num_comment_downvotes)
        <> "\n"
        <> "Number of Messages Sent: "
        <> int.to_string(num_messages_sent)
        <> "\n"
        <> "======================="
      process.send(reply_subj, stats_message)

      actor.continue(state)
    }
    Shutdown -> {
      actor.stop()
    }
  }
}

// num_users, num_subreddits, num_posts, num_authentications, num_subscriptions, num_post_downloads, 
// num_post_upvotes, num_post_downvotes, num_comment_upvotes, num_comment_downvotes, num_messages_sent
pub type StatisticsState =
  #(Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int)

pub type StatisticsWorkerSubject =
  Subject(StatisticsWorkerMessage)

pub type StatisticsWorkerMessage {
  IncrementUsers
  DecrementUsers
  IncrementPosts
  DecrementPosts
  IncrementSubReddits
  DecrementSubReddits
  IncrementAuthentications
  IncrementSubscriptions
  DecrementSubscriptions
  IncrementPostDownloads
  IncrementPostUpvotes
  IncrementPostDownvotes
  IncrementCommentUpvotes
  IncrementCommentDownvotes
  IncrementMessagesSent
  GetStatistics(Subject(String))
  Shutdown
}
