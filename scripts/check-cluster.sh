#!/bin/bash
# kind cluster setup verification
set -e

CLUSTER_NAME="${CLUSTER_NAME:-rook-lab}"

echo "=== Rook Lab — kind Cluster Check ==="
echo ""

echo "Cluster:"
kubectl cluster-info --context "kind-${CLUSTER_NAME}"
echo ""

echo "Nodes:"
kubectl get nodes
echo ""

echo "System Pods:"
kubectl get pods -A
echo ""

echo "StorageClass:"
kubectl get storageclass
echo ""

echo "=== Alles Ready ==="
