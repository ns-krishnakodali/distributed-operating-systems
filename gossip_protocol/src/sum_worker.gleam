import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/list
import gleam/otp/actor

pub fn start_and_get_subj(idx: Int) -> SumWorkerSubject {
  let neighbors_dict: Dict(Int, SumWorkerSubject) = dict.from_list([])

  let assert Ok(actor) =
    actor.new(#(neighbors_dict, idx, int.to_float(idx), 1.0, 0))
    |> actor.on_message(handle_message)
    |> actor.start

  actor.data
}

fn handle_message(
  state: SumWorkerState,
  w_message: SumWorkerMessage,
) -> actor.Next(SumWorkerState, SumWorkerMessage) {
  case w_message {
    SendSumValues(sum_a, weight_a, waiting_subj) -> {
      let #(neighbors_data, current_idx, current_sum, current_weight, rounds) =
        state
      let new_sum: Float = current_sum +. sum_a
      let new_weight: Float = current_weight +. weight_a
      let ratio_difference: Float =
        float.absolute_value(
          { new_sum /. new_weight } -. { current_sum /. current_weight },
        )
      let updated_rounds: Int = case ratio_difference == 0.0 {
        True -> rounds
        False -> {
          case ratio_difference <. 1.0e-10 {
            True -> {
              case rounds >= 3 {
                True -> {
                  process.send(waiting_subj, current_idx)
                  rounds
                }
                False -> rounds
              }
            }
            False -> {
              rounds + 1
            }
          }
        }
      }

      let random_neighbor_idx: Int = int.random(dict.size(neighbors_data)) + 1
      let assert Ok(random_neighbor_subj) =
        dict.get(neighbors_data, random_neighbor_idx)
      process.send(
        random_neighbor_subj,
        SendSumValues(new_sum /. 2.0, new_weight /. 2.0, waiting_subj),
      )
      actor.continue(#(
        neighbors_data,
        current_idx,
        new_sum /. 2.0,
        new_weight /. 2.0,
        updated_rounds,
      ))
    }
    SetPSNeighborsData(reply_subj, neighbors_data) -> {
      let #(_, current_idx, sum, weight, rounds) = state
      process.send(reply_subj, True)
      actor.continue(#(neighbors_data, current_idx, sum, weight, rounds))
    }
    GetAverage(reply_subj) -> {
      let #(_, _, sum, weight, _) = state
      process.send(reply_subj, Ok(sum /. weight))
      actor.continue(state)
    }
    RemoveNeighbor(reply_subj, neighbor_actor_subj) -> {
      let #(neighbors_data, current_idx, sum, weight, rounds) = state
      case dict.size(neighbors_data) == 1 {
        True -> {
          process.send(reply_subj, False)
          actor.continue(state)
        }
        False -> {
          let last_neighbors_idx: Int = dict.size(neighbors_data)
          let removed_neighbor: Dict(Int, SumWorkerSubject) =
            dict.filter(neighbors_data, fn(_, actor_subj: SumWorkerSubject) {
              actor_subj == neighbor_actor_subj
            })
          let mod_neighbors_data: Dict(Int, SumWorkerSubject) = case
            list.first(dict.keys(removed_neighbor))
          {
            Ok(neighbor_idx) -> {
              let assert Ok(last_neighbor_subj) =
                dict.get(neighbors_data, last_neighbors_idx)
              let new_neighbors_data: Dict(Int, SumWorkerSubject) =
                dict.insert(neighbors_data, neighbor_idx, last_neighbor_subj)
              dict.delete(new_neighbors_data, last_neighbors_idx)
            }
            Error(_) -> {
              neighbors_data
            }
          }
          process.send(reply_subj, True)
          actor.continue(#(mod_neighbors_data, current_idx, sum, weight, rounds))
        }
      }
    }
    DropNode(reply_subj, current_actor_subj, waiting_subj) -> {
      let #(neighbors_data, _, _, _, _) = state
      let all_nodes_dropped: Bool =
        list.all(
          list.map(dict.values(neighbors_data), fn(actor_subj) {
            process.call(actor_subj, 50, RemoveNeighbor(_, current_actor_subj))
          }),
          fn(status: Bool) { status == True },
        )
      case all_nodes_dropped {
        True -> {
          let random_idx: Int = int.random(dict.size(neighbors_data)) + 1
          let assert Ok(random_neighbor_subj) =
            dict.get(neighbors_data, random_idx)
          process.send(
            random_neighbor_subj,
            SendSumValues(0.0, 0.0, waiting_subj),
          )
          process.send(reply_subj, True)
          actor.stop()
        }
        False -> {
          process.send(reply_subj, False)
          actor.continue(state)
        }
      }
    }
    Shutdown -> {
      actor.stop()
    }
  }
}

pub type SumWorkerState =
  #(Dict(Int, SumWorkerSubject), Int, Float, Float, Int)

pub type SumWorkerSubject =
  Subject(SumWorkerMessage)

pub type SumWorkerMessage {
  SendSumValues(Float, Float, Subject(Int))
  SetPSNeighborsData(Subject(Bool), Dict(Int, SumWorkerSubject))
  GetAverage(Subject(Result(Float, Nil)))
  RemoveNeighbor(Subject(Bool), SumWorkerSubject)
  DropNode(Subject(Bool), SumWorkerSubject, Subject(Int))
  Shutdown
}
