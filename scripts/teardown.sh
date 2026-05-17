#!/usr/bin/env bash
# ============================================================
# scripts/teardown.sh
#
# Wrapper local que pide confirmación y dispara el workflow
# teardown-cluster.yml.
#
# Uso: ./scripts/teardown.sh [--delete-ecr]
# ============================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()    { printf "${GREEN}✓${NC} %s\n" "$1"; }
err()   { printf "${RED}✗${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}⚠${NC} %s\n" "$1"; }
info()  { printf "→ %s\n" "$1"; }

DELETE_ECR="false"
if [ "${1:-}" = "--delete-ecr" ]; then
  DELETE_ECR="true"
fi

echo "============================================"
echo "  AUY1104 EVA2 — Teardown del Cluster"
echo "============================================"
echo
warn "Esto va a DESTRUIR los siguientes recursos:"
echo "  - Cluster EKS: duoc-eks-cluster-cli"
echo "  - LoadBalancers y nodos del cluster"
if [ "$DELETE_ECR" = "true" ]; then
  echo "  - Repositorio ECR: duoc-eks-app (con todas sus imágenes)"
fi
echo

# Confirmación local antes de tocar nada
read -p "Escribe DESTROY para confirmar: " CONFIRM
if [ "$CONFIRM" != "DESTROY" ]; then
  err "Cancelado por el usuario."
  exit 1
fi

# ------------------------------------------------------------
# Verificaciones
# ------------------------------------------------------------
info "Verificando credenciales AWS locales..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  err "Credenciales AWS inválidas. Reiniciá el Learner Lab."
  exit 1
fi
ok "Credenciales OK"

info "Verificando autenticación GitHub..."
if ! gh auth status >/dev/null 2>&1; then
  err "No autenticado en gh."
  exit 1
fi
ok "gh autenticado"

# ------------------------------------------------------------
# Refrescar secrets (por si las credenciales cambiaron)
# ------------------------------------------------------------
info "Refrescando GitHub Secrets..."
gh secret set AWS_ACCESS_KEY_ID     --body "$(aws configure get aws_access_key_id)"   >/dev/null
gh secret set AWS_SECRET_ACCESS_KEY --body "$(aws configure get aws_secret_access_key)" >/dev/null
gh secret set AWS_SESSION_TOKEN     --body "$(aws configure get aws_session_token)"   >/dev/null
ok "Secrets actualizados"

# ------------------------------------------------------------
# Lanzar workflow
# ------------------------------------------------------------
info "Lanzando workflow teardown-cluster.yml..."
gh workflow run teardown-cluster.yml \
  -f cluster_name=duoc-eks-cluster-cli \
  -f aws_region=us-east-1 \
  -f confirm=DESTROY \
  -f delete_ecr="$DELETE_ECR"

ok "Workflow lanzado"
sleep 5

info "Siguiendo ejecución (Ctrl+C no detiene el teardown en AWS)..."
echo
gh run watch || true

echo
LAST_RUN=$(gh run list --workflow=teardown-cluster.yml --limit 1 --json status,conclusion --jq '.[0]')
CONCLUSION=$(echo "$LAST_RUN" | jq -r .conclusion)

if [ "$CONCLUSION" = "success" ]; then
  ok "Teardown completado con éxito"
else
  warn "Teardown reportó status: $CONCLUSION (revisá los logs)"
fi
