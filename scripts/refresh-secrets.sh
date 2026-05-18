#!/usr/bin/env bash
# ============================================================
# scripts/refresh-secrets.sh
#
# Actualiza los 3 GitHub Secrets (AWS_ACCESS_KEY_ID,
# AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN) con las credenciales
# actuales del Learner Lab.
#
# Cuándo usarlo:
#   - Después de hacer Start Lab + actualizar ~/.aws/credentials
#   - Antes de cualquier workflow que NO sea bootstrap (porque
#     bootstrap.sh ya lo hace internamente).
#
# Uso: ./scripts/refresh-secrets.sh
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

echo "============================================"
echo "  AUY1104 EVA2 — Refresh GitHub Secrets"
echo "============================================"
echo

# ------------------------------------------------------------
# 1. Verificar herramientas
# ------------------------------------------------------------
for cmd in aws gh; do
  if ! command -v "$cmd" >/dev/null; then
    err "Falta '$cmd'. Instalá la herramienta antes de seguir."
    exit 1
  fi
done

# ------------------------------------------------------------
# 2. Verificar credenciales AWS locales
# ------------------------------------------------------------
info "Verificando credenciales AWS locales..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  err "Credenciales AWS locales inválidas o expiradas."
  echo "  → Reiniciá el AWS Learner Lab (Start Lab) y copiá el bloque [default]"
  echo "    actualizado a ~/.aws/credentials"
  exit 1
fi

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
ok "Credenciales válidas (Account: $ACCOUNT)"

# ------------------------------------------------------------
# 3. Verificar permisos críticos
# ------------------------------------------------------------
info "Verificando permisos EKS..."
if ! aws eks list-clusters --region us-east-1 >/dev/null 2>&1; then
  err "Permisos EKS denegados. El lab puede estar cerrado (voc-cancel-cred)."
  echo "  → Reiniciá el Learner Lab y volvé a copiar credenciales."
  exit 1
fi
ok "Permisos EKS OK"

# ------------------------------------------------------------
# 4. Verificar gh CLI
# ------------------------------------------------------------
info "Verificando autenticación con GitHub..."
if ! gh auth status >/dev/null 2>&1; then
  err "No estás autenticado en gh. Ejecutá: gh auth login"
  exit 1
fi
ok "GitHub CLI autenticado"

# ------------------------------------------------------------
# 5. Refrescar los 3 secrets
# ------------------------------------------------------------
info "Refrescando GitHub Secrets con credenciales actuales..."

ACCESS_KEY=$(aws configure get aws_access_key_id)
SECRET_KEY=$(aws configure get aws_secret_access_key)
SESSION_TOKEN=$(aws configure get aws_session_token)

if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ] || [ -z "$SESSION_TOKEN" ]; then
  err "Una de las credenciales está vacía en ~/.aws/credentials"
  echo "  ACCESS_KEY:    $([ -n "$ACCESS_KEY" ] && echo "OK" || echo "VACÍA")"
  echo "  SECRET_KEY:    $([ -n "$SECRET_KEY" ] && echo "OK" || echo "VACÍA")"
  echo "  SESSION_TOKEN: $([ -n "$SESSION_TOKEN" ] && echo "OK" || echo "VACÍA")"
  exit 1
fi

gh secret set AWS_ACCESS_KEY_ID     --body "$ACCESS_KEY"    >/dev/null
gh secret set AWS_SECRET_ACCESS_KEY --body "$SECRET_KEY"    >/dev/null
gh secret set AWS_SESSION_TOKEN     --body "$SESSION_TOKEN" >/dev/null

ok "Los 3 secrets actualizados"

# ------------------------------------------------------------
# 6. Mostrar estado final
# ------------------------------------------------------------
echo
info "Estado de los secrets en GitHub:"
gh secret list

echo
ok "Listo. Ahora podés lanzar cualquier workflow:"
echo "    gh workflow run deploy-eks.yml -f strategy=blue-green -f action=deploy"
echo "    gh workflow run teardown-cluster.yml -f confirm=DESTROY ..."
