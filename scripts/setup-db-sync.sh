#!/usr/bin/env bash
# ==============================================================================
# setup-db-sync.sh: Builds and deploys PostgreSQL & DB-to-ConfigMap Syncer
# ==============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
NS=gitops-demo

echo "==> 1. Building DB Syncer Docker image"
docker build -t gitops-demo-db-syncer:latest "$ROOT/services/db-syncer" >/dev/null

echo "==> 2. Loading DB Syncer image into Minikube"
minikube image load gitops-demo-db-syncer:latest >/dev/null 2>&1 || true

echo "==> 3. Deploying PostgreSQL Database into cluster"
kubectl apply -f "$ROOT/k8s/db/postgres.yaml"
kubectl -n $NS rollout status deployment/postgres --timeout=120s

echo "==> 4. Deploying DB-to-ConfigMap Syncer Controller"
kubectl apply -f "$ROOT/k8s/db/db-syncer.yaml"
kubectl -n $NS rollout status deployment/db-syncer --timeout=120s

echo
echo "=================================================================="
echo " PostgreSQL and DB-to-ConfigMap Syncer are RUNNING!"
echo " Initial database properties will now sync to ConfigMaps."
echo "=================================================================="
