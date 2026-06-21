# Add-ons de Código EVA3 — TechMarket Orders

Este paquete contiene **únicamente los archivos nuevos o modificados** respecto del repositorio de EVA2 (`AUY1104-EVA2-techmarket-orders-deployment-strategy`). Ningún archivo de EVA2 fue alterado en su comportamiento por defecto: todo lo nuevo es aditivo y opt-in mediante inputs del `workflow_dispatch`.

## 1. Qué archivo va dónde

Copia este árbol completo sobre la raíz de tu repositorio existente (mismas rutas):

```
.github/workflows/
├── deploy-eks.yml          ← REEMPLAZA al actual (ver diff abajo)
└── setup-monitoring.yml    ← NUEVO

k8s/
├── blue-green/
│   └── green-broken.yaml   ← NUEVO (no toca blue.yaml ni green.yaml)
└── feature-flags/
    ├── configmap.yaml      ← NUEVO
    └── green-toggle.yaml   ← NUEVO

app/
├── v3-broken/
│   ├── Dockerfile
│   ├── index.html
│   └── broken.conf
└── feature-toggle/
    ├── Dockerfile
    ├── index-old.html
    ├── index-new.html
    └── entrypoint.sh

scripts/
└── build-and-push-eva3-images.sh   ← NUEVO
```

## 2. Qué cambió exactamente en `deploy-eks.yml`

Los jobs `validate`, `deploy` y `rollback` son **idénticos** a EVA2, con dos excepciones mínimas:

1. El `action` del `workflow_dispatch` ahora acepta también `feature-toggle` y `hotfix` (antes solo `deploy`/`rollback`).
2. El step **Blue-Green** ahora soporta el input `simulate_failure` (`true`/`false`). Si es `true`, despliega `k8s/blue-green/green-broken.yaml` (imagen `v3-broken`) en lugar de `green.yaml`. Si es `false` (default), el comportamiento es exactamente el de EVA2.

Se agregaron dos jobs nuevos al final del archivo: `feature-toggle` y `hotfix`. Ninguno se ejecuta a menos que se invoque explícitamente con `-f action=feature-toggle` o `-f action=hotfix`, por lo que **no afectan ninguna corrida existente**.

## 3. Pasos para dejarlo operativo

```bash
# 1) Copiar los archivos de este paquete sobre tu repo y commitear
cp -r .github k8s app scripts <ruta-de-tu-repo>/
cd <ruta-de-tu-repo>
git checkout -b eva3-remediacion
git add .
git commit -m "EVA3: feature toggle, hotfix, monitoreo CloudWatch+SNS y simulación de falla v3-broken"
git push -u origin eva3-remediacion

# 2) Asegurar credenciales AWS vigentes (Learner Lab) y secrets de GitHub
./scripts/refresh-secrets.sh

# 3) Construir y publicar las imágenes nuevas en ECR
./scripts/build-and-push-eva3-images.sh

# 4) Configurar la capa de monitoreo (CloudWatch + SNS)
#    Requiere que el cluster y el Service svc-bluegreen ya existan
#    (bootstrap.sh + un deploy blue-green previo).
gh workflow run setup-monitoring.yml -f sns_email=tu-correo@duocuc.cl
gh run watch
# → confirma la suscripción desde tu correo antes de seguir

# 5) Desplegar Blue-Green normal (si no lo tienes activo)
gh workflow run deploy-eks.yml -f strategy=blue-green -f action=deploy
gh run watch

# 6) Ensayar el escenario de falla simulada (lo que hará el docente en vivo)
gh workflow run deploy-eks.yml -f strategy=blue-green -f action=deploy -f simulate_failure=true
gh run watch
# Esperado: el job "deploy" falla en "Verificación post-deploy" (~2-3 min)
#           y el job "rollback" se dispara solo y restaura BLUE.
#           En paralelo, revisa la consola CloudWatch (alarma -> ALARM)
#           y tu correo (notificación SNS).

# 7) Probar el Feature Toggle
kubectl apply -f k8s/feature-flags/configmap.yaml

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
sed "s|IMAGE_TOGGLE|${ACCOUNT}.dkr.ecr.us-east-1.amazonaws.com/duoc-eks-app:v2-toggle|g" \
  k8s/feature-flags/green-toggle.yaml | kubectl apply -f -

gh workflow run deploy-eks.yml -f action=feature-toggle -f flag_value=true
gh run watch
kubectl port-forward svc/svc-feature-toggle 8080:80
# abrir http://localhost:8080 -> debe verse "Feature Toggle: ON"

# 8) Probar el Hotfix
#    Antes, crea app/hotfix/ con tu parche (puede ser una copia de
#    app/v1 con un fix puntual) y agrégalo al script de build, o
#    simplemente reusa la imagen :v1 como hotfix_image_tag=v1 para
#    el ensayo.
gh workflow run deploy-eks.yml -f action=hotfix -f hotfix_target_deployment=app-blue -f hotfix_image_tag=v1
gh run watch
```

## 4. Checklist de evidencias a capturar (para el informe y la presentación)

| # | Evidencia | Dónde obtenerla |
|---|---|---|
| 1 | Job `deploy` en rojo por fallo del smoke test | Pestaña *Actions* del run del paso 6 |
| 2 | Alarma CloudWatch en estado `ALARM` | Consola AWS → CloudWatch → Alarms |
| 3 | Correo de notificación SNS | Tu bandeja de entrada |
| 4 | Job `rollback` en verde, disparado automáticamente | Mismo run del paso 6 |
| 5 | `kubectl get pods` + `curl` HTTP 200 tras el rollback | Terminal local o step "Estado final del cluster" |
| 6 | Diff del ConfigMap `feature-flags` antes/después | Logs del job `feature-toggle` (paso 7) |
| 7 | Página servida cambiando con el toggle | Captura del `port-forward` (paso 7) |
| 8 | Job `hotfix` en verde + verificación HTTP 200 | Logs del job `hotfix` (paso 8) |

## 5. Notas importantes

* **CloudWatch namespace:** `setup-monitoring.yml` asume que `svc-bluegreen` provisiona un **Classic Load Balancer** (comportamiento por defecto de un Service `type: LoadBalancer` en EKS sin el AWS Load Balancer Controller instalado, que es el caso de este repositorio). Por eso usa `AWS/ELB` + `UnHealthyHostCount` con dimensión `LoadBalancerName`, no `AWS/ApplicationELB`. Si en algún momento migras a un Ingress/ALB real, la alarma debe recrearse con `AWS/ApplicationELB` y dimensión `TargetGroup`.
* **Costos/cuotas del Learner Lab:** el Feature Toggle usa un Service `ClusterIP` (no un Load Balancer adicional) para no consumir cuota de ELBs del laboratorio.
* **No se modificó** `blue.yaml`, `green.yaml`, `rolling-update/*`, `recreate/*`, `canary/*` ni los workflows `bootstrap-cluster.yml`/`teardown-cluster.yml` de EVA2.
