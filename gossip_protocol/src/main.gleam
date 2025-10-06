import argv
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleam/time/timestamp

import protocol_handler
import utils.{type Algorithm, type Topology, get_cube_root}

const valid_topologies: List(String) = ["full", "3d", "line", "imp3d"]

const valid_algorithms: List(String) = ["gossip", "push-sum"]

pub fn main() -> Nil {
  let drop_node_simulation: Bool = case argv.load().arguments {
    ["drop_node"] -> True
    _ -> False
  }
  let line: String = get_line("Enter Inputs: \n")
  case parse_input_line(line) {
    Ok(input_values) -> {
      let #(num_nodes, topology, algorithm) = input_values
      let before_time: Float =
        timestamp.to_unix_seconds(timestamp.system_time())
      protocol_handler.bootstrap(
        num_nodes,
        topology,
        algorithm,
        drop_node_simulation,
      )
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

fn parse_input_line(line: String) -> Result(#(Int, Topology, Algorithm), String) {
  let inputs: List(String) = string.split(line, on: " ")
  case inputs {
    [num_nodes, topology, algorithm] ->
      case int.parse(num_nodes) {
        Ok(num_nodes) -> {
          let topology_lc: String = string.lowercase(topology)
          case list.contains(valid_topologies, topology_lc) {
            True -> {
              let is_valid_topology = case topology_lc {
                "3d" | "imp3d" -> {
                  case get_cube_root(num_nodes, 1) {
                    Ok(_) -> True
                    Error(Nil) -> False
                  }
                }
                _ -> True
              }
              let topology_def: Topology = utils.topology_to_type(topology_lc)
              case is_valid_topology {
                True -> {
                  let algorithm_nlc: String =
                    string.lowercase(string.replace(
                      algorithm,
                      each: "\n",
                      with: "",
                    ))
                  case list.contains(valid_algorithms, algorithm_nlc) {
                    True -> {
                      let algorith_def: Algorithm =
                        utils.algorithm_to_type(algorithm_nlc)
                      Ok(#(num_nodes, topology_def, algorith_def))
                    }
                    False -> {
                      Error(
                        "Invalid algorithm, choose be one of '"
                        <> string.join(valid_algorithms, ", ")
                        <> "'",
                      )
                    }
                  }
                }
                False ->
                  Error(
                    "Invalid number of nodes ("
                    <> int.to_string(num_nodes)
                    <> ") for 3D topology, must be a perfect cube",
                  )
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
