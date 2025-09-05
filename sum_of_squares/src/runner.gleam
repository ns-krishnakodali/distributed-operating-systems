import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor

import collector
import sum_worker

const tasks_per_worker = 1024

pub fn spawn_workers(n: Int, k: Int) -> Nil {
  let waiting_subj = process.new_subject()
  let collector_subj = collector.start_and_get_subj(waiting_subj)

  let total_workers: Int =
    float.truncate(float.ceiling(
      int.to_float(n) /. int.to_float(tasks_per_worker),
    ))

  list.range(from: 1, to: total_workers)
  |> list.each(fn(idx: Int) {
    let worker_subj = sum_worker.start_and_get_subj(collector_subj)
    let tasks_list: List(Int) =
      list.range(
        from: idx + { { idx - 1 } * tasks_per_worker },
        to: int.min(n, idx * tasks_per_worker),
      )
    process.send(worker_subj, sum_worker.ComputeSum(tasks_list, k))
  })

  wait_till_completion(waiting_subj, total_workers)

  let ps_list =
    actor.call(collector_subj, waiting: 5000, sending: collector.Get)

  case list.length(ps_list) {
    0 -> {
      io.println("No subsequences found for given inputs")
    }
    _ -> {
      list.each(list.reverse(ps_list), fn(idx) {
        io.print(int.to_string(idx) <> " ")
      })
      io.println("")
    }
  }
}

fn wait_till_completion(waiting_subj: Subject(Bool), total_workers: Int) -> Nil {
  case process.receive(waiting_subj, within: 5000) {
    Ok(sent) -> sent
    Error(_) -> False
  }

  case total_workers > 1 {
    True -> wait_till_completion(waiting_subj, total_workers - 1)
    False -> {
      io.print("")
    }
  }
}
