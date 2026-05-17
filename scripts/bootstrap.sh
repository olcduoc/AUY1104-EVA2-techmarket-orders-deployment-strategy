#!/usr/bin/env bash
# ============================================================
# scripts/bootstrap.sh
#
# Wrapper local que:
#  1. Verifica credenciales AWS locales
#  2. Refresca los GitHub Secrets con esas credenciales
#  3. Dispara el workflow bootstrap-cluster.yml
#  4. Sigue el run en vivo
#
# Uso: ./scripts/bootstrap.sh
# ============================================================

set -e

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()    { printf "${GREEN}✓${NC} %s\n" "$1"; }
err()   { printf "${RED}✗${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}⚠${NC} %s\n" "$1"; }
info()  { printf "→ %s\n" "$1"; }

echo "============================================"
echo "  AUY1104 EVA2 — Bootstrap del Cluster"
echo "============================================"
echo

# ------------------------------------------------------------
# 1. Verificar herramientas
# ------------------------------------------------------------
info "Verificando herramientas locales..."
for cmd in aws gh; do
  if ! command -v "$cmd" >/dev/null; then
    err "Falta '$cmd'. Instalá la herramienta antes de seguir."
    exit 1
  fi
done
ok "Herramientas instaladas: aws, gh"

# ------------------------------------------------------------
# 2. Verificar credenciales AWS locales
# ------------------------------------------------------------
info "Verificando credenciales AWS locales..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  err "Credenciales AWS locales inválidas o expiradas."
  echo "  → Reinicia el AWS Learner Lab (Start Lab) y pega el bloque [default]"
  echo "    actualizado en ~/.aws/credentials"
  exit 1
fi
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
ok "Credenciales AWS válidas (Account: $ACCOUNT)"

# ------------------------------------------------------------
# 3. Verificar permisos críticos
# ------------------------------------------------------------
info "Verificando permisos EKS..."
if ! aws eks list-clusters --region us-east-1 >/dev/null 2>&1; then
  err "Permisos EKS denegados. El lab puede estar cerrado (End Lab)."
  echo "  → Reinicia el AWS Learner Lab y volvé a copiar las credenciales."
  exit 1
fi
ok "Permisos EKS OK"

# ------------------------------------------------------------
# 4. Verificar autenticación con GitHub
# ------------------------------------------------------------
info "Verificando autenticación con GitHub..."
if ! gh auth status >/dev/null 2>&1; then
  err "No estás autenticado en gh. Ejecutá: gh auth login"
  exit 1
fi
ok "GitHub CLI autenticado"

# ------------------------------------------------------------
# 5. Refrescar GitHub Secrets
# ------------------------------------------------------------
info "Refrescando GitHub Secrets con credenciales actuales..."
gh secret set AWS_ACCESS_KEY_ID     --body "$(aws configure get aws_access_key_id)"   >/dev/null
gh secret set AWS_SECRET_ACCESS_KEY --body "$(aws configure get aws_secret_access_key)" >/dev/null
gh secret set AWS_SESSION_TOKEN     --body "$(aws configure get aws_session_token)"   >/dev/null
ok "Secrets actualizados: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN"

# ------------------------------------------------------------
# 6. Disparar workflow
# ------------------------------------------------------------
info "Lanzando workflow bootstrap-cluster.yml..."
gh workflow run bootstrap-cluster.yml
ok "Workflow lanzado"

# Pequeña pausa para que GitHub registre el run
sleep 5

# ------------------------------------------------------------
# 7. Seguir el run
# ------------------------------------------------------------
echo
info "Siguiendo ejecución (Ctrl+C para salir; el run sigue en GitHub)..."
echo "  → Si Ctrl+C, podés volver a engancharte con: gh run watch"
echo "  → O abrir en browser: gh run list --workflow=bootstrap-cluster.yml --limit 1"
echo
gh run watch || true

# ------------------------------------------------------------
# 8. Resumen final
# ------------------------------------------------------------
echo
LAST_RUN=$(gh run list --workflow=bootstrap-cluster.yml --limit 1 --json databaseId,status,conclusion --jq '.[0]')
STATUS=$(echo "$LAST_RUN" | jq -r .status)
CONCLUSION=$(echo "$LAST_RUN" | jq -r .conclusion)

if [ "$CONCLUSION" = "success" ]; then
  ok "Bootstrap completado con éxito"
  echo
  echo "Próximo paso — refrescar kubeconfig local y desplegar:"
  echo "  aws eks update-kubeconfig --name duoc-eks-cluster-cli --region us-east-1"
  echo "  gh workflow run deploy-eks.yml -f strategy=blue-green -f action=deploy"
elif [ "$STATUS" = "in_progress" ] || [ "$STATUS" = "queued" ]; then
  warn "El run sigue en curso. Volvé a engancharte con: gh run watch"
else
  err "Bootstrap falló (status=$STATUS, conclusion=$CONCLUSION)"
  echo "  → Revisá los logs: gh run view --log"
  exit 1
fi
