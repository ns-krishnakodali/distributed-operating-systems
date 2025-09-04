import gleam/float
import gleam/int
import gleam/io
import gleam/string
import gleam/time/timestamp

import sum_supervisor

pub fn main() -> Nil {
  let line: String = get_line("Enter Inputs: \n")
  case get_input_list(line) {
    Ok(pair) -> {
      let #(n, k) = pair
      case k <= n {
        True -> {
          let before_time: Float =
            timestamp.to_unix_seconds(timestamp.system_time())
          sum_supervisor.bootstrap(n, k)
          let execution_time: Float =
            timestamp.to_unix_seconds(timestamp.system_time()) -. before_time
          io.println("Execution Time: " <> float.to_string(execution_time))
        }
        False -> {
          io.println("Invalid inputs, k must be less than n")
        }
      }
    }
    Error(msg) -> {
      io.println("Error: " <> msg)
    }
  }
}

@external(erlang, "io", "get_line")
fn get_line(prompt: String) -> String

fn get_input_list(line: String) -> Result(#(Int, Int), String) {
  let inputs: List(String) = string.split(line, on: " ")
  case inputs {
    [n_str, k_str] ->
      case int.parse(n_str) {
        Ok(n) ->
          case int.parse(string.replace(k_str, each: "\n", with: "")) {
            Ok(k) -> Ok(#(n, k))
            Error(_) -> Error("k is not a valid integer")
          }
        Error(_) -> Error("n is not a valid integer")
      }
    _ -> Error("Input must be 'lukas n k'")
  }
}
