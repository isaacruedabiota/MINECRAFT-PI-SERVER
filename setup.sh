#!/usr/bin/env bash
#
# setup.sh - Instalador de servidor Minecraft Forge para Raspberry Pi 4 (4GB)
# Mods: Create, Tinkers' Construct, SecurityCraft + decoracion + optimizacion.
#
# USO:   sudo bash setup.sh
#
# Lo que hace:
#   1. Instala Java 17 y utilidades.
#   2. Crea un usuario de servicio 'minecraft' y la carpeta /opt/minecraft.
#   3. Descarga e instala Forge para Minecraft 1.20.1.
#   4. Acepta el EULA y aplica la configuracion optimizada.
#   5. Descarga todos los mods (y sus dependencias) desde Modrinth.
#   6. Crea un servicio systemd para arrancar/parar el servidor.
#
set -euo pipefail

# ============ CONFIGURACION (puedes editar) ============
MC_VERSION="1.20.1"       # Version de Minecraft
FORGE_FALLBACK="47.3.0"   # Version de Forge si falla la deteccion automatica
INSTALL_DIR="/opt/minecraft"
SERVICE_USER="minecraft"
MAX_RAM="2800M"           # RAM para el servidor. Bajala a 2560M si hay cierres por memoria.
# =======================================================

echo ">>> Instalador del servidor Minecraft para Raspberry Pi"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: ejecutalo con sudo ->  sudo bash setup.sh"
  exit 1
fi

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Limpiar posibles finales de linea de Windows (CRLF) en los archivos auxiliares ---
for f in "$SRC_DIR"/download_mods.py "$SRC_DIR"/server.properties "$SRC_DIR"/backup.sh "$SRC_DIR"/attach-console.sh; do
  [[ -f "$f" ]] && sed -i 's/\r$//' "$f"
done

# --- 1) Paquetes del sistema ---
echo ">>> Instalando Java 17 y utilidades..."
apt-get update
apt-get install -y openjdk-17-jre-headless screen curl python3 ca-certificates tar

# --- 2) Usuario de servicio y carpetas ---
if ! id -u "$SERVICE_USER" &>/dev/null; then
  useradd -r -m -d "$INSTALL_DIR" -s /usr/sbin/nologin "$SERVICE_USER"
fi
mkdir -p "$INSTALL_DIR/mods"

# --- 3) Detectar version de Forge ---
echo ">>> Detectando la ultima version de Forge para $MC_VERSION..."
FORGE_VER="$(curl -fsSL https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json 2>/dev/null \
  | python3 -c "import sys,json
try:
    d=json.load(sys.stdin)['promos']
    print(d.get('$MC_VERSION-recommended') or d.get('$MC_VERSION-latest') or '')
except Exception:
    print('')" 2>/dev/null || true)"
[[ -z "${FORGE_VER:-}" ]] && FORGE_VER="$FORGE_FALLBACK"
FULL="$MC_VERSION-$FORGE_VER"
echo ">>> Usando Forge $FULL"

# --- 4) Descargar e instalar el servidor Forge (solo si no esta ya instalado) ---
cd "$INSTALL_DIR"
if [[ ! -f "$INSTALL_DIR/run.sh" ]]; then
  echo ">>> Descargando el instalador de Forge..."
  curl -fSL -o forge-installer.jar \
    "https://maven.minecraftforge.net/net/minecraftforge/forge/$FULL/forge-$FULL-installer.jar"
  echo ">>> Instalando el servidor (esto puede tardar unos minutos)..."
  java -jar forge-installer.jar --installServer
  rm -f forge-installer.jar forge-installer.jar.log
else
  echo ">>> Forge ya instalado, salto este paso."
fi

# --- 5) Aceptar EULA ---
echo "eula=true" > "$INSTALL_DIR/eula.txt"

# --- 6) Configuracion ---
echo ">>> Aplicando configuracion..."
cp -f "$SRC_DIR/server.properties" "$INSTALL_DIR/server.properties"

# Argumentos de la JVM (memoria + flags de Aikar ajustados para poca RAM)
cat > "$INSTALL_DIR/user_jvm_args.txt" <<EOF
# Memoria + flags de Aikar (variante para <12GB, seguros para Raspberry Pi 4)
-Xms${MAX_RAM}
-Xmx${MAX_RAM}
-XX:+UseG1GC
-XX:+ParallelRefProcEnabled
-XX:MaxGCPauseMillis=200
-XX:+UnlockExperimentalVMOptions
-XX:+DisableExplicitGC
-XX:+AlwaysPreTouch
-XX:G1NewSizePercent=30
-XX:G1MaxNewSizePercent=40
-XX:G1HeapRegionSize=8M
-XX:G1ReservePercent=20
-XX:G1HeapWastePercent=5
-XX:G1MixedGCCountTarget=4
-XX:InitiatingHeapOccupancyPercent=15
-XX:G1MixedGCLiveThresholdPercent=90
-XX:G1RSetUpdatingPauseTimePercent=5
-XX:SurvivorRatio=32
-XX:+PerfDisableSharedMem
-XX:MaxTenuringThreshold=1
-Dusing.aikars.flags=https://mcflags.emc.gs
-Daikars.new.flags=true
EOF

# --- 7) Descargar mods ---
echo ">>> Descargando mods desde Modrinth..."
python3 "$SRC_DIR/download_mods.py" "$INSTALL_DIR/mods"

# --- 8) Permisos ---
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/run.sh"

# --- 9) Servicio systemd ---
echo ">>> Creando el servicio systemd..."
cat > /etc/systemd/system/minecraft.service <<EOF
[Unit]
Description=Servidor Minecraft Forge
After=network-online.target
Wants=network-online.target

[Service]
User=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/screen -DmS minecraft $INSTALL_DIR/run.sh nogui
ExecStop=/usr/bin/screen -p 0 -S minecraft -X eval 'stuff "say Apagando el servidor en 5 segundos...\015"'
ExecStop=/bin/sleep 5
ExecStop=/usr/bin/screen -p 0 -S minecraft -X eval 'stuff "save-all flush\015"'
ExecStop=/bin/sleep 5
ExecStop=/usr/bin/screen -p 0 -S minecraft -X eval 'stuff "stop\015"'
Restart=on-failure
RestartSec=15
TimeoutStopSec=90

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable minecraft.service

echo ""
echo "======================================================================"
echo " LISTO. El servidor esta instalado en $INSTALL_DIR"
echo ""
echo "  Arrancar:    sudo systemctl start minecraft"
echo "  Parar:       sudo systemctl stop minecraft"
echo "  Estado:      systemctl status minecraft"
echo "  Ver consola: sudo -u $SERVICE_USER screen -r minecraft   (salir: Ctrl-A, luego D)"
echo ""
echo " La PRIMERA vez tardara varios minutos en generar el mundo."
echo " Sigue el README para: hacerte OP, whitelist de amigos, pregenerar y conectar."
echo "======================================================================"
