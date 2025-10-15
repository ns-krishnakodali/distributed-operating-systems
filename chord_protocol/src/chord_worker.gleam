import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/list
import gleam/otp/actor

import utils

pub fn init_node_ref(id: Int) -> NodeRef {
  let node_id: Int = utils.get_hash_id(id)
  let successors_list: List(NodeRef) = []

  let assert Ok(actor) =
    actor.new(#(
      node_id,
      #(-1, process.new_subject()),
      #(-1, process.new_subject()),
      successors_list,
      dict.from_list([]),
      dict.from_list([]),
    ))
    |> actor.on_message(handle_message)
    |> actor.start

  #(node_id, actor.data)
}

fn handle_message(
  state: ChordWorkerState,
  w_message: ChordWorkerMessage,
) -> actor.Next(ChordWorkerState, ChordWorkerMessage) {
  case w_message {
    FindSuccessor(reply_subj, node_subj, id) -> {
      let #(node_id, snode_ref, _, _, finger_table, _): ChordWorkerState = state
      let #(pnode_id, pnode_subj): NodeRef =
        find_predecessor(id, #(node_id, node_subj), snode_ref, finger_table)
      let new_snode_ref: NodeRef = case pnode_id == node_id {
        True -> snode_ref
        False -> process.call(pnode_subj, 100, GetSuccessorRef)
      }

      process.send(reply_subj, new_snode_ref)
      actor.continue(state)
    }
    GetSuccessorRef(reply_subj) -> {
      process.send(reply_subj, state.1)
      actor.continue(state)
    }
    GetPredecessorRef(reply_subj) -> {
      process.send(reply_subj, state.2)
      actor.continue(state)
    }
    SetSuccessor(reply_subj, new_snode_ref) -> {
      let #(node_id, _, pnr, sl, ft, kvm): ChordWorkerState = state
      process.send(reply_subj, True)
      actor.continue(#(node_id, new_snode_ref, pnr, sl, ft, kvm))
    }
    Notify(reply_subj, new_pnode_ref) -> {
      let #(node_id, snr, pnode_ref, sl, ft, kvm): ChordWorkerState = state
      let #(pnode_id, _) = pnode_ref
      let #(new_pnode_id, _) = new_pnode_ref

      let updated_pnode_ref: NodeRef = case
        { pnode_id == node_id }
        || { new_pnode_id > pnode_id && new_pnode_id < node_id }
      {
        True -> {
          process.send(reply_subj, True)
          new_pnode_ref
        }
        False -> {
          process.send(reply_subj, False)
          pnode_ref
        }
      }
      actor.continue(#(node_id, snr, updated_pnode_ref, sl, ft, kvm))
    }
    Stabilize(reply_subj, node_subj) -> {
      let #(node_id, snode_ref, pnode_ref, sl, ft, kvm) = state
      let #(snode_id, snode_subj) = snode_ref

      let xpnode_ref: NodeRef = case snode_id == node_id {
        True -> pnode_ref
        False -> process.call(snode_subj, 50, GetPredecessorRef)
      }
      let #(xpnode_id, _): NodeRef = xpnode_ref
      let new_snode_ref: NodeRef = case
        xpnode_id > node_id && xpnode_id < snode_id
      {
        True -> xpnode_ref
        False -> snode_ref
      }

      case new_snode_ref.0 == node_id {
        True -> {
          process.send(reply_subj, True)
          actor.continue(#(node_id, snode_ref, pnode_ref, sl, ft, kvm))
        }
        False -> {
          let status: Bool =
            process.call(new_snode_ref.1, 50, Notify(_, #(node_id, node_subj)))
          process.send(reply_subj, status)
          actor.continue(#(node_id, new_snode_ref, pnode_ref, sl, ft, kvm))
        }
      }
    }

    FixFingers(idx, node_subj) -> {
      let #(node_id, snr, pnr, sl, finger_table, kvm) = state
      let assert Ok(power_value) = int.power(2, int.to_float(idx - 1))
      let node_ref: NodeRef =
        process.call(node_subj, 100, FindSuccessor(
          _,
          node_subj,
          utils.get_hash_id(node_id + float.round(power_value)),
        ))
      let updated_finger_table: Dict(Int, NodeRef) =
        dict.insert(finger_table, idx, node_ref)
      actor.continue(#(node_id, snr, pnr, sl, updated_finger_table, kvm))
    }
    GetNodeState(reply_subj) -> {
      let #(node_id, snode_ref, pnode_ref, _, _, _) = state
      process.send(reply_subj, #(node_id, snode_ref, pnode_ref))
      actor.continue(state)
    }
    Shutdown -> {
      actor.stop()
    }
  }
}

fn find_predecessor(
  id: Int,
  node_ref: NodeRef,
  snode_ref: NodeRef,
  finger_table: Dict(Int, NodeRef),
) -> NodeRef {
  let #(node_id, _): NodeRef = node_ref
  let #(snode_id, _): NodeRef = snode_ref

  case id <= node_id || id > snode_id {
    True -> {
      let new_node_ref: NodeRef =
        closest_preceding_node(id, node_ref, finger_table)
      let #(new_node_id, new_node_subj): NodeRef = new_node_ref
      case new_node_id == node_id {
        True -> node_ref
        False -> {
          let new_snode_ref: NodeRef =
            process.call(new_node_subj, 100, GetSuccessorRef)
          find_predecessor(id, new_node_ref, new_snode_ref, finger_table)
        }
      }
    }
    False -> node_ref
  }
}

fn closest_preceding_node(
  id: Int,
  node_ref: NodeRef,
  finger_table: Dict(Int, NodeRef),
) -> NodeRef {
  let #(node_id, _): NodeRef = node_ref
  let fnode_result: Result(NodeRef, Nil) =
    list.find(dict.values(finger_table), fn(fnode_ref: NodeRef) {
      let #(fnode_id, _): NodeRef = fnode_ref
      fnode_id > node_id && fnode_id < id
    })
  case fnode_result {
    Ok(value) -> value
    Error(_) -> node_ref
  }
}

pub type NodeRef =
  #(Int, ChordWorkerSubject)

pub type ChordWorkerState =
  #(
    Int,
    NodeRef,
    NodeRef,
    List(NodeRef),
    Dict(Int, NodeRef),
    Dict(String, String),
  )

pub type ChordWorkerSubject =
  Subject(ChordWorkerMessage)

pub type ChordWorkerMessage {
  FindSuccessor(Subject(NodeRef), ChordWorkerSubject, Int)
  GetSuccessorRef(Subject(NodeRef))
  SetSuccessor(Subject(Bool), NodeRef)
  GetPredecessorRef(Subject(NodeRef))
  Notify(Subject(Bool), NodeRef)
  Stabilize(Subject(Bool), ChordWorkerSubject)
  FixFingers(Int, ChordWorkerSubject)
  GetNodeState(Subject(#(Int, NodeRef, NodeRef)))
  Shutdown
}
