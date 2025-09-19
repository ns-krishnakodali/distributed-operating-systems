import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/io
import gleam/list
import gleam/time/timestamp
import glearray.{type Array}

import gossip_worker.{type GossipWorkerSubject, SendGossip, UpdateNeighborsList}

pub fn bootstrap(num_nodes: Int, topology: String, algorithm: String) -> Nil {
  let nodes_list: List(Int) = list.range(from: 1, to: num_nodes)

  case algorithm {
    "gossip" -> run_gossip_protocol(num_nodes, topology, nodes_list)
    _ -> Nil
  }
}

fn run_gossip_protocol(
  num_nodes: Int,
  topology: String,
  nodes_list: List(Int),
) -> Nil {
  let before_time: Float = timestamp.to_unix_seconds(timestamp.system_time())

  let waiting_subj: Subject(Bool) = process.new_subject()
  let nodes_map: Dict(Int, GossipWorkerSubject) =
    dict.from_list(
      list.map(nodes_list, fn(idx: Int) {
        #(idx, gossip_worker.start_gossip_worker())
      }),
    )

  list.each(nodes_list, fn(idx: Int) {
    let assert Ok(current_actor_subj) = dict.get(nodes_map, idx)
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
              dict.get(nodes_map, neighbor_pos)
            #(neighbor_idx + 1, neighbor_actor_subj)
          },
        ),
      )
    let assert Ok(True) =
      process.call(current_actor_subj, 100, UpdateNeighborsList(
        _,
        neighbors_subj_map,
      ))
  })

  let elapsed_time: Float =
    timestamp.to_unix_seconds(timestamp.system_time()) -. before_time
  io.println(
    "Elapsed time for setting the topology: " <> float.to_string(elapsed_time),
  )

  io.println("Starting gossip protocol")
  let assert Ok(actor_subj) = dict.get(nodes_map, 1)
  process.send(actor_subj, SendGossip("gossip", actor_subj, waiting_subj))

  wait_till_completion(waiting_subj, num_nodes)
  let protocol_time: Float =
    timestamp.to_unix_seconds(timestamp.system_time()) -. before_time
  io.println(
    "Gossip protocol for "
    <> topology
    <> " topology completed in "
    <> float.to_string(protocol_time),
  )
}

fn get_neighbors_list(
  current_idx: Int,
  num_nodes: Int,
  nodes_list: List(Int),
  topology: String,
) -> List(Int) {
  case topology {
    "full" -> {
      list.filter(nodes_list, fn(node_idx: Int) { node_idx != current_idx })
    }
    "line" -> {
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
    // "3d" -> nodes_list
    // "imp3d" -> nodes_list
    _ -> []
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
