import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/list
import gleam/otp/actor

pub fn start_sum_worker(idx: Int) -> SumWorkerSubject {
  let neighbors_dict: Dict(Int, SumWorkerSubject) = dict.from_list([])

  let assert Ok(actor) =
    actor.new(#(neighbors_dict, int.to_float(idx), 1.0, 0))
    |> actor.on_message(handle_message)
    |> actor.start

  actor.data
}

fn handle_message(
  state: SumWorkerState,
  w_message: SumWorkerMessage,
) -> actor.Next(SumWorkerState, SumWorkerMessage) {
  case w_message {
    SendSumValues(sum_a, weight_a, current_actor_subj, waiting_subj) -> {
      let #(neighbors_data, current_sum, current_weight, rounds) = state
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
                  list.each(
                    dict.values(neighbors_data),
                    fn(actor_subj: SumWorkerSubject) {
                      process.send(
                        actor_subj,
                        RemoveNeighbor(current_actor_subj),
                      )
                    },
                  )
                  process.send(waiting_subj, True)
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
        SendSumValues(
          new_sum /. 2.0,
          new_weight /. 2.0,
          random_neighbor_subj,
          waiting_subj,
        ),
      )
      actor.continue(#(
        neighbors_data,
        new_sum /. 2.0,
        new_weight /. 2.0,
        updated_rounds,
      ))
    }
    SetPSNeighborsData(reply_subj, neighbors_data) -> {
      let #(_, sum, weight, rounds) = state
      process.send(reply_subj, Ok(True))
      actor.continue(#(neighbors_data, sum, weight, rounds))
    }
    RemoveNeighbor(neighbor_actor_subj) -> {
      let #(neighbors_data, sum, weight, rounds) = state
      case dict.size(neighbors_data) == 1 {
        True -> actor.continue(state)
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
          actor.continue(#(mod_neighbors_data, sum, weight, rounds))
        }
      }
    }
    GetAverage(reply_subj) -> {
      let #(_, sum, weight, _) = state
      process.send(reply_subj, Ok(sum /. weight))
      actor.stop()
    }
    Shutdown -> {
      actor.stop()
    }
  }
}

pub type SumWorkerState =
  #(Dict(Int, SumWorkerSubject), Float, Float, Int)

pub type SumWorkerSubject =
  Subject(SumWorkerMessage)

pub type SumWorkerMessage {
  SendSumValues(Float, Float, SumWorkerSubject, Subject(Bool))
  SetPSNeighborsData(Subject(Result(Bool, Nil)), Dict(Int, SumWorkerSubject))
  RemoveNeighbor(SumWorkerSubject)
  GetAverage(Subject(Result(Float, Nil)))
  Shutdown
}
