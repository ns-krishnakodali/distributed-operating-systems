import argv
import gleam/float
import gleam/int
import gleam/io
import gleam/string
import gleam/time/timestamp

pub fn main() -> Nil {
  let _drop_node_simulation: Bool = case argv.load().arguments {
    ["drop_node"] -> True
    _ -> False
  }
  let line: String = get_line("Enter Inputs: \n")
  case parse_input_line(line) {
    Ok(values) -> {
      let #(_nn, _nr) = values
      let before_time: Float =
        timestamp.to_unix_seconds(timestamp.system_time())
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
    [num_nodes, num_requests] -> {
      case int.parse(num_nodes) {
        Ok(nn) ->
          case int.parse(string.replace(num_requests, each: "\n", with: "")) {
            Ok(nr) -> Ok(#(nn, nr))
            Error(_) -> Error("num_requests must be a valid integer")
          }
        Error(_) -> Error("num_nodes must be a valid integer")
      }
    }
    _ -> Error("Input must be 'num_nodes num_requests'")
  }
}
