#!/usr/bin/env python3
"""
download_mods.py - Descarga mods (y sus dependencias obligatorias) desde Modrinth.

Uso:   python3 download_mods.py [carpeta_destino]
       (por defecto: ./mods)

Para anadir o quitar mods, edita la lista MODS de abajo con el 'slug' de Modrinth.
El slug es la parte final de la URL: modrinth.com/mod/<slug>
"""
import sys, os, json, urllib.request, urllib.parse, time

# ---------------- CONFIGURACION ----------------
MC = "1.20.1"          # Version de Minecraft
LOADER = "forge"       # Cargador de mods
DEST = sys.argv[1] if len(sys.argv) > 1 else "mods"

# Lista de mods (slugs de Modrinth). Las dependencias obligatorias
# (p.ej. Mantle para Tinkers, Moonlight para Supplementaries) se
# descargan solas, no hace falta ponerlas.
MODS = [
    # --- Contenido principal ---
    "create",             # Create
    "tinkers-construct",  # Tinkers' Construct
    "securitycraft",      # SecurityCraft
    # --- Decoracion (ligeros) ---
    "supplementaries",    # Supplementaries (deco + utilidades)
    "macaws-furniture",   # Macaw's Furniture
    # --- Rendimiento / memoria (IMPORTANTES para 4GB) ---
    "ferrite-core",       # FerriteCore  (reduce mucho la RAM)
    "modernfix",          # ModernFix    (menos RAM, arranque mas rapido)
    "memoryleakfix",      # Memory Leak Fix
    # --- Utilidades ---
    "chunky",             # Chunky (pregenerar el mundo)
    "spark",              # spark (medir rendimiento; opcional)
]
# -----------------------------------------------

API = "https://api.modrinth.com/v2"
UA = "isaac-raspberry-pi-mc-setup/1.0 (uso personal)"


def api_get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def best_version(project):
    q = urllib.parse.urlencode({
        "loaders": json.dumps([LOADER]),
        "game_versions": json.dumps([MC]),
    })
    versions = api_get(f"{API}/project/{project}/version?{q}")
    if not versions:
        return None
    # Preferir versiones estables (release) sobre beta/alpha
    releases = [v for v in versions if v.get("version_type") == "release"]
    return (releases or versions)[0]


def download(url, path):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=180) as r, open(path, "wb") as f:
        f.write(r.read())


def main():
    os.makedirs(DEST, exist_ok=True)
    queue = list(MODS)
    seen = set()
    files_done = set()
    failed = []

    while queue:
        project = queue.pop(0)
        if project in seen:
            continue
        seen.add(project)
        try:
            v = best_version(project)
            if not v:
                print(f"  [!] Sin version {MC}/{LOADER} para '{project}' - lo salto")
                failed.append(project)
                continue
            files = v.get("files", [])
            file = next((f for f in files if f.get("primary")), files[0] if files else None)
            if not file:
                print(f"  [!] '{project}' sin archivo descargable - lo salto")
                failed.append(project)
                continue
            name = file["filename"]
            if name in files_done:
                continue
            print(f"  -> {project}: {name}")
            download(file["url"], os.path.join(DEST, name))
            files_done.add(name)
            # Encolar dependencias OBLIGATORIAS
            for dep in v.get("dependencies", []):
                if dep.get("dependency_type") == "required" and dep.get("project_id"):
                    queue.append(dep["project_id"])
            time.sleep(0.2)  # ser amable con la API
        except Exception as e:
            print(f"  [!] Fallo con '{project}': {e}")
            failed.append(project)

    print(f"\n>>> Descargados {len(files_done)} archivos .jar en '{DEST}'")
    if failed:
        print("\n[!] Estos no se pudieron descargar automaticamente.")
        print("    Buscalos a mano en https://modrinth.com (version 1.20.1, Forge)")
        print("    y copia el .jar en la carpeta mods/:")
        for x in failed:
            print(f"      - {x}")


if __name__ == "__main__":
    main()
