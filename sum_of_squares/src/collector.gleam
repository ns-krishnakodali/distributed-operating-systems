import gleam/erlang/process.{type Subject}
import gleam/otp/actor

pub fn start_and_get_subj(
  waiting_subj: Subject(Bool),
) -> Subject(CollectorMessage) {
  let assert Ok(collector_actor) =
    actor.new(#(waiting_subj, []))
    |> actor.on_message(handle_message)
    |> actor.start

  collector_actor.data
}

fn handle_message(
  state: #(Subject(Bool), List(Int)),
  message: CollectorMessage,
) -> actor.Next(#(Subject(Bool), List(Int)), CollectorMessage) {
  case message {
    Add(v) -> {
      let #(subject, collection) = state
      let new_collection: List(Int) = [v, ..collection]
      process.send(subject, True)
      actor.continue(#(subject, new_collection))
    }
    Get(reply) -> {
      let #(_, collection) = state
      process.send(reply, collection)
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
