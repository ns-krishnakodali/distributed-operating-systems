import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor

import collector
import sum_worker

// const tasks_per_worker = 1024

pub fn bootstrap(n: Int, k: Int) -> Nil {
  let collector_subj = collector.start_and_get_subj()

  let worker_subj = sum_worker.start_and_get_subj(collector_subj)
  let tasks_list: List(Int) = list.range(from: 1, to: n)
  process.send(worker_subj, sum_worker.ComputeSum(tasks_list, n, k))

  let ps_list =
    actor.call(collector_subj, waiting: 10_000, sending: collector.Get)

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
