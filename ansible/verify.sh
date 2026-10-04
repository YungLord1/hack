#!/usr/bin/env bash
set -euo pipefail

echo "=== Kubernetes nodes ==="
kubectl get nodes

echo
echo "=== Application ==="
kubectl get pods -n demo
kubectl get svc -n demo

echo
echo "=== Gateway API ==="
kubectl get gateway -n demo
kubectl get httproute -n demo

echo
echo "=== Monitoring ==="
kubectl get pods -n monitoring

echo
echo "=== Logging ==="
kubectl get pods -n logging

echo
echo "=== Application HTTP check ==="

curl -f http://177.1.180.84:32630/

echo
echo "=== Verification completed ==="
