#!/usr/bin/env bash
#
# install.sh - Instalador TODO-EN-UNO del servidor Minecraft Forge para Raspberry Pi 4.
#
# Este unico archivo se basta solo: escribe la configuracion, instala Java 17 y Forge,
# descarga los mods y crea el servicio. No necesitas los demas archivos.
#
# USO en la Pi (por SSH):
#   nano install.sh        # pega este contenido y guarda (Ctrl-O, Enter, Ctrl-X)
#   sudo bash install.sh
#
set -euo pipefail

# ================= CONFIGURACION (editable) =================
MC_VERSION="1.20.1"
FORGE_FALLBACK="47.3.0"
INSTALL_DIR="/opt/minecraft"
SERVICE_USER="minecraft"
MAX_RAM="2800M"       # Baja a 2560M si hay cierres por falta de memoria.
# ===========================================================

echo ">>> Instalador todo-en-uno del servidor Minecraft"
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: ejecutalo con sudo ->  sudo bash install.sh"; exit 1
fi

# --- 1) Paquetes ---
echo ">>> Instalando Java 17 y utilidades..."
apt-get update
apt-get install -y openjdk-17-jre-headless screen curl python3 ca-certificates tar

# --- 2) Usuario y carpetas ---
id -u "$SERVICE_USER" &>/dev/null || useradd -r -m -d "$INSTALL_DIR" -s /usr/sbin/nologin "$SERVICE_USER"
mkdir -p "$INSTALL_DIR/mods"

# --- 3) Escribir el descargador de mods ---
cat > "$INSTALL_DIR/download_mods.py" <<'PYEOF'
#!/usr/bin/env python3
"""Descarga mods (y dependencias obligatorias) desde Modrinth para 1.20.1 Forge."""
import sys, os, json, urllib.request, urllib.parse, time

MC = "1.20.1"
LOADER = "forge"
DEST = sys.argv[1] if len(sys.argv) > 1 else "mods"

# Edita esta lista para anadir/quitar mods (slug de modrinth.com/mod/<slug>).
MODS = [
    "create", "tinkers-construct", "securitycraft",   # contenido
    "supplementaries", "macaws-furniture",            # decoracion
    "ferrite-core", "modernfix", "memoryleakfix",     # memoria (importante en 4GB)
    "chunky", "spark",                                # utilidades
]

API = "https://api.modrinth.com/v2"
UA = "isaac-raspberry-pi-mc-setup/1.0 (uso personal)"

def api_get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)

def best_version(project):
    q = urllib.parse.urlencode({"loaders": json.dumps([LOADER]),
                                "game_versions": json.dumps([MC])})
    versions = api_get(f"{API}/project/{project}/version?{q}")
    if not versions:
        return None
    releases = [v for v in versions if v.get("version_type") == "release"]
    return (releases or versions)[0]

def download(url, path):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=180) as r, open(path, "wb") as f:
        f.write(r.read())

def main():
    os.makedirs(DEST, exist_ok=True)
    queue, seen, done, failed = list(MODS), set(), set(), []
    while queue:
        project = queue.pop(0)
        if project in seen:
            continue
        seen.add(project)
        try:
            v = best_version(project)
            if not v:
                print(f"  [!] Sin version {MC}/{LOADER} para '{project}'"); failed.append(project); continue
            files = v.get("files", [])
            f = next((x for x in files if x.get("primary")), files[0] if files else None)
            if not f:
                print(f"  [!] '{project}' sin archivo"); failed.append(project); continue
            name = f["filename"]
            if name in done:
                continue
            print(f"  -> {project}: {name}")
            download(f["url"], os.path.join(DEST, name)); done.add(name)
            for dep in v.get("dependencies", []):
                if dep.get("dependency_type") == "required" and dep.get("project_id"):
                    queue.append(dep["project_id"])
            time.sleep(0.2)
        except Exception as e:
            print(f"  [!] Fallo '{project}': {e}"); failed.append(project)
    print(f"\n>>> Descargados {len(done)} .jar en '{DEST}'")
    if failed:
        print("[!] Descarga manual (modrinth.com, 1.20.1 Forge) para:", ", ".join(failed))

if __name__ == "__main__":
    main()
PYEOF

# --- 4) Escribir server.properties ---
cat > "$INSTALL_DIR/server.properties" <<'PROPEOF'
motd=Servidor de Isaac y amigos
max-players=8
white-list=true
enforce-whitelist=true
online-mode=true
level-name=world
gamemode=survival
difficulty=normal
pvp=true
hardcore=false
allow-nether=true
spawn-protection=0
view-distance=6
simulation-distance=5
sync-chunk-writes=false
network-compression-threshold=256
max-tick-time=180000
allow-flight=true
enable-command-block=false
server-port=25565
enable-rcon=false
PROPEOF

# --- 5) Detectar e instalar Forge ---
echo ">>> Detectando version de Forge para $MC_VERSION..."
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

cd "$INSTALL_DIR"
if [[ ! -f "$INSTALL_DIR/run.sh" ]]; then
  echo ">>> Descargando e instalando Forge (unos minutos)..."
  curl -fSL -o forge-installer.jar \
    "https://maven.minecraftforge.net/net/minecraftforge/forge/$FULL/forge-$FULL-installer.jar"
  java -jar forge-installer.jar --installServer
  rm -f forge-installer.jar forge-installer.jar.log
else
  echo ">>> Forge ya instalado, salto este paso."
fi

# --- 6) EULA + argumentos de la JVM ---
echo "eula=true" > "$INSTALL_DIR/eula.txt"
cat > "$INSTALL_DIR/user_jvm_args.txt" <<EOF
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

# --- 7) Mods ---
echo ">>> Descargando mods desde Modrinth..."
python3 "$INSTALL_DIR/download_mods.py" "$INSTALL_DIR/mods"

# --- 8) Permisos ---
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/run.sh"

# --- 9) Servicio systemd ---
echo ">>> Creando servicio systemd..."
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
echo " LISTO. Servidor instalado en $INSTALL_DIR"
echo "  Arrancar:    sudo systemctl start minecraft   (la 1a vez genera el mundo)"
echo "  Consola:     sudo -u $SERVICE_USER screen -r minecraft   (salir: Ctrl-A, D)"
echo "  En consola:  op TU_NOMBRE  |  whitelist add AMIGO  |  chunky radius 2000; chunky start"
echo "======================================================================"
