#!/usr/bin/env bash
# ==============================================================================
# teardown.sh: Cleans up gitops-demo workloads and optionally ArgoCD / Reloader
# ==============================================================================
set -euo pipefail

echo "==> 1. Deleting ArgoCD Applications & Projects"
kubectl -n argocd delete application gitops-polyglot-config-demo --cascade=orphan --ignore-not-found=true 2>/dev/null || true
kubectl -n argocd delete appproject gitops-config-demo --ignore-not-found=true 2>/dev/null || true

echo "==> 2. Deleting gitops-demo namespace and all workloads"
kubectl delete namespace gitops-demo --ignore-not-found=true

if [ "${1:-}" = "--all" ]; then
  echo "==> 3. Deleting Stakater Reloader..."
  kubectl delete -f https://raw.githubusercontent.com/stakater/Reloader/master/deployments/kubernetes/reloader.yaml --ignore-not-found=true

  echo "==> 4. Deleting ArgoCD..."
  kubectl delete namespace argocd --ignore-not-found=true

  echo "==> 5. Cleaning local Docker demo images to free space..."
  docker rmi gitops-demo-springboot-service:latest \
             gitops-demo-go-service:latest \
             gitops-demo-node-service:latest \
             gitops-demo-python-service:latest \
             gitops-demo-db-syncer:latest 2>/dev/null || true
  docker builder prune -f >/dev/null 2>&1 || true
fi

echo "Teardown complete!"
