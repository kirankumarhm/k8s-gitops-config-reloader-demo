#!/usr/bin/env bash
# ==============================================================================
# teardown.sh: Cleans up gitops-demo workloads and optionally ArgoCD / Reloader
# ==============================================================================
set -euo pipefail

echo "==> Deleting gitops-demo namespace and workloads"
kubectl delete namespace gitops-demo --ignore-not-found=true

if [ "${1:-}" = "--all" ]; then
  echo "==> Deleting Stakater Reloader..."
  kubectl delete -f https://raw.githubusercontent.com/stakater/Reloader/master/deployments/kubernetes/reloader.yaml --ignore-not-found=true

  echo "==> Deleting ArgoCD..."
  kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --ignore-not-found=true
  kubectl delete namespace argocd --ignore-not-found=true
fi

echo "Teardown complete!"
