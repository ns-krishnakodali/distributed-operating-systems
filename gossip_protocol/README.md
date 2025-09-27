# Gossip Protocol

A simulator for Gossip and Push-Sum protocols using the actor model in Gleam, supporting multiple network topologies.

## Input Format

To run the program, use the following format:

```

num_nodes topology algorithm drop_node

```

Where:

- `num_nodes`: number of actors in the network
- `topology`: one of `full`, `3D`, `line`, or `imp3D`
- `algorithm`: one of `gossip` or `push-sum`
- `drop_node` _(optional)_: enables dropping/failing a node during simulation

### Examples

```

100 full gossip
5000 line push-sum
8000 imp3D gossip
1000 3D push-sum drop_node

```

The program will build the specified topology, bootstrap the chosen algorithm, and measure the convergence time.

## Topologies

- **Full:** Each actor can talk to every other actor
- **3D Grid:** Actors arranged in a 3D cube, each connected to its grid neighbors
  - **Important:** `num_nodes` must be a _perfect cube_ (e.g., 27, 64, 125), else the protocol will not execute (a check is in place)
- **Line:** Actors arranged in a straight line, each with up to 2 neighbors
- **Imperfect 3D:** Same as 3D grid, plus one extra random neighbor

## Algorithms

### Gossip

- One node starts with a rumor
- Each step: a node selects a random neighbor and shares the rumor
- A node stops transmitting after hearing the rumor **10 times**

### Push-Sum

- Each node starts with `(s, w)`, where `s = node_idx` and `w = 1`
- At every step, the node keeps half of `(s, w)` and sends half to a random neighbor
- The ratio `s / w` estimates the average
- Convergence is reached when the ratio changes by less than **1e-10** over three consecutive rounds

## Largest Network Sizes Tested

| Topology     | Gossip (nodes) | Push-Sum (nodes) |
| ------------ | -------------- | ---------------- |
| Full         | 10000          | 10000            |
| Line         | 5000           | 400              |
| 3D Grid      | 216000         | 15625            |
| Imperfect 3D | 216000         | 91125            |

## What is Working

- Both the protocols, **Gossip** and **Push-Sum** are implemented using the actor model in Gleam.
- Supported network topologies: **full**, **line**, **3D** grid, and **imperfect 3D** grid.
- **Gossip protocol**: Rumor spreads correctly, and convergence is detected once all nodes have received it the required number of times.
- **Push-Sum protocol**: Each actor maintains `(s, w)` values, exchanges them with neighbors, and converges once the ratio `s/w` stabilizes within a threshold.
- Convergence time is measured in seconds and reported accurately at the end of each simulation.
- The program scales to large numbers of nodes while maintaining correctness for certain topologies.

## Observations

- **Topology construction time**:

  - For large networks, **3D** and **Imperfect 3D** are faster to construct because each node only has 6 neighbors (plus 1 random neighbor in Imp3D).
  - Also, for larger networks, building a **Full** topology is very slow because each node must connect to all other nodes.

- **Gossip protocol**:

  - **3D grid** performs best.
    - Reason: Rumor spreads like a balanced wave through fixed 6 neighbors, so convergence is faster.
  - **Imperfect 3D** also works, but extra random neighbor can waste some messages.
  - **Full topology** works well for small to medium networks but is limited by message redundancy.
  - **Line topology** scales to thousands of nodes, but convergence is slow.

- **Push-Sum protocol**:

  - **Imperfect 3D** performs best.
    - Reason: The random neighbor helps balance `(s, w)` values quickly across the network, reducing convergence time.
  - **3D grid** works moderately well for small to medium networks, but convergence is much slower than Imp3D for large networks.
  - **Full topology** works for small to medium networks but scaling is limited due to message overhead.
  - **Line topology** is extremely slow, practical only for very small networks.
