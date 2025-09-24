#!/bin/bash

PUSH_FULL_NODES=(10 50 100 300 500 1000 2000 3000)
PUSH_LINE_NODES=(10 25 50 75 100 200)
PUSH_GRID_NODES=(125 512 1000 3375 8000)
PUSH_IMP_GRID_NODES=(125 512 1000 3375 8000 15625 27000)

TOPOLOGIES=("full" "line" "3D" "imp3D")

for TOPO in "${TOPOLOGIES[@]}"; do
  echo "=============================================="
  echo " Algorithm: Push-Sum | Topology: $TOPO "
  echo "=============================================="
  
  if [ "$TOPO" == "full" ]; then
    NODES_LIST=("${PUSH_FULL_NODES[@]}")
  elif [ "$TOPO" == "line" ]; then
    NODES_LIST=("${PUSH_LINE_NODES[@]}")
  elif [ "$TOPO" == "3D" ]; then
    NODES_LIST=("${PUSH_GRID_NODES[@]}")
  else
    NODES_LIST=("${PUSH_IMP_GRID_NODES[@]}")
  fi

  for NODES in "${NODES_LIST[@]}"; do
    echo "------ Nodes: $NODES ------"
    echo "$NODES $TOPO push-sum" | gleam run | grep -iE "convergence time|execution time|total sum"
    echo ""
  done
done
