import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/time/timestamp
import glearray.{type Array}

import gossip_worker.{
  type GossipWorkerSubject, SendGossip, UpdateGPNeighborsList,
}
import sum_worker.{
  type SumWorkerSubject, GetAverage, SendSumValues, UpdatePSNeighborsList,
}
import utils.{
  type Algorithm, type Topology, Full, Gossip, Imp3D, Line, PushSum, ThreeD,
  get_cube_root,
}

pub fn bootstrap(
  num_nodes: Int,
  topology: Topology,
  algorithm: Algorithm,
) -> Nil {
  let before_time: Float = timestamp.to_unix_seconds(timestamp.system_time())

  let waiting_subj: Subject(Bool) = process.new_subject()
  let nodes_list: List(Int) = list.range(from: 1, to: num_nodes)

  case algorithm {
    Gossip -> {
      let gp_nodes_map: Dict(Int, GossipWorkerSubject) =
        dict.from_list(
          list.map(nodes_list, fn(idx: Int) {
            #(idx, gossip_worker.start_gossip_worker())
          }),
        )
      list.each(nodes_list, fn(idx: Int) {
        let assert Ok(current_actor_subj) = dict.get(gp_nodes_map, idx)
        let neighbors_list: Array(Int) =
          glearray.from_list(get_neighbors_list(
            idx,
            num_nodes,
            nodes_list,
            topology,
          ))
        let neighbors_subj_map: Dict(Int, GossipWorkerSubject) =
          dict.from_list(
            list.map(
              list.range(from: 0, to: glearray.length(neighbors_list) - 1),
              fn(neighbor_idx: Int) {
                let assert Ok(neighbor_pos) =
                  glearray.get(neighbors_list, neighbor_idx)
                let assert Ok(neighbor_actor_subj) =
                  dict.get(gp_nodes_map, neighbor_pos)
                #(neighbor_idx + 1, neighbor_actor_subj)
              },
            ),
          )
        let assert Ok(True) =
          process.call(current_actor_subj, 100, UpdateGPNeighborsList(
            _,
            neighbors_subj_map,
          ))
      })

      let elapsed_time: Float =
        timestamp.to_unix_seconds(timestamp.system_time()) -. before_time
      io.println(
        "Elapsed time for setting the topology: "
        <> float.to_string(elapsed_time),
      )

      io.println("Starting gossip protocol")
      let assert Ok(actor_subj) = dict.get(gp_nodes_map, 1)
      process.send(actor_subj, SendGossip("gossip", actor_subj, waiting_subj))
      wait_till_completion(waiting_subj, num_nodes)
    }
    PushSum -> {
      let ps_nodes_map: Dict(Int, SumWorkerSubject) =
        dict.from_list(
          list.map(nodes_list, fn(idx: Int) {
            #(idx, sum_worker.start_sum_worker(idx))
          }),
        )
      list.each(nodes_list, fn(idx: Int) {
        let assert Ok(current_actor_subj) = dict.get(ps_nodes_map, idx)
        let neighbors_list: Array(Int) =
          glearray.from_list(get_neighbors_list(
            idx,
            num_nodes,
            nodes_list,
            topology,
          ))
        let neighbors_subj_map: Dict(Int, SumWorkerSubject) =
          dict.from_list(
            list.map(
              list.range(from: 0, to: glearray.length(neighbors_list) - 1),
              fn(neighbor_idx: Int) {
                let assert Ok(neighbor_pos) =
                  glearray.get(neighbors_list, neighbor_idx)
                let assert Ok(neighbor_actor_subj) =
                  dict.get(ps_nodes_map, neighbor_pos)
                #(neighbor_idx + 1, neighbor_actor_subj)
              },
            ),
          )
        let assert Ok(True) =
          process.call(current_actor_subj, 100, UpdatePSNeighborsList(
            _,
            neighbors_subj_map,
          ))
      })

      let elapsed_time: Float =
        timestamp.to_unix_seconds(timestamp.system_time()) -. before_time
      io.println(
        "Elapsed time for setting the topology: "
        <> float.to_string(elapsed_time),
      )

      io.println("Starting push-sum protocol")
      let assert Ok(actor_subj) = dict.get(ps_nodes_map, 1)
      process.send(
        actor_subj,
        SendSumValues(0.0, 0.0, actor_subj, waiting_subj),
      )
      wait_till_completion(waiting_subj, num_nodes)
      let assert Ok(average) = process.call(actor_subj, 50, GetAverage)
      io.println(
        "Sum: "
        <> int.to_string(float.round(average *. int.to_float(num_nodes))),
      )
    }
  }

  let convergence_time: Float =
    timestamp.to_unix_seconds(timestamp.system_time()) -. before_time
  io.println(
    "Convergence time for protocol: "
    <> utils.algorithm_to_string(algorithm)
    <> " topology: "
    <> utils.topology_to_string(topology)
    <> " is: "
    <> float.to_string(convergence_time)
    <> "s",
  )
}

fn get_neighbors_list(
  current_idx: Int,
  num_nodes: Int,
  nodes_list: List(Int),
  topology: Topology,
) -> List(Int) {
  case topology {
    Full ->
      list.filter(nodes_list, fn(node_idx: Int) { node_idx != current_idx })
    Line -> {
      case current_idx == 1 {
        True -> [current_idx + 1]
        False -> {
          case current_idx == num_nodes {
            True -> [current_idx - 1]
            False -> [current_idx - 1, current_idx + 1]
          }
        }
      }
    }
    ThreeD -> get_neighbors_3d_list(current_idx, num_nodes)
    Imp3D -> {
      nodes_list
    }
  }
}

fn wait_till_completion(waiting_subj: Subject(Bool), total_workers: Int) -> Nil {
  case process.receive(waiting_subj, within: 1000) {
    Ok(sent) -> sent
    Error(_) -> False
  }

  case total_workers > 1 {
    True -> wait_till_completion(waiting_subj, total_workers - 1)
    False -> {
      io.println("Computation completed")
    }
  }
}

fn get_neighbors_3d_list(current_idx: Int, num_nodes: Int) -> List(Int) {
  let assert Ok(num_nodes_cr) = get_cube_root(num_nodes, 1)
  let num_nodes_cr_square: Int = num_nodes_cr * num_nodes_cr

  let neighbors_list: List(Int) = []

  // positive-x
  let assert Ok(px_remainder) = int.remainder(current_idx, by: num_nodes_cr)
  let neighbors_list = case px_remainder {
    0 -> neighbors_list
    _ -> list.append(neighbors_list, [current_idx + 1])
  }
  // negative-x
  let assert Ok(nx_remainder) = int.remainder(current_idx, by: num_nodes_cr)
  let neighbors_list = case nx_remainder {
    1 -> neighbors_list
    _ -> list.append(neighbors_list, [current_idx - 1])
  }
  // positive-y
  let assert Ok(py_remainder) =
    int.remainder(current_idx, by: num_nodes_cr_square)
  let neighbors_list = case py_remainder {
    0 -> neighbors_list
    _ ->
      case py_remainder + num_nodes_cr <= num_nodes_cr_square {
        True -> list.append(neighbors_list, [current_idx + num_nodes_cr])
        False -> neighbors_list
      }
  }
  // negative-y
  let assert Ok(ny_remainder) =
    int.remainder(current_idx, by: num_nodes_cr_square)
  let neighbors_list = case ny_remainder {
    0 -> list.append(neighbors_list, [current_idx - num_nodes_cr])
    _ ->
      case ny_remainder - num_nodes_cr > 0 {
        True -> list.append(neighbors_list, [current_idx - num_nodes_cr])
        False -> neighbors_list
      }
  }
  // positive-z
  let neighbors_list = case current_idx + num_nodes_cr_square <= num_nodes {
    True -> list.append(neighbors_list, [current_idx + num_nodes_cr_square])
    False -> neighbors_list
  }
  // negative-z
  let neighbors_list = case current_idx - num_nodes_cr_square > 0 {
    True -> list.append(neighbors_list, [current_idx - num_nodes_cr_square])
    False -> neighbors_list
  }

  neighbors_list
}
