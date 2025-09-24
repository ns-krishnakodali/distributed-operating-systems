#!/bin/bash

DROP_NODE=$1

PUSH_FULL_NODES=(10 50 100 300 500 1000 2000 3000)
PUSH_LINE_NODES=(10 25 50 75 100 200)
PUSH_GRID_NODES=(125 512 1000 3375 8000)
PUSH_IMP_GRID_NODES=(125 512 1000 3375 8000 15625 27000)

TOPOLOGIES=("full" "line" "3D" "imp3D")

for TOPO in "${TOPOLOGIES[@]}"; do
  if [ -n "$DROP_NODE" ] && { [ "$TOPO" == "line" ] || [ "$TOPO" == "imp3D" ]; }; then
    echo "Skipping $TOPO topology due to drop_node parameter."
    continue
  fi

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
    if [ -n "$DROP_NODE" ]; then
      echo "$NODES $TOPO push-sum" | gleam run drop_node | grep -iE "convergence time|execution time|total sum"
    else
      echo "$NODES $TOPO push-sum" | gleam run | grep -iE "convergence time|execution time|total sum"
    fi
    echo ""
  done
done
