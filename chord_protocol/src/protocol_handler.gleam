import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/time/timestamp

import chord_worker.{type NodeRef}

pub fn bootstrap(nn: Int, _nr: Int, _drop_node: Bool) -> Nil {
  let start_time: Float = timestamp.to_unix_seconds(timestamp.system_time())

  let nodes_list: List(NodeRef) =
    list.map(list.range(from: 1, to: nn), fn(id: Int) {
      chord_worker.init_node_ref(id)
    })
  io.println(
    "Time to initialize nodes: "
    <> float.to_string(float.to_precision(
      timestamp.to_unix_seconds(timestamp.system_time()) -. start_time,
      2,
    ))
    <> "s",
  )

  init_ring(nodes_list)
}

fn init_ring(nodes_list: List(NodeRef)) -> Nil {
  // Set a primary contact node
  let assert Ok(pcnode_ref) = list.first(nodes_list)
  let #(_, pcnode_subj) = pcnode_ref
  let _ =
    process.call(pcnode_subj, 50, chord_worker.SetSuccessor(_, pcnode_ref))
  let current_nodes_list: List(NodeRef) = list.new()
  list.each(nodes_list, fn(node_ref: NodeRef) -> Nil {
    let #(node_id, node_subj) = node_ref
    let snode_ref: NodeRef =
      process.call(pcnode_subj, 100, chord_worker.FindSuccessor(
        _,
        pcnode_subj,
        node_id,
      ))
    let _ =
      process.call(node_subj, 100, chord_worker.SetSuccessor(_, snode_ref))
    process.spawn(fn() {
      stabilize_ring(list.append(current_nodes_list, [node_ref]))
    })
    Nil
  })

  list.each(nodes_list, fn(node_ref: NodeRef) {
    echo process.call(node_ref.1, 50, chord_worker.GetNodeState)
  })
}

fn stabilize_ring(nodes_list: List(NodeRef)) -> Nil {
  list.each(nodes_list, fn(node_ref: NodeRef) -> Nil {
    let #(node_id, node_subj) = node_ref
    case process.call(node_subj, 50, chord_worker.Stabilize(_, node_subj)) {
      True -> Nil
      False ->
        io.println("Node " <> int.to_string(node_id) <> " not stabilized")
    }
  })
}
