import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/json
import gleam/result
import wisp.{type Request, type Response}

import server/server_worker.{type ServerWorkerSubject}
import server/web

pub fn handle_request(
  request: Request,
  server_subj: ServerWorkerSubject,
) -> Response {
  use request <- web.middleware(request)

  case wisp.path_segments(request) {
    // Server health endpoint.
    [] -> health(request)
    ["sign-up"] -> sign_up_user(request, server_subj)
    ["sign-out"] -> sign_out_user(request, server_subj)
    ["create-subreddit"] -> create_subreddit(request, server_subj)
    ["subreddits"] -> get_subreddits(request, server_subj)
    ["join-subreddit"] -> join_subreddit(request, server_subj)
    _ -> wisp.not_found()
  }
}

fn health(request: Request) -> Response {
  use <- wisp.require_method(request, Get)

  wisp.ok()
  |> wisp.html_body("Server up and running!")
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

fn create_subreddit(
  request: Request,
  server_subj: ServerWorkerSubject,
) -> Response {
  use <- wisp.require_method(request, Post)
  use json_data <- wisp.require_json(request)

  let subreddit_data: Result(CreateSubReddit, List(decode.DecodeError)) = {
    use user <- result.try(
      decode.run(json_data, {
        use name <- decode.field("name", decode.string)
        use username <- decode.field("username", decode.string)
        use rank <- decode.field("rank", decode.int)
        decode.success(CreateSubReddit(name:, username:, rank:))
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

  let subreddits_info: List(#(String, Int)) =
    process.call(server_subj, 1000, server_worker.GetSubRedditsFeed)

  let subreddits_body =
    json.array(subreddits_info, fn(subreddit_info: #(String, Int)) {
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

  let subreddit_data: Result(JoinSubReddit, List(decode.DecodeError)) = {
    use user <- result.try(
      decode.run(json_data, {
        use name <- decode.field("name", decode.string)
        use username <- decode.field("username", decode.string)
        decode.success(JoinSubReddit(name:, username:))
      }),
    )
    Ok(user)
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
            "User" <> username <> "joined subreddit " <> subreddit_name,
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

type CreateSubReddit {
  CreateSubReddit(name: String, username: String, rank: Int)
}

type JoinSubReddit {
  JoinSubReddit(name: String, username: String)
}
