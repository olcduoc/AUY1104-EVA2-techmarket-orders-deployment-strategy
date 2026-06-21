#!/bin/sh
# Entrypoint de la imagen feature-toggle (EVA3).
# Lee NEW_CHECKOUT_FLOW (inyectada vía envFrom desde el ConfigMap
# feature-flags) y copia el index.html correspondiente ANTES de
# arrancar nginx. El cambio se aplica en cada reinicio del pod
# (kubectl rollout restart), sin reconstruir ni republicar la imagen.
set -e

if [ "$NEW_CHECKOUT_FLOW" = "true" ]; then
  echo "[entrypoint] NEW_CHECKOUT_FLOW=true -> sirviendo index-new.html"
  cp /usr/share/nginx/html/index-new.html /usr/share/nginx/html/index.html
else
  echo "[entrypoint] NEW_CHECKOUT_FLOW=${NEW_CHECKOUT_FLOW:-false} -> sirviendo index-old.html"
  cp /usr/share/nginx/html/index-old.html /usr/share/nginx/html/index.html
fi

exec nginx -g 'daemon off;'
