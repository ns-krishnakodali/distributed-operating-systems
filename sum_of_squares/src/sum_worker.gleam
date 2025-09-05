import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/list
import gleam/otp/actor

import collector.{type CollectorSubject}

pub fn start_and_get_subj(
  collector_subj: CollectorSubject,
) -> Subject(WorkerMessage) {
  let assert Ok(actor) =
    actor.new(collector_subj)
    |> actor.on_message(handle_message)
    |> actor.start

  actor.data
}

fn handle_message(
  state: CollectorSubject,
  message: WorkerMessage,
) -> actor.Next(CollectorSubject, WorkerMessage) {
  case message {
    ComputeSum(tasks_list, k) -> {
      list.each(tasks_list, fn(n1: Int) {
        let squares_sum: Int =
          sum_of_squares(n1 + k - 1) - sum_of_squares(n1 - 1)
        let sqrt_value: Float = case int.square_root(squares_sum) {
          Ok(value) -> value
          Error(_) -> -1.0
        }
        case float.floor(sqrt_value) == sqrt_value {
          True -> {
            process.send(state, collector.Add(n1))
          }
          False -> Nil
        }
      })
      actor.continue(state)
    }
    Shutdown -> {
      actor.stop()
    }
  }
}

fn sum_of_squares(n: Int) -> Int {
  { n * { n + 1 } * { 2 * n + 1 } / 6 }
}

pub type WorkerMessage {
  ComputeSum(List(Int), Int)
  Shutdown
}
