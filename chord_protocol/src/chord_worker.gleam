import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}

pub fn start_and_get_subj() {
  todo
}

pub type ChordWorkerState =
  #(
    String,
    Dict(Int, Int),
    Dict(Int, Int),
    ChordWorkerSubject,
    ChordWorkerSubject,
    List(ChordWorkerSubject),
  )

pub type ChordWorkerSubject =
  Subject(ChordWorkerMessage)

pub type ChordWorkerMessage {
  Lookup
  FindSuccessor
  Stablize
  Notify
  FixFingers
  Shutdown
}
// - id - node’s identifier
// - successor - pointer to next node clockwise.
// - predecessor - pointer to previous node clockwise.
// - finger[1…m] - touring table where finger[i] = find_successor((id + 2^{i-1}) mod 2^m), for speed routing.
// - successor_list - for next r successors, usually maintained in case of fault tolerance.
// - keys: set of keys for which the node is the successor.

// Use SHA-1 as base hashing, as the hash is not used for security bit rather for load imbalance, hashing can be used for better distribution across identifier space.
