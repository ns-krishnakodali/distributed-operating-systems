import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleam/time/timestamp

const valid_topologies: List(String) = ["full", "3D", "line", "imp3D"]

const valid_algorithms: List(String) = ["gossip", "push-sum"]

pub fn main() -> Nil {
  let line: String = get_line("Enter Inputs: \n")
  case get_input_values(line) {
    Ok(input_values) -> {
      let #(num_nodes, topology, algorithm) = input_values
      let before_time: Float =
        timestamp.to_unix_seconds(timestamp.system_time())
      io.println("num_nodes: " <> int.to_string(num_nodes))
      io.println("topology: " <> topology)
      io.println("num_nodes: " <> algorithm)
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

fn get_input_values(line: String) -> Result(#(Int, String, String), String) {
  let inputs: List(String) = string.split(line, on: " ")
  case inputs {
    [num_nodes, topology, algorithm] ->
      case int.parse(num_nodes) {
        Ok(num_nodes) -> {
          case list.contains(valid_topologies, topology) {
            True -> {
              let n_algorithm: String =
                string.replace(algorithm, each: "\n", with: "")
              case list.contains(valid_algorithms, n_algorithm) {
                True -> Ok(#(num_nodes, topology, n_algorithm))
                False -> {
                  Error(
                    "Invalid algorithm, choose be one of '"
                    <> string.join(valid_algorithms, ", ")
                    <> "'",
                  )
                }
              }
            }
            False -> {
              Error(
                "Invalid topology, choose be one of '"
                <> string.join(valid_topologies, ", ")
                <> "'",
              )
            }
          }
        }
        Error(_) -> Error("num_nodesmust be a valid integer")
      }
    _ -> Error("Input must be 'num_nodes topology algorithm'")
  }
}
