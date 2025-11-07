import gleam/io

pub fn log_heading(heading: String) -> Nil {
  io.println("========== " <> heading <> " ==========")
}

pub fn info(message: String) -> Nil {
  io.println("[INFO] " <> message)
}

pub fn warning(message: String) -> Nil {
  io.println("[WARNING] " <> message)
}

pub fn error(message: String) -> Nil {
  io.println("[ERROR] " <> message)
}
