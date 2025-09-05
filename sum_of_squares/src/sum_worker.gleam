import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
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
    ComputeSum(n1, n2) -> {
      let squares_diff: Int = sum_of_squares(n2) - sum_of_squares(n1)
      let sqrt_value: Float = case
        float.square_root(int.to_float(squares_diff))
      {
        Ok(value) -> value
        Error(_) -> -1.0
      }
      let floored_sqrt = float.floor(sqrt_value)
      case floored_sqrt == sqrt_value {
        True -> {
          process.send(state, collector.Add(n1 + 1))
        }
        False -> Nil
      }
      actor.continue(state)
    }
    Shutdown -> {
      actor.stop()
    }
  }
}

pub fn sum_of_squares(n: Int) -> Int {
  { n * { n + 1 } * { 2 * n + 1 } / 6 }
}

pub type WorkerMessage {
  ComputeSum(Int, Int)
  Shutdown
}
