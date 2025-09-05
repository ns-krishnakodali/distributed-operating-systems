import gleam/erlang/process.{type Subject}
import gleam/otp/actor

pub fn start_and_get_subj() -> Subject(CollectorMessage) {
  let assert Ok(collector_actor) =
    actor.new([])
    |> actor.on_message(handle_message)
    |> actor.start

  collector_actor.data
}

fn handle_message(
  state: List(Int),
  message: CollectorMessage,
) -> actor.Next(List(Int), CollectorMessage) {
  case message {
    Add(v) -> {
      let new_state: List(Int) = [v, ..state]
      actor.continue(new_state)
    }
    Get(reply) -> {
      process.send(reply, state)
      actor.continue(state)
    }
    Shutdown -> {
      actor.stop()
    }
  }
}

pub type CollectorSubject =
  Subject(CollectorMessage)

pub type CollectorMessage {
  Add(Int)
  Get(Subject(List(Int)))
  Shutdown
}
