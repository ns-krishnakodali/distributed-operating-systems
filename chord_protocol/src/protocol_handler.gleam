import gleam/time/timestamp

pub fn bootstrap(nn: Int, nr: Int, drop_node: Bool) -> Nil {
  let _start_time: Float = timestamp.to_unix_seconds(timestamp.system_time())
  Nil
}
