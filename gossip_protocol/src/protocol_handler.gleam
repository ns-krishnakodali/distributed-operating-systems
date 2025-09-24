import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/set
import gleam/time/timestamp
import glearray.{type Array}

import gossip_worker.{
  type GossipWorkerSubject, GetGossip, SendGossip, SetGPNeighborsData,
}
import sum_worker.{
  type SumWorkerSubject, GetAverage, SendSumValues, SetPSNeighborsData,
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

  let waiting_subj: Subject(Int) = process.new_subject()
  let nodes_list: List(Int) = list.range(from: 1, to: num_nodes)

  case algorithm {
    Gossip -> {
      let gp_nodes_map: Dict(Int, GossipWorkerSubject) =
        dict.from_list(
          list.map(nodes_list, fn(idx: Int) {
            #(idx, gossip_worker.start_gossip_worker(idx))
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
          process.call(current_actor_subj, 100, SetGPNeighborsData(
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
      process.send(actor_subj, SendGossip("gossip_rumor", waiting_subj))
      wait_till_completion(waiting_subj, set.new(), num_nodes)
      case topology {
        Full -> {
          let random_idx: Int = int.random(num_nodes) + 1
          let assert Ok(last_actor_subj) = dict.get(gp_nodes_map, random_idx)
          let rumor: String = process.call(last_actor_subj, 50, GetGossip)
          io.println("Rumor gossiped: " <> rumor)
        }
        Line | ThreeD | Imp3D -> {
          let assert Ok(last_actor_subj) = dict.get(gp_nodes_map, num_nodes)
          let rumor: String = process.call(last_actor_subj, 50, GetGossip)
          io.println("Rumor gossiped: " <> rumor)
        }
      }
      list.each(dict.values(gp_nodes_map), fn(actor_subj: GossipWorkerSubject) {
        process.send(actor_subj, gossip_worker.Shutdown)
      })
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
          process.call(current_actor_subj, 100, SetPSNeighborsData(
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
      process.send(actor_subj, SendSumValues(0.0, 0.0, waiting_subj))
      wait_till_completion(waiting_subj, set.new(), num_nodes)
      let assert Ok(average) = process.call(actor_subj, 50, GetAverage)
      io.println(
        "Total Sum: "
        <> int.to_string(float.round(average *. int.to_float(num_nodes))),
      )
      list.each(dict.values(ps_nodes_map), fn(actor_subj: SumWorkerSubject) {
        process.send(actor_subj, sum_worker.Shutdown)
      })
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

fn wait_till_completion(
  waiting_subj: Subject(Int),
  actors_data: set.Set(Int),
  num_nodes: Int,
) -> Nil {
  let updated_actors_data: set.Set(Int) = case
    process.receive(waiting_subj, within: 1000)
  {
    Ok(actor_idx) -> {
      set.insert(actors_data, actor_idx)
    }
    Error(_) -> actors_data
  }

  case set.size(updated_actors_data) < num_nodes {
    True -> wait_till_completion(waiting_subj, updated_actors_data, num_nodes)
    False -> {
      io.println("Computation completed")
    }
  }
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
      let neighbors_list: List(Int) =
        get_neighbors_3d_list(current_idx, num_nodes)
      let random_neighbor: Int =
        random_valid_neighbor(neighbors_list, num_nodes)
      list.append(neighbors_list, [random_neighbor])
    }
  }
}

fn random_valid_neighbor(neighbors_list: List(Int), num_nodes: Int) -> Int {
  let random_number: Int = int.random(num_nodes) + 1
  case list.contains(neighbors_list, random_number) {
    True -> random_valid_neighbor(neighbors_list, num_nodes)
    False -> random_number
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
