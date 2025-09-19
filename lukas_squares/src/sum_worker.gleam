import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/list
import gleam/otp/actor

import collector.{type CollectorSubject}

pub fn start_and_get_subj(collector_subj: CollectorSubject) -> WorkerSubject {
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
    ComputeSum(nums_list, k) -> {
      list.each(nums_list, fn(n1: Int) {
        let squares_sum: Int =
          sum_of_squares(n1 + k - 1) - sum_of_squares(n1 - 1)
        let sqrt_value: Float = case int.square_root(squares_sum) {
          Ok(value) -> value
          Error(_) -> 0.01
        }

        let is_perfect_square: Bool = float.floor(sqrt_value) == sqrt_value
        process.send(state, collector.Add(n1, is_perfect_square))
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

pub type WorkerSubject =
  Subject(WorkerMessage)

pub type WorkerMessage {
  ComputeSum(List(Int), Int)
  Shutdown
}
