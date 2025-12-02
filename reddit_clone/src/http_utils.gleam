import gleam/http.{Get, Post}
import gleam/http/request
import gleam/httpc
import gleam/result

import log

pub fn get_request(url: String, query_params: List(#(String, String))) {
  log.info("Sending GET request to: " <> url)
  let assert Ok(base_request) = request.to(url)

  let get_request: request.Request(String) =
    request.set_method(base_request, Get)
    |> request.prepend_header("content-type", "application/json")
    |> request.set_query(query_params)

  use response <- result.try(httpc.send(get_request))
  Ok(response.body)
}

pub fn post_request(
  url: String,
  body: String,
  query_params: List(#(String, String)),
) {
  log.info("Sending POST request to: " <> url <> " with payload " <> body)
  let assert Ok(base_request) = request.to(url)

  let post_request: request.Request(String) =
    request.set_body(base_request, body)
    |> request.set_method(Post)
    |> request.prepend_header("content-type", "application/json")
    |> request.set_query(query_params)

  use response <- result.try(httpc.send(post_request))
  Ok(response.body)
}
