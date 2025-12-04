import gleam/bit_array
import gleam/crypto
import gleam/float
import gleam/int
import gleam/string
import gleam/time/timestamp

pub const user_prefix: String = "R_User"

pub const subreddit_prefix: String = "R_SubReddit"

pub const post_prefix: String = "R_Post"

pub const comment_prefix: String = "U_Comment"

pub const message_prefix: String = "U_Message"

pub const reply_prefix: String = "U_Reply"

pub const post_description: String = "Post_Description"

pub const post_comment: String = "Comment_Data"

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

// Get a randomly generated boolean value
pub fn random_boolean() -> Bool {
  int.random(2) + 1 == 1
}
