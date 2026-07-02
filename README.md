Estructura mínima del README para el EFT:
```markdown
# TechMarket Orders — Pipeline CI/CD con Auto-Healing
## AUY1104 · EFT 2026 · olcduoc

## Arquitectura
<!-- Insertar imagen del diagrama FLUJO o cap-18-aws-eks-cluster -->

## Workflows modulares (EFT)
| Archivo | Disparador | Descripción |
|---|---|---|
| main-eft.yml | workflow_dispatch | Orquestador: llama a los 3 templates |
| wf-validate.yml | workflow_call | Template: lint + validación de manifiestos |
| wf-deploy-bluegreen.yml | workflow_call | Template: despliegue Blue-Green + health check |
| wf-rollback.yml | workflow_call | Template: rollback automático al entorno BLUE |

## Cómo usar
# Despliegue normal
gh workflow run main-eft.yml -f simulate_failure=false

# Simular falla + auto-healing (Prueba de Fuego)
gh workflow run main-eft.yml -f simulate_failure=true

## Estrategia Blue-Green
...
## Remediación automática
...
## Evidencias
...
