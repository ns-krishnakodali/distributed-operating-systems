import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/io
import gleam/list

import collector.{type CollectorSubject}
import sum_worker.{type WorkerSubject}

const nums_per_worker: Int = 1024

pub fn bootstrap(n: Int, k: Int) -> Nil {
  let waiting_subj: Subject(Bool) = process.new_subject()
  let collector_subj: CollectorSubject =
    collector.start_and_get_subj(waiting_subj)

  spawn_workers(collector_subj, 1, n, n, k)

  wait_till_completion(waiting_subj, n)
  let ps_list: List(Int) = process.call(collector_subj, 5000, collector.Get)

  case list.length(ps_list) {
    0 -> {
      io.println("No subsequences found for given inputs")
    }
    _ -> {
      io.print("Numbers: ")
      list.each(list.reverse(ps_list), fn(val) {
        io.print(int.to_string(val) <> " ")
      })
      io.println("")
    }
  }
}

fn spawn_workers(
  collector_subj: CollectorSubject,
  n1: Int,
  n2: Int,
  n: Int,
  k: Int,
) -> Nil {
  case { n2 - n1 + 1 } <= nums_per_worker {
    True -> {
      let worker_subj: WorkerSubject =
        sum_worker.start_and_get_subj(collector_subj)
      let nums_list: List(Int) = list.range(from: n1, to: n2)
      process.send(worker_subj, sum_worker.ComputeSum(nums_list, k))
    }
    False -> {
      process.spawn(fn() {
        spawn_workers(collector_subj, n1, n1 + nums_per_worker - 1, n, k)
      })
      process.spawn(fn() {
        spawn_workers(collector_subj, n1 + nums_per_worker, n2, n, k)
      })
      Nil
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
      io.println("Computation completed")
    }
  }
}
