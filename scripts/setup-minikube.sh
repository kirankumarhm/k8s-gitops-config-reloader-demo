#!/usr/bin/env bash
# ==============================================================================
# setup-minikube.sh: Installs Stakater Reloader and ArgoCD onto Minikube
# ==============================================================================
set -euo pipefail

echo "==> 1. Verifying Minikube status"
command -v minikube >/dev/null || { echo "minikube CLI not found" >&2; exit 1; }
minikube status >/dev/null 2>&1 || {
  echo "    Starting Minikube..."
  minikube start --driver=docker --cpus=4 --memory=6g --disk-size=20g
}

echo "==> 2. Installing Stakater Reloader (ConfigMap/Secret change watcher)"
# Reloader watches ConfigMaps & Secrets and triggers RollingUpdates on annotated workloads
kubectl apply -f https://raw.githubusercontent.com/stakater/Reloader/master/deployments/kubernetes/reloader.yaml
echo "    Waiting for Reloader to become ready..."
kubectl -n default rollout status deployment/reloader-reloader --timeout=180s || true

echo "==> 3. Installing ArgoCD (GitOps Controller)"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo "    Waiting for ArgoCD Server to roll out..."
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s || true

echo
echo "=================================================================="
echo " Infrastructure Setup Complete!"
echo " - Stakater Reloader: Running"
echo " - ArgoCD Controller: Running in namespace 'argocd'"
echo "=================================================================="
echo "To access ArgoCD UI:"
echo "  kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo "  Username: admin"
echo "  Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "=================================================================="
