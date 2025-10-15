import gleam/crypto.{Sha1}
import gleam/int

pub const ring_size: Int = 16

pub fn mod(value: Int, modulus: Int) -> Int {
  case int.modulo(value, modulus) {
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
