import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor

import collector
import sum_worker

// const tasks_per_worker = 1024

pub fn bootstrap(n: Int, k: Int) -> Nil {
  let collector_subj = collector.get_subject()
  list.range(0, n - 1)
  |> list.each(fn(idx) {
    let worker_subj = sum_worker.get_subject()
    process.send(
      worker_subj,
      sum_worker.ComputeSum(collector_subj, idx, idx + k),
    )
  })

  let ps_list =
    actor.call(collector_subj, waiting: 10_000, sending: collector.Get)
  list.each(ps_list, fn(idx) { io.println(int.to_string(idx)) })
}
