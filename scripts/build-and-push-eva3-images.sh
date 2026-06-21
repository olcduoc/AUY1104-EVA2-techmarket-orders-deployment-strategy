#!/usr/bin/env bash
# ============================================================
# scripts/build-and-push-eva3-images.sh
#
# Construye y publica en ECR las dos imágenes nuevas de EVA3:
#   - duoc-eks-app:v3-broken   (simulación de falla)
#   - duoc-eks-app:v2-toggle   (demo de feature toggle)
#
# Reutiliza el mismo repositorio ECR de EVA2 (duoc-eks-app),
# solo agrega tags nuevos. No toca :v1 ni :v2.
#
# Uso: ./scripts/build-and-push-eva3-images.sh
# ============================================================

set -e

ECR_REPO="duoc-eks-app"
REGION="${AWS_REGION:-us-east-1}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()    { printf "${GREEN}✓${NC} %s\n" "$1"; }
err()   { printf "${RED}✗${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}⚠${NC} %s\n" "$1"; }
info()  { printf "→ %s\n" "$1"; }

echo "============================================"
echo "  AUY1104 EVA3 — Build & Push de imágenes"
echo "============================================"
echo

# ------------------------------------------------------------
# 1. Verificar herramientas y credenciales
# ------------------------------------------------------------
for cmd in aws docker; do
  if ! command -v "$cmd" >/dev/null; then
    err "Falta '$cmd'. Instalá la herramienta antes de seguir."
    exit 1
  fi
done

info "Verificando credenciales AWS locales..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  err "Credenciales AWS locales inválidas o expiradas."
  echo "  → Reiniciá el AWS Learner Lab (Start Lab) y actualizá ~/.aws/credentials"
  exit 1
fi
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
ok "Credenciales válidas (Account: $ACCOUNT)"

ECR_URI="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO}"

# ------------------------------------------------------------
# 2. Login en ECR
# ------------------------------------------------------------
info "Autenticando Docker contra ECR..."
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"
ok "Login en ECR exitoso"

# ------------------------------------------------------------
# 3. Build y push: v3-broken (simulación de falla)
# ------------------------------------------------------------
info "Construyendo imagen v3-broken..."
docker build -t "${ECR_URI}:v3-broken" app/v3-broken
ok "Imagen v3-broken construida"

info "Publicando v3-broken en ECR..."
docker push "${ECR_URI}:v3-broken"
ok "v3-broken publicada: ${ECR_URI}:v3-broken"
echo

# ------------------------------------------------------------
# 4. Build y push: v2-toggle (demo de feature toggle)
# ------------------------------------------------------------
info "Construyendo imagen v2-toggle..."
docker build -t "${ECR_URI}:v2-toggle" app/feature-toggle
ok "Imagen v2-toggle construida"

info "Publicando v2-toggle en ECR..."
docker push "${ECR_URI}:v2-toggle"
ok "v2-toggle publicada: ${ECR_URI}:v2-toggle"
echo

# ------------------------------------------------------------
# 5. (Opcional) Build y push: imagen de hotfix
# ------------------------------------------------------------
if [ -d "app/hotfix" ]; then
  info "Construyendo imagen de hotfix (app/hotfix)..."
  docker build -t "${ECR_URI}:v1-hotfix" app/hotfix
  docker push "${ECR_URI}:v1-hotfix"
  ok "v1-hotfix publicada: ${ECR_URI}:v1-hotfix"
else
  warn "No existe app/hotfix/ — omitido. Crea esa carpeta con tu parche antes de"
  warn "ejecutar 'gh workflow run deploy-eks.yml -f action=hotfix'."
fi

echo
ok "Listo. Imágenes disponibles en ${ECR_URI}"
echo
info "Próximos pasos:"
echo "  1) Configurar monitoreo:"
echo "     gh workflow run setup-monitoring.yml -f sns_email=tu-correo@duocuc.cl"
echo "  2) Desplegar Blue-Green normal:"
echo "     gh workflow run deploy-eks.yml -f strategy=blue-green -f action=deploy"
echo "  3) Simular la falla (con BLUE ya activo):"
echo "     gh workflow run deploy-eks.yml -f strategy=blue-green -f action=deploy -f simulate_failure=true"
echo "  4) Probar el feature toggle:"
echo "     kubectl apply -f k8s/feature-flags/green-toggle.yaml"
echo "     gh workflow run deploy-eks.yml -f action=feature-toggle -f flag_value=true"
echo "  5) Probar el hotfix:"
echo "     gh workflow run deploy-eks.yml -f action=hotfix -f hotfix_target_deployment=app-blue -f hotfix_image_tag=v1-hotfix"
