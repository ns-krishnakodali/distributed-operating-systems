import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleam/time/timestamp

import protocol_handler

const valid_topologies: List(String) = ["full", "3d", "line", "imp3d"]

const valid_algorithms: List(String) = ["gossip", "push-sum"]

pub fn main() -> Nil {
  let line: String = get_line("Enter Inputs: \n")
  case get_input_values(line) {
    Ok(input_values) -> {
      let #(num_nodes, topology, algorithm) = input_values
      let before_time: Float =
        timestamp.to_unix_seconds(timestamp.system_time())
      protocol_handler.bootstrap(num_nodes, topology, algorithm)
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
          let topology_lc: String = string.lowercase(topology)
          case list.contains(valid_topologies, topology_lc) {
            True -> {
              let algorithm_nlc: String =
                string.lowercase(string.replace(algorithm, each: "\n", with: ""))
              case list.contains(valid_algorithms, algorithm_nlc) {
                True -> Ok(#(num_nodes, topology_lc, algorithm_nlc))
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
