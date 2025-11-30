import gleam/float
import gleam/int
import gleam/io
import gleam/string
import gleam/time/timestamp

import reddit_simulation

pub fn main() -> Nil {
  let line: String =
    get_line("Enter number of users for simulation (min 100): \n")
  case parse_input_line(line) {
    Ok(num_users) -> {
      let before_time: Float =
        timestamp.to_unix_seconds(timestamp.system_time())

      reddit_simulation.bootstrap_simulation(num_users)

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

fn parse_input_line(line: String) -> Result(Int, String) {
  let input: List(String) = string.split(line, on: " ")
  case input {
    [num_users] -> {
      case int.parse(string.replace(num_users, each: "\n", with: "")) {
        Ok(num_users) -> {
          case num_users >= 100 {
            True -> Ok(num_users)
            False -> Error("Number of users must be at least 100")
          }
        }

        Error(_) -> Error("Number of users must be a valid integer")
      }
    }
    _ -> Error("Invalid input: Provide a single integer value for 'num_users'")
  }
}
