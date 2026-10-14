#!/usr/bin/env bash
# ==============================================================================
# test-db-sync.sh: Tests dynamic sync from PostgreSQL DB -> ConfigMap -> Pods
# Proves: Updating a SQL table row automatically updates the K8s ConfigMap,
#         Stakater Reloader triggers a rolling restart, and the pod serves
#         the new DB config with ZERO application code and ZERO DB dependencies!
# ==============================================================================
set -euo pipefail

NS=gitops-demo
GREEN=$'\033[32m'; RED=$'\033[31m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
PASS=0; FAIL=0

ok()  { PASS=$((PASS+1)); echo "  ${GREEN}PASS${OFF}  $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ${RED}FAIL${OFF}  $1"; }

echo "${BOLD}==================================================================${OFF}"
echo "${BOLD} Database-to-ConfigMap Sync Acceptance Test${OFF}"
echo "${BOLD}==================================================================${OFF}"

query_sb() {
  kubectl -n $NS exec deploy/springboot-service -- wget -qO- --timeout=5 "http://127.0.0.1:8081/api/v1/config" 2>/dev/null
}

echo
echo "${BOLD}Step 1: Reading initial Spring Boot configuration${OFF}"
sb_initial=$(query_sb)
echo "  [Spring Boot] current config: $sb_initial"

echo
echo "${BOLD}Step 2: Updating configuration row in PostgreSQL database${OFF}"
NEW_MSG="UPDATED dynamically from PostgreSQL DB at $(date +%T)!"
NEW_MAX=9999

kubectl -n $NS exec deploy/postgres -- psql -U postgres -d configdb -c \
  "UPDATE app_properties SET prop_value = '$NEW_MSG' WHERE application = 'springboot-service' AND prop_key = 'APP_MESSAGE';"
kubectl -n $NS exec deploy/postgres -- psql -U postgres -d configdb -c \
  "UPDATE app_properties SET prop_value = '$NEW_MAX' WHERE application = 'springboot-service' AND prop_key = 'APP_MAX_ORDER_QUANTITY';"

echo "  Database updated successfully."

echo
echo "${BOLD}Step 3: Waiting for DB-Syncer to reconcile ConfigMap and Reloader to Rollout Pod${OFF}"
echo "  Waiting for springboot-service to reload..."
sleep 6

kubectl -n $NS rollout status deployment/springboot-service --timeout=120s

echo
echo "${BOLD}Step 4: Probing Spring Boot with new DB-driven configuration${OFF}"
sb_new=$(query_sb)
echo "  [Spring Boot] new config: $sb_new"

if echo "$sb_new" | grep -q "UPDATED dynamically from PostgreSQL DB"; then
  ok "Spring Boot picked up updated message from PostgreSQL!"
else
  bad "Spring Boot failed to receive new message from PostgreSQL"
fi

if echo "$sb_new" | grep -q "$NEW_MAX"; then
  ok "Spring Boot picked up updated maxOrderQuantity: $NEW_MAX from PostgreSQL!"
else
  bad "Spring Boot failed to receive new maxOrderQuantity from PostgreSQL"
fi

echo
echo "${BOLD}==================================================================${OFF}"
if [ "$FAIL" -eq 0 ]; then
  echo "${GREEN}${BOLD} ALL $PASS DB-SYNC CHECKS PASSED: Database -> ConfigMap -> Pod Reload verified!${OFF}"
else
  echo "${RED}${BOLD} $FAIL FAILED, $PASS passed${OFF}"
fi
echo "${BOLD}==================================================================${OFF}"
