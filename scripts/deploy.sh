#!/usr/bin/env bash
# ==============================================================================
# deploy.sh: Builds polyglot services, loads to Minikube, and deploys manifests
# ==============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
NS=gitops-demo

echo "==> 1. Building Spring Boot jar"
(cd "$ROOT/services/springboot-service" && mvn -B -q clean package -DskipTests)

echo "==> 2. Building Docker images on host daemon"
echo "    -> Building springboot-service image..."
docker build -t gitops-demo-springboot-service:latest "$ROOT/services/springboot-service" >/dev/null

echo "    -> Building go-service image..."
docker build -t gitops-demo-go-service:latest "$ROOT/services/go-service" >/dev/null

echo "    -> Building node-service image..."
docker build -t gitops-demo-node-service:latest "$ROOT/services/node-service" >/dev/null

echo "    -> Building python-service image..."
docker build -t gitops-demo-python-service:latest "$ROOT/services/python-service" >/dev/null

echo "==> 3. Loading images into Minikube"
for img in gitops-demo-springboot-service:latest \
           gitops-demo-go-service:latest \
           gitops-demo-node-service:latest \
           gitops-demo-python-service:latest; do
  printf '    Loading %-40s ... ' "$img"
  minikube image load "$img" >/dev/null 2>&1 && echo "ok" || echo "FAILED"
done

echo "==> 4. Deploying Kustomize manifests to Minikube"
kubectl apply -k "$ROOT/k8s/overlays/minikube"

echo "==> 5. Waiting for polyglot workloads to roll out"
kubectl -n $NS rollout status deployment/springboot-service --timeout=180s
kubectl -n $NS rollout status deployment/go-service --timeout=180s
kubectl -n $NS rollout status deployment/node-service --timeout=180s
kubectl -n $NS rollout status deployment/python-service --timeout=180s

echo
echo "=================================================================="
echo " All polyglot workloads are running!"
echo "=================================================================="
kubectl -n $NS get pods -o wide
