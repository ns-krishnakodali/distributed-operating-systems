#!/bin/bash

GOSSIP_FULL_NODES=(10 50 100 300 500 1000 1500 2000 3000)
GOSSIP_LINE_NODES=(10 50 100 150 200 300 400 500 1000)
GOSSIP_GRID_NODES=(8 27 64 125 216 343 512 729 1000 8000 27000 64000 125000)

TOPOLOGIES=("full" "line" "3D" "imp3D")

for TOPO in "${TOPOLOGIES[@]}"; do
  echo "=============================================="
  echo " Algorithm: Gossip | Topology: $TOPO "
  echo "=============================================="
  
  if [ "$TOPO" == "full" ]; then
    NODES_LIST=("${GOSSIP_FULL_NODES[@]}")
  elif [ "$TOPO" == "line" ]; then
    NODES_LIST=("${GOSSIP_LINE_NODES[@]}")
  else
    NODES_LIST=("${GOSSIP_GRID_NODES[@]}")
  fi

  for NODES in "${NODES_LIST[@]}"; do
    echo "------ Nodes: $NODES ------"
    echo "$NODES $TOPO gossip" | gleam run | grep -iE "convergence time|execution time"
    echo ""
  done
done
