import gleam/bit_array
import gleam/crypto
import gleam/string

pub const comment_prefix: String = "R Comment"

pub const message_prefix: String = "R Message"

pub const post_prefix: String = "R Post"

pub const subreddit_prefix: String = "R SubReddit"

pub const user_prefix: String = "R User"

pub fn generate_random_string(length: Int, prefix: String) -> String {
  let hex_string = bit_array.base16_encode(crypto.strong_random_bytes(length))
  prefix <> string.slice(hex_string, 0, length)
}
