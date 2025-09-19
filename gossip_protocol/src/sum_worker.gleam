// import gleam/erlang/process.{type Subject}
// import gleam/otp/actor

// pub fn start_sum_worker(value: Int) -> SumWorkerSubject {
//   let assert Ok(actor) =
//     actor.new(#(value, 1))
//     |> actor.on_message({ todo })
//     |> actor.start

//   actor.data
// }

// pub type SumWorkerSubject =
//   Subject(SumWorkerMessage)

// pub type SumWorkerMessage {
//   AddValues(List(Int), Int)
//   Shutdown
// }
