import gleam/erlang/process

import server_worker.{type ServerWorkerSubject}

pub fn bootstrap_simulation(num_users: Int) -> Nil {
  echo num_users
  let server_subj: ServerWorkerSubject = server_worker.start_and_get_subj()

  echo process.call(server_subj, 100, server_worker.SignUpUser(
    _,
    "krishna",
    "krishna@91299",
  ))
  echo process.call(server_subj, 100, server_worker.CreateSubReddit(
    _,
    "kk subreddit",
    "krishna",
  ))
  echo process.call(server_subj, 100, server_worker.JoinSubReddit(
    _,
    "kk subreddit",
    "krishna",
  ))
  Nil
}
