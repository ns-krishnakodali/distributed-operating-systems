import gleam/bit_array
import gleam/crypto
import gleam/int
import gleam/string

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

pub fn get_random_username(num_users) -> String {
  user_prefix <> int.to_string(int.random(num_users) + 1)
}
