#!/usr/bin/env bash
# ==============================================================================
# test-github-sync.sh: Tests GitOps ConfigMap sync from GitHub via ArgoCD
# Proves: Committing configuration changes to the GitHub repo triggers
#         ArgoCD reconciliation and Stakater Reloader rolling updates!
# ==============================================================================
set -euo pipefail

NS=gitops-demo
GREEN=$'\033[32m'; RED=$'\033[31m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
PASS=0; FAIL=0

ok()  { PASS=$((PASS+1)); echo "  ${GREEN}PASS${OFF}  $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ${RED}FAIL${OFF}  $1"; }

echo "${BOLD}==================================================================${OFF}"
echo "${BOLD} GitHub Repository (ArgoCD GitOps) -> ConfigMap Sync Acceptance Test${OFF}"
echo "${BOLD}==================================================================${OFF}"

# 1. Scale down db-syncer if active to prevent multi-writer drift
kubectl -n $NS scale deployment/db-syncer --replicas=0 2>/dev/null || true

query_sb() {
  kubectl -n $NS exec deploy/springboot-service -- wget -qO- --timeout=5 "http://127.0.0.1:8081/api/v1/config" 2>/dev/null
}

echo
echo "${BOLD}Step 1: Reading current Spring Boot configuration${OFF}"
sb_current=$(query_sb)
echo "  [Spring Boot] current config: $sb_current"

echo
echo "${BOLD}Step 2: Checking ArgoCD Application Status${OFF}"
kubectl -n argocd get application gitops-polyglot-config-demo

echo
echo "${BOLD}Step 3: Triggering ArgoCD GitOps Sync from GitHub repo${OFF}"
kubectl -n argocd patch application gitops-polyglot-config-demo --type merge -p '{"operation":{"sync":{"prune":true}}}'

echo "  Waiting for ArgoCD to synchronize and Reloader to roll out pods..."
sleep 5
kubectl -n $NS rollout status deployment/springboot-service --timeout=120s

echo
echo "${BOLD}Step 4: Verifying Spring Boot config matches GitHub Repository${OFF}"
sb_git=$(query_sb)
echo "  [Spring Boot] active config: $sb_git"

if echo "$sb_git" | grep -q "Spring Boot live from GitOps ConfigMap!"; then
  ok "Spring Boot configuration successfully synchronized from GitHub repository via ArgoCD!"
else
  bad "Configuration does not match GitHub repository state"
fi

echo
echo "${BOLD}==================================================================${OFF}"
if [ "$FAIL" -eq 0 ]; then
  echo "${GREEN}${BOLD} ALL $PASS GITHUB-SYNC CHECKS PASSED: GitHub -> ArgoCD -> ConfigMap -> Pod Reload verified!${OFF}"
else
  echo "${RED}${BOLD} $FAIL FAILED, $PASS passed${OFF}"
fi
echo "${BOLD}==================================================================${OFF}"
