import gleam/bit_array
import gleam/result

pub fn decode_pem_to_der(pem_key: String) -> Result(BitArray, String) {
  do_decode_pem_to_der(bit_array.from_string(pem_key))
}

pub fn generate_key_pair() -> #(PublicKey, PrivateKey) {
  let #(public_pem, private_pem, public_der, private_der) =
    do_generate_rsa_keys()
  let public_key = PublicKey(public_der, public_pem)
  let private_key = PrivateKey(private_der, private_pem)
  #(public_key, private_key)
}

pub fn sign_message(msg: BitArray, key: PrivateKey) -> Result(BitArray, String) {
  do_sign_message(msg, key.der)
}

pub fn sign_message_with_pem_string(
  msg: BitArray,
  key_pem: String,
) -> Result(BitArray, String) {
  use key_der <- result.try(decode_pem_to_der(key_pem))
  do_sign_message(msg, key_der)
}

pub fn verify_message(
  msg: BitArray,
  key: PublicKey,
  sig: BitArray,
) -> Result(Bool, String) {
  case do_verify_message(msg, key.der, sig) {
    Ok(ValidSignature) -> Ok(True)
    Ok(InvalidSignature) -> Ok(False)
    Error(reason) -> Error(reason)
  }
}

pub fn verify_message_with_pem_string(
  msg: BitArray,
  key_pem: String,
  sig: BitArray,
) -> Result(Bool, String) {
  case decode_pem_to_der(key_pem) {
    Ok(key_der) -> {
      case do_verify_message(msg, key_der, sig) {
        Ok(ValidSignature) -> Ok(True)
        Ok(InvalidSignature) -> Ok(False)
        Error(reason) -> Error(reason)
      }
    }
    Error(reason) -> Error(reason)
  }
}

pub fn encrypt_message(msg: BitArray, key: PublicKey) -> BitArray {
  let assert Ok(result) = do_encrypt_message(msg, key.der)
  result
}

pub fn decrypt_message(msg: BitArray, key: PrivateKey) {
  case do_decrypt_message(msg, key.der) {
    Error(e) -> Error(e)
    Ok(result) -> Ok(result)
  }
}

@external(erlang, "rsa_keys_ffi", "decode_pem_to_der")
fn do_decode_pem_to_der(pem_key: BitArray) -> Result(BitArray, String)

@external(erlang, "rsa_keys_ffi", "generate_rsa_key_pair")
fn do_generate_rsa_keys() -> #(String, String, BitArray, BitArray)

@external(erlang, "rsa_keys_ffi", "sign_message")
fn do_sign_message(
  msg: BitArray,
  private_key: BitArray,
) -> Result(BitArray, String)

@external(erlang, "rsa_keys_ffi", "verify_message")
fn do_verify_message(
  msg: BitArray,
  public_key: BitArray,
  sig: BitArray,
) -> Result(SignatureType, String)

@external(erlang, "rsa_keys_ffi", "encrypt_message")
fn do_encrypt_message(
  msg: BitArray,
  public_key: BitArray,
) -> Result(BitArray, String)

@external(erlang, "rsa_keys_ffi", "decrypt_message")
fn do_decrypt_message(
  msg: BitArray,
  private_key: BitArray,
) -> Result(BitArray, ErrorDecrypt)

pub type PrivateKey {
  PrivateKey(der: BitArray, pem: String)
}

pub type PublicKey {
  PublicKey(der: BitArray, pem: String)
}

type SignatureType {
  ValidSignature
  InvalidSignature
}

pub type ErrorDecrypt {
  Integrity
  Format
  Other
}
