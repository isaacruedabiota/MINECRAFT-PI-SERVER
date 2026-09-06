#!/usr/bin/env bash
#
# backup.sh - Copia de seguridad del mundo. Guarda las ultimas 7 copias.
# Uso:   sudo bash backup.sh
# Automatizar (cada dia a las 5:00): ver el README, seccion Mantenimiento.
#
set -euo pipefail

INSTALL_DIR="/opt/minecraft"
BK_DIR="$INSTALL_DIR/backups"
KEEP=7

mkdir -p "$BK_DIR"
ts="$(date +%Y%m%d-%H%M%S)"

# Si el servidor esta corriendo, forzar guardado antes de copiar.
if screen -list 2>/dev/null | grep -q "\.minecraft"; then
  screen -p 0 -S minecraft -X eval 'stuff "save-all flush\015"' || true
  sleep 5
fi

tar -czf "$BK_DIR/world-$ts.tar.gz" -C "$INSTALL_DIR" world
echo "Copia creada: $BK_DIR/world-$ts.tar.gz"

# Borrar las mas antiguas, quedarnos con las ultimas $KEEP
ls -1t "$BK_DIR"/world-*.tar.gz 2>/dev/null | tail -n +$((KEEP+1)) | xargs -r rm -f
echo "Copias conservadas: $(ls -1 "$BK_DIR"/world-*.tar.gz 2>/dev/null | wc -l)"
