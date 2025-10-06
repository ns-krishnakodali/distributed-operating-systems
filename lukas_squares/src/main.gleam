import gleam/float
import gleam/int
import gleam/io
import gleam/string
import gleam/time/timestamp

import runner

pub fn main() -> Nil {
  let line: String = get_line("Enter Inputs: \n")
  case parse_input_line(line) {
    Ok(pair) -> {
      let #(n, k) = pair
      let before_time: Float =
        timestamp.to_unix_seconds(timestamp.system_time())
      runner.bootstrap(n, k)
      let execution_time: Float =
        timestamp.to_unix_seconds(timestamp.system_time()) -. before_time
      io.println("Execution Time: " <> float.to_string(execution_time))
    }
    Error(msg) -> {
      io.println("Error: " <> msg)
    }
  }
}

@external(erlang, "io", "get_line")
fn get_line(prompt: String) -> String

fn parse_input_line(line: String) -> Result(#(Int, Int), String) {
  let inputs: List(String) = string.split(line, on: " ")
  case inputs {
    ["lukas", n_str, k_str] ->
      case int.parse(n_str) {
        Ok(n) ->
          case int.parse(string.replace(k_str, each: "\n", with: "")) {
            Ok(k) -> Ok(#(n, k))
            Error(_) -> Error("k must be a valid integer")
          }
        Error(_) -> Error("n must be a valid integer")
      }
    _ -> Error("Input must be 'lukas n k'")
  }
}
