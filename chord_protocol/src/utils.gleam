import gleam/crypto.{Sha1}
import gleam/float
import gleam/int
import gleam/io
import gleam/time/timestamp

pub const ring_size: Int = 16

pub fn mod_ring_size(value: Int) -> Int {
  case int.modulo(value, ring_size) {
    Ok(remainder) -> remainder
    Error(Nil) -> -1
  }
}

pub fn get_hash_id(value: Int) -> Int {
  let digest: BitArray = crypto.hash(Sha1, <<value:int>>)
  let assert <<hash_value:size(ring_size), _:bits>> = digest
  hash_value
}

pub fn get_hash_key(key: String) -> Int {
  let digest: BitArray = crypto.hash(Sha1, <<key:utf8>>)
  let assert <<hash_value:size(ring_size), _:bits>> = digest
  hash_value
}

pub fn log_time(message: String, start_time: Float) -> Nil {
  io.println(
    message
    <> float.to_string(float.to_precision(
      timestamp.to_unix_seconds(timestamp.system_time()) -. start_time,
      2,
    ))
    <> "s",
  )
}

pub fn log2(value: Float) -> Float {
  let assert Ok(log_value) = float.logarithm(value)
  let assert Ok(log2_value) = float.logarithm(2.0)
  log_value /. log2_value
}
