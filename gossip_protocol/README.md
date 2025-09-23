# Gossip Protocol

A simulator for Gossip and Push-Sum protocols using the actor model in Gleam, supporting multiple network topologies.

## Input Format

To run the program, use the following format:

```

num_nodes topology algorithm

```

Where:

- `num_nodes` → number of actors in the network
- `topology` → one of `full`, `3D`, `line`, or `imp3D`
- `algorithm` → one of `gossip` or `push-sum`

### Examples

```

100 full gossip
5000 line push-sum
8000 imp3D gossip

```

The program will build the specified topology, bootstrap the chosen algorithm, and measure the convergence time.

---

## Topologies

- **Full:** Each actor can talk to every other actor
- **3D Grid:** Actors arranged in a 3D cube, each connected to its grid neighbors
  - **Important:** `num_nodes` must be a _perfect cube_ (e.g., 27, 64, 125), else the protocol will not execute (a check is in place)
- **Line:** Actors arranged in a straight line, each with up to 2 neighbors
- **Imperfect 3D:** Same as 3D grid, plus one extra random neighbor

---

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

---

## Largest Network Sizes Tested

| Topology     | Gossip (nodes) | Push-Sum (nodes) |
| ------------ | -------------- | ---------------- |
| Full         | 2000           | 2000             |
| Line         | 1000000        | 150              |
| 3D Grid      | 512000         | 216              |
| Imperfect 3D | 512000         | 91125            |

---

## What is Working

- Both the protocols, **Gossip** and **Push-Sum** are implemented using the actor model in Gleam
- Supported network topologies: **full**, **line**, **3D** grid, and **imperfect 3D** grid
- Gossip protocol: Rumor spreads correctly, and convergence is detected once all nodes have received it the required number of times
- Push-Sum protocol: Each actor maintains `(s, w)` values, exchanges them with neighbors, and converges once the ratio `s/w` stabilizes within a threshold
- Convergence time is measured in seconds and reported accurately at the end of each simulation
- The program scales to large numbers of nodes (tested successfully up to the sizes shown below) while maintaining correctness
- Observed performance trends:
  - For **Gossip**:
    - **Line topology** scales extremely well, handling up to 1,000,000 nodes, though convergence is slower than 3D-based topologies in medium networks
    - **Imperfect 3D** and **3D grid** provide fast convergence for large networks due to multiple neighbors and shortcuts
    - **Full topology** is efficient for small to medium networks, but message redundancy can limit scaling
  - For **Push-Sum**:
    - **Imperfect 3D** topology performs best for large networks, converging with up to 91,125 nodes
    - **3D grid** works moderately well for small to medium networks (up to 216 nodes tested)
    - **Line topology** is extremely slow, practical only for very small networks (150 nodes tested)
    - **Full topology** works for small to medium networks (up to 2,000 nodes tested), but scaling is limited by message overhead
