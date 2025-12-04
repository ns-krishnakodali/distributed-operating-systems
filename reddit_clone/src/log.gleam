import gleam/io

pub fn heading(heading: String) -> Nil {
  io.println("\n\n========== " <> heading <> " ==========\n\n")
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
