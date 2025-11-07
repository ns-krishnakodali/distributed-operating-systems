import server_worker.{type ServerWorkerSubject}

pub fn bootstrap_simulation(num_users: Int) -> Nil {
  echo num_users
  let _server_subj: ServerWorkerSubject = server_worker.start_and_get_subj()

  Nil
}
