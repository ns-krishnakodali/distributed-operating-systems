import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/json
import gleam/result
import wisp.{type Request, type Response}

import server/server_worker.{
  type CommentInfo, type PostInfo, type ServerWorkerSubject, type SubRedditInfo,
  type UserMessageInfo,
}
import server/web

pub fn handle_request(
  request: Request,
  server_subj: ServerWorkerSubject,
) -> Response {
  use request <- web.middleware(request)

  case wisp.path_segments(request) {
    // Server health endpoint.
    [] -> health(request)
    // Auth endpoints
    ["login"] -> login_user(request, server_subj)
    ["sign-up"] -> sign_up_user(request, server_subj)
    ["sign-out"] -> sign_out_user(request, server_subj)

    // User endpoints
    ["active-users"] -> get_users(request, server_subj, True)
    ["inactive-users"] -> get_users(request, server_subj, False)
    ["user-subreddits", username] ->
      get_user_subreddits(request, server_subj, username)
    ["user-posts", username] -> get_user_posts(request, server_subj, username)

    // SubReddit endpoints
    ["create-subreddit"] -> create_subreddit(request, server_subj)
    ["subreddits"] -> get_subreddits(request, server_subj)
    ["join-subreddit"] -> join_subreddit(request, server_subj)
    ["leave-subreddit"] -> leave_subreddit(request, server_subj)

    // Post endpoints
    ["post-subreddit"] -> post_subreddit(request, server_subj)
    ["subreddit-posts", subreddit_name] ->
      get_subreddit_posts(request, server_subj, subreddit_name)
    ["posts"] -> get_posts(request, server_subj)
    ["upvote-post", post_id] -> vote_post(request, server_subj, post_id, True)
    ["downvote-post", post_id] ->
      vote_post(request, server_subj, post_id, False)

    // Comment endpoints
    ["comment-post"] -> comment_post(request, server_subj)
    ["post-comments", post_id] ->
      get_post_comments(request, server_subj, post_id)
    ["upvote-comment", post_id] ->
      vote_comment(request, server_subj, post_id, True)
    ["downvote-comment", post_id] ->
      vote_comment(request, server_subj, post_id, False)

    // Message Endpoints
    ["message-user"] -> message_user(request, server_subj)
    ["unread-messages", username] ->
      get_unread_messages(request, server_subj, username)
    _ -> wisp.not_found()
  }
}

fn health(request: Request) -> Response {
  use <- wisp.require_method(request, Get)

  wisp.ok()
  |> wisp.html_body("Server up and running!")
}

fn login_user(request: Request, server_subj: ServerWorkerSubject) -> Response {
  use <- wisp.require_method(request, Post)
  use json_data <- wisp.require_json(request)

  let user_data: Result(User, List(decode.DecodeError)) =
    get_user_data(json_data)
  case user_data {
    Ok(user) -> {
      let username: String = user.username

      let status: Bool =
        process.call(server_subj, 1000, server_worker.LogInUser(
          _,
          username,
          user.password,
        ))
      case status {
        True ->
          wisp.created()
          |> wisp.string_body("User " <> username <> " has logged in successfully")
        False ->
          wisp.bad_request("An issue occured when logging in user " <> username)
      }
    }
    Error(_) -> wisp.unprocessable_content()
  }
}

fn sign_up_user(request: Request, server_subj: ServerWorkerSubject) -> Response {
  use <- wisp.require_method(request, Post)
  use json_data <- wisp.require_json(request)

  let user_data: Result(User, List(decode.DecodeError)) =
    get_user_data(json_data)
  case user_data {
    Ok(user) -> {
      let username: String = user.username

      let status: Bool =
        process.call(server_subj, 1000, server_worker.SignUpUser(
          _,
          username,
          user.password,
        ))
      case status {
        True ->
          wisp.created()
          |> wisp.string_body("User " <> username <> " signed up successfully")
        False ->
          wisp.bad_request("An issue occured when signing up user " <> username)
      }
    }
    Error(_) -> wisp.unprocessable_content()
  }
}

fn sign_out_user(request: Request, server_subj: ServerWorkerSubject) -> Response {
  use <- wisp.require_method(request, Post)
  use json_data <- wisp.require_json(request)

  let user_data: Result(User, List(decode.DecodeError)) =
    get_user_data(json_data)
  case user_data {
    Ok(user) -> {
      let username: String = user.username

      let status: Bool =
        process.call(server_subj, 1000, server_worker.SignOutUser(
          _,
          username,
          user.password,
        ))
      case status {
        True ->
          wisp.created()
          |> wisp.string_body("User " <> username <> " signed out successfully")
        False ->
          wisp.bad_request(
            "An issue occured when signing out user " <> username,
          )
      }
    }
    Error(_) -> wisp.unprocessable_content()
  }
}

fn get_users(
  request: Request,
  server_subj: ServerWorkerSubject,
  active_users: Bool,
) -> Response {
  use <- wisp.require_method(request, Get)

  let usernames_info: List(String) =
    process.call(server_subj, 1000, server_worker.GetUsers(_, active_users))

  let usernames_body =
    json.array(usernames_info, fn(username: String) { json.string(username) })
    |> json.to_string

  wisp.ok()
  |> wisp.json_body(usernames_body)
}

fn get_user_subreddits(
  request: Request,
  server_subj: ServerWorkerSubject,
  username: String,
) -> Response {
  use <- wisp.require_method(request, Get)

  let user_subreddits: List(String) =
    process.call(server_subj, 1000, server_worker.GetUserSubReddits(_, username))

  let user_subreddits_body =
    json.array(user_subreddits, fn(subreddit: String) { json.string(subreddit) })
    |> json.to_string

  wisp.ok()
  |> wisp.json_body(user_subreddits_body)
}

fn get_user_posts(
  request: Request,
  server_subj: ServerWorkerSubject,
  username: String,
) -> Response {
  use <- wisp.require_method(request, Get)

  let user_posts: List(String) =
    process.call(server_subj, 1000, server_worker.GetUserPosts(_, username))

  let user_posts_body =
    json.array(user_posts, fn(post: String) { json.string(post) })
    |> json.to_string

  wisp.ok()
  |> wisp.json_body(user_posts_body)
}

fn create_subreddit(
  request: Request,
  server_subj: ServerWorkerSubject,
) -> Response {
  use <- wisp.require_method(request, Post)
  use json_data <- wisp.require_json(request)

  let subreddit_data: Result(SubReddit, List(decode.DecodeError)) = {
    use user <- result.try(
      decode.run(json_data, {
        use name <- decode.field("name", decode.string)
        use username <- decode.field("username", decode.string)
        use rank <- decode.field("rank", decode.int)
        decode.success(SubReddit(name:, username:, rank:))
      }),
    )
    Ok(user)
  }

  case subreddit_data {
    Ok(subreddit_info) -> {
      let subreddit_name: String = subreddit_info.name
      let username: String = subreddit_info.username

      let status: Bool =
        process.call(server_subj, 1000, server_worker.CreateSubReddit(
          _,
          subreddit_name,
          username,
          subreddit_info.rank,
        ))
      case status {
        True ->
          wisp.created()
          |> wisp.string_body(
            "Subreddit " <> subreddit_name <> " created by user " <> username,
          )
        False ->
          wisp.bad_request(
            "An issue occured when creating subreddit " <> username,
          )
      }
    }
    Error(_) -> wisp.unprocessable_content()
  }
}

fn get_subreddits(
  request: Request,
  server_subj: ServerWorkerSubject,
) -> Response {
  use <- wisp.require_method(request, Get)

  let subreddits_info: List(SubRedditInfo) =
    process.call(server_subj, 1000, server_worker.GetSubRedditsInfo)

  let subreddits_body =
    json.array(subreddits_info, fn(subreddit_info: SubRedditInfo) {
      let #(subreddit_name, rank) = subreddit_info
      json.object([
        #("name", json.string(subreddit_name)),
        #("rank", json.int(rank)),
      ])
    })
    |> json.to_string

  wisp.ok()
  |> wisp.json_body(subreddits_body)
}

fn join_subreddit(
  request: Request,
  server_subj: ServerWorkerSubject,
) -> Response {
  use <- wisp.require_method(request, Post)
  use json_data <- wisp.require_json(request)

  let subreddit_data: Result(UserSubReddit, List(decode.DecodeError)) = {
    use user_subreddit <- result.try(
      decode.run(json_data, {
        use name <- decode.field("name", decode.string)
        use username <- decode.field("username", decode.string)
        decode.success(UserSubReddit(name:, username:))
      }),
    )
    Ok(user_subreddit)
  }
  case subreddit_data {
    Ok(subreddit_info) -> {
      let subreddit_name: String = subreddit_info.name
      let username: String = subreddit_info.username

      let status: Bool =
        process.call(server_subj, 1000, server_worker.JoinSubReddit(
          _,
          subreddit_name,
          username,
        ))
      case status {
        True ->
          wisp.created()
          |> wisp.string_body(
            "User " <> username <> " joined subreddit " <> subreddit_name,
          )
        False ->
          wisp.bad_request(
            "An issue occured when joining subreddit " <> username,
          )
      }
    }
    Error(_) -> wisp.unprocessable_content()
  }
}

fn leave_subreddit(
  request: Request,
  server_subj: ServerWorkerSubject,
) -> Response {
  use <- wisp.require_method(request, Post)
  use json_data <- wisp.require_json(request)

  let subreddit_data: Result(UserSubReddit, List(decode.DecodeError)) = {
    use user <- result.try(
      decode.run(json_data, {
        use name <- decode.field("name", decode.string)
        use username <- decode.field("username", decode.string)
        decode.success(UserSubReddit(name:, username:))
      }),
    )
    Ok(user)
  }
  case subreddit_data {
    Ok(subreddit_info) -> {
      let subreddit_name: String = subreddit_info.name
      let username: String = subreddit_info.username

      let status: Bool =
        process.call(server_subj, 1000, server_worker.LeaveSubReddit(
          _,
          subreddit_name,
          username,
        ))
      case status {
        True ->
          wisp.created()
          |> wisp.string_body(
            "User " <> username <> " left subreddit " <> subreddit_name,
          )
        False ->
          wisp.bad_request(
            "An issue occured when leaving subreddit " <> username,
          )
      }
    }
    Error(_) -> wisp.unprocessable_content()
  }
}

fn post_subreddit(
  request: Request,
  server_subj: ServerWorkerSubject,
) -> Response {
  use <- wisp.require_method(request, Post)
  use json_data <- wisp.require_json(request)

  let subreddit_post_data: Result(SubRedditPost, List(decode.DecodeError)) = {
    use subreddit_post <- result.try(
      decode.run(json_data, {
        use name <- decode.field("name", decode.string)
        use username <- decode.field("username", decode.string)
        use post_description <- decode.field("post_description", decode.string)
        decode.success(SubRedditPost(name:, username:, post_description:))
      }),
    )
    Ok(subreddit_post)
  }
  case subreddit_post_data {
    Ok(subreddit_post_info) -> {
      let subreddit_name: String = subreddit_post_info.name
      let username: String = subreddit_post_info.username

      let status: Bool =
        process.call(server_subj, 1000, server_worker.PostInSubReddit(
          _,
          subreddit_name,
          username,
          subreddit_post_info.post_description,
        ))
      case status {
        True ->
          wisp.created()
          |> wisp.string_body(
            "User " <> username <> " posted in subreddit " <> subreddit_name,
          )
        False ->
          wisp.bad_request(
            "An issue occured when posting in subreddit " <> subreddit_name,
          )
      }
    }
    Error(_) -> wisp.unprocessable_content()
  }
}

fn get_subreddit_posts(
  request: Request,
  server_subj: ServerWorkerSubject,
  subreddit_name: String,
) {
  use <- wisp.require_method(request, Get)

  let subreddits_posts_feed: List(PostInfo) =
    process.call(server_subj, 1000, server_worker.GetSubRedditPostsFeed(
      _,
      subreddit_name,
    ))

  let subreddit_posts_data: String =
    json.array(subreddits_posts_feed, fn(post_info: PostInfo) {
      let #(subreddit_name, post_id, post_description, comment_ids) = post_info
      json.object([
        #("subreddit_name", json.string(subreddit_name)),
        #("post_id", json.string(post_id)),
        #("post_description", json.string(post_description)),
        #("comment_ids", json.array(comment_ids, json.string)),
      ])
    })
    |> json.to_string

  wisp.ok()
  |> wisp.json_body(subreddit_posts_data)
}

fn get_posts(request: Request, server_subj: ServerWorkerSubject) {
  use <- wisp.require_method(request, Get)

  let posts_feed: List(PostInfo) =
    process.call(server_subj, 1000, server_worker.GetPostsFeed)

  let posts_data: String =
    json.array(posts_feed, fn(post_info: PostInfo) {
      let #(subreddit_name, post_id, post_description, comment_ids) = post_info
      json.object([
        #("subreddit_name", json.string(subreddit_name)),
        #("post_id", json.string(post_id)),
        #("post_description", json.string(post_description)),
        #("comment_ids", json.array(comment_ids, json.string)),
      ])
    })
    |> json.to_string

  wisp.ok()
  |> wisp.json_body(posts_data)
}

fn vote_post(
  request: Request,
  server_subj: ServerWorkerSubject,
  post_id: String,
  upvote: Bool,
) {
  use <- wisp.require_method(request, Post)

  let status: Bool = case upvote {
    True ->
      process.call(server_subj, 1000, server_worker.UpVotePost(_, post_id))
    False ->
      process.call(server_subj, 1000, server_worker.DownVotePost(_, post_id))
  }

  case status {
    True ->
      wisp.created()
      |> wisp.string_body("Voted post " <> post_id)
    False -> wisp.bad_request("An issue occured when voting post " <> post_id)
  }
}

fn comment_post(request: Request, server_subj: ServerWorkerSubject) {
  use <- wisp.require_method(request, Post)
  use json_data <- wisp.require_json(request)

  let post_comment_data: Result(PostComment, List(decode.DecodeError)) = {
    use post_comment <- result.try(
      decode.run(json_data, {
        use post_id <- decode.field("post_id", decode.string)
        use parent_comment_id <- decode.field(
          "parent_comment_id",
          decode.string,
        )
        use username <- decode.field("username", decode.string)
        use comment <- decode.field("comment", decode.string)
        decode.success(PostComment(
          post_id:,
          parent_comment_id:,
          username:,
          comment:,
        ))
      }),
    )
    Ok(post_comment)
  }

  case post_comment_data {
    Ok(comment_post_info) -> {
      let post_id: String = comment_post_info.post_id
      let username: String = comment_post_info.username

      let status: Bool =
        process.call(server_subj, 1000, server_worker.CommentOnPost(
          _,
          post_id,
          comment_post_info.parent_comment_id,
          username,
          comment_post_info.comment,
        ))
      case status {
        True ->
          wisp.created()
          |> wisp.string_body(
            "User " <> username <> " commented on post " <> post_id,
          )
        False ->
          wisp.bad_request(
            "An issue occured when commenting on post " <> post_id,
          )
      }
    }
    Error(_) -> wisp.unprocessable_content()
  }
}

fn get_post_comments(
  request: Request,
  server_subj: ServerWorkerSubject,
  post_id: String,
) {
  use <- wisp.require_method(request, Get)

  let post_comments_info: List(CommentInfo) =
    process.call(server_subj, 1000, server_worker.GetPostComments(_, post_id))
  let post_comments_data: String =
    json.array(post_comments_info, fn(comment_info: CommentInfo) {
      let #(post_id, comment_id, parent_comment_id, comment) = comment_info
      json.object([
        #("post_id", json.string(post_id)),
        #("comment_id", json.string(comment_id)),
        #("parent_comment_id", json.string(parent_comment_id)),
        #("comment", json.string(comment)),
      ])
    })
    |> json.to_string

  wisp.ok()
  |> wisp.json_body(post_comments_data)
}

fn vote_comment(
  request: Request,
  server_subj: ServerWorkerSubject,
  comment_id: String,
  upvote: Bool,
) {
  use <- wisp.require_method(request, Post)

  let status: Bool = case upvote {
    True ->
      process.call(server_subj, 1000, server_worker.UpVoteComment(_, comment_id))
    False ->
      process.call(server_subj, 1000, server_worker.DownVoteComment(
        _,
        comment_id,
      ))
  }

  case status {
    True ->
      wisp.created()
      |> wisp.string_body("Voted comment " <> comment_id)
    False ->
      wisp.bad_request("An issue occured when voting comment " <> comment_id)
  }
}

fn message_user(request: Request, server_subj: ServerWorkerSubject) -> Response {
  use <- wisp.require_method(request, Post)
  use json_data <- wisp.require_json(request)

  let user_message_data: Result(UserMessage, List(decode.DecodeError)) = {
    use subreddit_post <- result.try(
      decode.run(json_data, {
        use sender_username <- decode.field("sender_username", decode.string)
        use receiver_username <- decode.field(
          "receiver_username",
          decode.string,
        )
        use message <- decode.field("message", decode.string)
        decode.success(UserMessage(
          sender_username:,
          receiver_username:,
          message:,
        ))
      }),
    )
    Ok(subreddit_post)
  }
  case user_message_data {
    Ok(user_message_info) -> {
      let receiver_username: String = user_message_info.receiver_username

      let status: Bool =
        process.call(server_subj, 1000, server_worker.MessageUser(
          _,
          user_message_info.sender_username,
          receiver_username,
          user_message_info.message,
        ))
      case status {
        True ->
          wisp.created()
          |> wisp.string_body("Message sent to user " <> receiver_username)
        False ->
          wisp.bad_request(
            "An issue occured when sendimg message to user "
            <> receiver_username,
          )
      }
    }
    Error(_) -> wisp.unprocessable_content()
  }
}

fn get_unread_messages(
  request: Request,
  server_subj: ServerWorkerSubject,
  username: String,
) {
  use <- wisp.require_method(request, Get)

  let user_messages_info: List(UserMessageInfo) =
    process.call(server_subj, 1000, server_worker.GetUnreadMessages(_, username))
  let user_messages_data: String =
    json.array(user_messages_info, fn(user_message_info: UserMessageInfo) {
      let #(sender_username, message, timestamp) = user_message_info
      json.object([
        #("sender_username", json.string(sender_username)),
        #("message", json.string(message)),
        #("timestamp", json.float(timestamp)),
      ])
    })
    |> json.to_string

  wisp.ok()
  |> wisp.json_body(user_messages_data)
}

// Functions to decode JSON data
fn get_user_data(json_data) {
  {
    use user <- result.try(
      decode.run(json_data, {
        use username <- decode.field("username", decode.string)
        use password <- decode.field("password", decode.string)
        decode.success(User(username:, password:))
      }),
    )
    Ok(user)
  }
}

type User {
  User(username: String, password: String)
}

type SubReddit {
  SubReddit(name: String, username: String, rank: Int)
}

type UserSubReddit {
  UserSubReddit(name: String, username: String)
}

type SubRedditPost {
  SubRedditPost(name: String, username: String, post_description: String)
}

type UserMessage {
  UserMessage(
    sender_username: String,
    receiver_username: String,
    message: String,
  )
}

type PostComment {
  PostComment(
    post_id: String,
    parent_comment_id: String,
    username: String,
    comment: String,
  )
}
