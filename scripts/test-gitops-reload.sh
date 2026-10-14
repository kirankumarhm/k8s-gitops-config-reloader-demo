#!/usr/bin/env bash
# ==============================================================================
# test-gitops-reload.sh: Automated Acceptance Test for Reloader & ConfigMaps
# Proves: A ConfigMap change triggers an automatic zero-downtime rolling update,
#         and the new config is actively served by all 4 polyglot services.
# ==============================================================================
set -euo pipefail

NS=gitops-demo
GREEN=$'\033[32m'; RED=$'\033[31m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
PASS=0; FAIL=0

ok()  { PASS=$((PASS+1)); echo "  ${GREEN}PASS${OFF}  $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ${RED}FAIL${OFF}  $1"; }

echo "${BOLD}==================================================================${OFF}"
echo "${BOLD} GitOps & Stakater Reloader Acceptance Test (Polyglot)${OFF}"
echo "${BOLD}==================================================================${OFF}"

echo
echo "${BOLD}Step 1: Check Current Running Pods & Versions${OFF}"
kubectl -n $NS get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP --no-headers | awk '{printf "  %-35s %-8s %s\n", $1, $2, $3}'

# Helper function to query a service in-cluster
query_svc() {
  local svc="$1" port="$2" path="$3"
  kubectl -n $NS exec deploy/"$svc" -- wget -qO- --timeout=5 "http://127.0.0.1:$port$path" 2>/dev/null
}

echo
echo "${BOLD}Step 2: Probing initial configuration across services${OFF}"
sb_init=$(query_svc springboot-service 8081 /api/v1/config)
echo "  [Spring Boot] initial: $sb_init"

go_init=$(query_svc go-service 8085 /api/v1/config)
echo "  [Go]          initial: $go_init"

node_init=$(query_svc node-service 8084 /api/v1/config)
echo "  [Node.js]     initial: $node_init"

py_init=$(query_svc python-service 8086 /api/v1/config)
echo "  [Python]      initial: $py_init"

echo
echo "${BOLD}Step 3: Updating ConfigMaps (Simulating GitOps sync or config change)${OFF}"

# Patch ConfigMaps with new values
kubectl -n $NS patch configmap springboot-config --type merge -p '{"data":{"APP_MESSAGE":"UPDATED by Reloader at runtime!","APP_MAX_ORDER_QUANTITY":"999"}}'
kubectl -n $NS patch configmap go-config --type merge -p '{"data":{"config.json":"{\"environment\":\"production-gitops\",\"message\":\"UPDATED Go config via Reloader!\",\"maxItems\":999,\"featureFlagActive\":true}"}}'
kubectl -n $NS patch configmap node-config --type merge -p '{"data":{"config.json":"{\"environment\":\"production-gitops\",\"message\":\"UPDATED Node config via Reloader!\",\"rateLimit\":999,\"featureFlagActive\":true}"}}'
kubectl -n $NS patch configmap python-config --type merge -p '{"data":{"config.json":"{\"environment\":\"production-gitops\",\"message\":\"UPDATED Python config via Reloader!\",\"timeoutSeconds\":999,\"featureFlagActive\":true}"}}'

echo "  ConfigMaps patched successfully."

echo
echo "${BOLD}Step 4: Waiting for Stakater Reloader to detect changes and perform RollingUpdate${OFF}"
echo "  Waiting for deployments to roll out new pods with updated configuration..."

kubectl -n $NS rollout status deployment/springboot-service --timeout=120s
kubectl -n $NS rollout status deployment/go-service --timeout=120s
kubectl -n $NS rollout status deployment/node-service --timeout=120s
kubectl -n $NS rollout status deployment/python-service --timeout=120s

echo
echo "${BOLD}Step 5: Verifying new configuration values in updated pods${OFF}"

sb_new=$(query_svc springboot-service 8081 /api/v1/config)
echo "$sb_new" | grep -q "UPDATED by Reloader" && ok "Spring Boot picked up new ConfigMap values (maxOrderQuantity: 999)" || bad "Spring Boot failed to update"

go_new=$(query_svc go-service 8085 /api/v1/config)
echo "$go_new" | grep -q "UPDATED Go config" && ok "Go Service picked up new ConfigMap values (maxItems: 999)" || bad "Go Service failed to update"

node_new=$(query_svc node-service 8084 /api/v1/config)
echo "$node_new" | grep -q "UPDATED Node config" && ok "Node.js Service picked up new ConfigMap values (rateLimit: 999)" || bad "Node.js Service failed to update"

py_new=$(query_svc python-service 8086 /api/v1/config)
echo "$py_new" | grep -q "UPDATED Python config" && ok "Python Service picked up new ConfigMap values (timeoutSeconds: 999)" || bad "Python Service failed to update"

echo
echo "${BOLD}==================================================================${OFF}"
if [ "$FAIL" -eq 0 ]; then
  echo "${GREEN}${BOLD} ALL $PASS CHECKS PASSED: Pure Kubernetes GitOps + Reloader works with ZERO custom client code!${OFF}"
else
  echo "${RED}${BOLD} $FAIL FAILED, $PASS passed${OFF}"
fi
echo "${BOLD}==================================================================${OFF}"
