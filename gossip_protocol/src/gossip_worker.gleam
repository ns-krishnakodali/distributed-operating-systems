import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/otp/actor

pub fn start_gossip_worker(idx: Int) -> GossipWorkerSubject {
  let neighbors_dict: Dict(Int, GossipWorkerSubject) = dict.from_list([])

  let assert Ok(actor) =
    actor.new(#(neighbors_dict, idx, "", 0))
    |> actor.on_message(handle_message)
    |> actor.start

  actor.data
}

fn handle_message(
  state: GossipWorkerState,
  w_message: GossipWorkerMessage,
) -> actor.Next(GossipWorkerState, GossipWorkerMessage) {
  case w_message {
    SendGossip(message, waiting_subj) -> {
      let #(neighbors_data, current_idx, _, w_rounds) = state
      let updated_rounds: Int = case w_rounds < 10 {
        True -> {
          w_rounds + 1
        }
        False -> {
          process.send(waiting_subj, current_idx)
          w_rounds
        }
      }

      let random_neighbor_idx: Int = int.random(dict.size(neighbors_data)) + 1
      let assert Ok(random_neighbor_subj) =
        dict.get(neighbors_data, random_neighbor_idx)
      process.send(
        random_neighbor_subj,
        SendGossip("gossip_rumor", waiting_subj),
      )
      actor.continue(#(neighbors_data, current_idx, message, updated_rounds))
    }
    SetGPNeighborsData(reply_subj, neighbors_data) -> {
      let #(_, current_idx, message, rounds) = state
      process.send(reply_subj, Ok(True))
      actor.continue(#(neighbors_data, current_idx, message, rounds))
    }
    RemoveNeighbor(neighbor_actor_subj) -> {
      let #(neighbors_data, current_idx, message, rounds) = state
      case dict.size(neighbors_data) == 1 {
        True -> actor.continue(state)
        False -> {
          let last_neighbors_idx: Int = dict.size(neighbors_data)
          let removed_neighbor: Dict(Int, GossipWorkerSubject) =
            dict.filter(neighbors_data, fn(_, actor_subj: GossipWorkerSubject) {
              actor_subj == neighbor_actor_subj
            })
          let mod_neighbors_data: Dict(Int, GossipWorkerSubject) = case
            list.first(dict.keys(removed_neighbor))
          {
            Ok(neighbor_idx) -> {
              let assert Ok(last_neighbor_subj) =
                dict.get(neighbors_data, last_neighbors_idx)
              let new_neighbors_data: Dict(Int, GossipWorkerSubject) =
                dict.insert(neighbors_data, neighbor_idx, last_neighbor_subj)
              dict.delete(new_neighbors_data, last_neighbors_idx)
            }
            Error(_) -> {
              neighbors_data
            }
          }
          actor.continue(#(mod_neighbors_data, current_idx, message, rounds))
        }
      }
    }
    GetGossip(return_subj) -> {
      let #(_, _, gossip, _) = state
      process.send(return_subj, gossip)
      actor.stop()
    }
    Shutdown -> {
      actor.stop()
    }
  }
}

pub type GossipWorkerState =
  #(Dict(Int, GossipWorkerSubject), Int, String, Int)

pub type GossipWorkerSubject =
  Subject(GossipWorkerMessage)

pub type GossipWorkerMessage {
  SendGossip(String, Subject(Int))
  SetGPNeighborsData(Subject(Result(Bool, Nil)), Dict(Int, GossipWorkerSubject))
  RemoveNeighbor(GossipWorkerSubject)
  GetGossip(Subject(String))
  Shutdown
}
