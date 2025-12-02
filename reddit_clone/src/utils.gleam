import gleam/bit_array
import gleam/crypto
import gleam/float
import gleam/int
import gleam/string
import gleam/time/timestamp

pub const user_prefix: String = "R/User"

pub const subreddit_prefix: String = "R/SubReddit"

pub const post_prefix: String = "R/Post"

pub const comment_prefix: String = "R/Comment"

pub const message_prefix: String = "R/Message"

// Generate a prefixed string of the given length
pub fn generate_hex_string(length: Int, prefix: String) -> String {
  let hex_string = bit_array.base16_encode(crypto.strong_random_bytes(length))
  prefix <> string.slice(hex_string, 0, length)
}

// Get time difference from start time
pub fn get_time_difference(start_time: Float) {
  timestamp.to_unix_seconds(timestamp.system_time()) -. start_time
}

// Get zipf weight for the corresponding rank
pub fn zipf_weight(rank: Int) {
  let assert Ok(rank) = float.power(int.to_float(rank), 1.2)
  1.0 /. rank
}

pub fn get_random_username(num_users) -> String {
  user_prefix <> int.to_string(int.random(num_users) + 1)
}
