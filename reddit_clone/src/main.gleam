import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/string
import mist
import wisp
import wisp/wisp_mist

import log
import server/server_worker.{type ServerWorkerSubject}
import server/statistics_worker.{type StatisticsWorkerSubject}

import reddit_simulation
import server/router

pub fn main() -> Nil {
  let line: String =
    get_line(
      "Enter number of users (min 50) and duration (in secs) for simulation: \n",
    )
  case parse_input_line(line) {
    Ok(#(num_users, num_seconds)) -> {
      log.heading("Starting reddit server")

      let server_subj: ServerWorkerSubject = server_worker.start_and_get_subj()
      let statistics_subj: StatisticsWorkerSubject =
        statistics_worker.start_and_get_subj()

      process.spawn(fn() { start_server(server_subj, statistics_subj) })
      process.sleep(1000)

      log.heading("Server started successfully, beginning reddit simulation.")
      reddit_simulation.bootstrap(num_users)

      process.sleep(num_seconds * 1000)
      process.send(server_subj, server_worker.Shutdown)

      log.heading("Displaying statistics")
      log.info(process.call(
        statistics_subj,
        1000,
        statistics_worker.GetStatistics,
      ))
      process.send(statistics_subj, statistics_worker.Shutdown)
    }
    Error(msg) -> {
      io.println("Error: " <> msg)
    }
  }
}

@external(erlang, "io", "get_line")
fn get_line(prompt: String) -> String

fn parse_input_line(line: String) -> Result(#(Int, Int), String) {
  let input: List(String) = string.split(line, on: " ")
  case input {
    [num_users, num_seconds] -> {
      case int.parse(num_users) {
        Ok(num_users) -> {
          case num_users >= 50 {
            True -> {
              case
                int.parse(string.replace(num_seconds, each: "\n", with: ""))
              {
                Ok(num_seconds) -> Ok(#(num_users, num_seconds))
                Error(_) -> Error("Number of seconds must be a valid integer")
              }
            }
            False -> Error("Number of users must be at least 50")
          }
        }
        Error(_) -> Error("Number of users must be a valid integer")
      }
    }
    _ -> Error("Invalid input: Provide a single integer value for 'num_users'")
  }
}

fn start_server(
  server_subj: ServerWorkerSubject,
  statistics_subj: StatisticsWorkerSubject,
) -> Nil {
  wisp.configure_logger()
  let secret_key_base: String = wisp.random_string(64)

  let assert Ok(_) =
    wisp_mist.handler(
      fn(request) {
        router.handle_request(request, server_subj, statistics_subj)
      },
      secret_key_base,
    )
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  io.println("Server started on port 8000")
  process.sleep_forever()
}
