# Chord Protocol

A simulator for a Chord-like Distributed Hash Table (DHT) implemented using the actor model in Gleam. Each node is an actor that communicates through message passing to maintain a consistent ring, stabilize successors and predecessors, update finger tables, and perform peer-to-peer (P2P) lookups.

---

## Input Format

To run the program, use the following format:

```bash
num_nodes num_requests
```

Where:

* `num_nodes`: number of nodes in the Chord ring
* `num_requests`: number of lookup requests each node performs

### Examples

```bash
10 2
512 3
128 5
```

Alternatively, you can call the bootstrap API directly:

```gleam
protocol_handler.bootstrap(num_nodes, num_requests, drop_node)
```

Example:

```gleam
protocol_handler.bootstrap(512, 3, False)
```

---

## What is Working

* **Node Creation and References**
  Nodes are created as actors via `chord_worker.init_node_ref`, returning a `NodeRef`.

* **Lookup and Routing**
  Lookup requests are implemented through `chord_worker.Lookup`, using helper functions:

  * `find_successor`
  * `find_predecessor`
  * `closest_preceding_node`

* **Stabilization**
  Successor and predecessor maintenance are handled via `chord_worker.Stabilize` and `Notify` messages.

* **Finger Table Maintenance**
  The `chord_worker.FixFingers` process periodically updates finger entries to maintain fast lookups.

* **End-to-End Orchestration**

  * Ring setup and bootstrap logic: `protocol_handler.bootstrap`
  * P2P workload orchestration: `protocol_handler.init_p2p`

* **Utilities**

  * Ring parameters and hash helpers: `utils.ring_size`

---

## Node Actor State

Each Chord node maintains a state defined in `chord_worker.ChordWorkerState`, containing:

| Field          | Type                 | Description                              |
| -------------- | -------------------- | ---------------------------------------- |
| `node_id`      | Int                  | Unique identifier for the node           |
| `successor`    | NodeRef              | Pointer to the next node in the ring     |
| `predecessor`  | NodeRef              | Pointer to the previous node in the ring |
| `successors`   | List(NodeRef)        | List of backup successors                |
| `finger_table` | Dict(Int, NodeRef)   | Cached routing table entries             |
| `finger_index` | Int                  | Current finger index for updates         |
| `kv_store`     | Dict(String, String) | Local key-value map                      |

---

## How to Run

1. **Using the CLI**

   Run the program via the main Gleam module:

   ```bash
   gleam run
   ```

   Then input:

   ```text
   num_nodes num_requests
   ```

   Example:

   ```bash
   512 3
   ```

2. **Using the API**

   From another module or the REPL:

   ```gleam
   protocol_handler.bootstrap(512, 3, False)
   ```

---

## Tested Configurations

| Description         | Example                     | Status                     |
| ------------------- | --------------------------- | -------------------------- |
| Standard simulation | `512 3`                     | Stable and verified        |
| Ring size parameter | `utils.ring_size` = 16 bits | SHA-1 truncated to 16 bits |

---

## Largest Network Managed

* Current verified configuration: 512 nodes with 3 lookup requests per node
* Ring size: 16 bits
* Larger networks are possible with:

  * Higher `ring_size`
  * Adequate runtime resources (CPU/memory)
  * Attention to ID collision handling

---

## Notes and Next Steps

* For larger simulations:

  * Increase `utils.ring_size`
  * Monitor CPU and memory usage

* For automated testing:

  * Use `protocol_handler.init_p2p` to vary `num_nodes` (`nn`) and `num_requests` (`nr`)
  * Collect and analyze average hop counts for lookups

---

## Referenced Files and Symbols

| File                         | Key Functions / Types                                                                     |
| ---------------------------- | ----------------------------------------------------------------------------------------- |
| `src/chord_worker.gleam`     | `init_node_ref`, `Lookup`, `FindSuccessor`, `Stabilize`, `FixFingers`, `ChordWorkerState` |
| `src/protocol_handler.gleam` | `bootstrap`, `init_p2p`                                                                   |
| `src/utils.gleam`            | `ring_size`, hashing utilities                                                            |
