Actúa como mi ingeniero de sistemas. Objetivo: instalar y dejar funcionando un servidor de Minecraft con mods (Forge 1.20.1) en mi Raspberry Pi, conectándote por SSH desde este ordenador.

## Contexto
- La Pi está en mi red local. Host SSH: `pi-isaac` (prueba también `pi-isaac.local` o su IP si el nombre no resuelve). Usuario: `isaac`.
- La contraseña la introduciré YO cuando SSH o `sudo` la pidan. No la guardes en ningún archivo ni la escribas en texto. Ejecuta SSH de forma interactiva.
- Es una Raspberry Pi 4 de 4GB que arranca desde un SSD NVMe (por USB). Ya tiene un par de servidores ligeros corriendo que puedo apagar si hace falta.
- Sistema operativo: Raspberry Pi OS Lite 64-bit (ARM64).
- Ya tengo un instalador PROBADO en este proyecto: `C:\Users\isaac\Documents\SM\minecraft-pi-server\install.sh` (y versiones modulares + README en esa misma carpeta). Úsalo en vez de reinventarlo. Léelo primero para entender qué hace.

## Mods objetivo (ya configurados en install.sh, se bajan de Modrinth)
Create, Tinkers' Construct, SecurityCraft, Supplementaries, Macaw's Furniture, y de optimización FerriteCore, ModernFix, Memory Leak Fix, Chunky y spark. Java 17, heap ~2.8GB, Forge 1.20.1.

## Tareas (en orden; explícame cada paso y DETENTE si algo falla)
1. Comprueba la conexión SSH a `isaac@pi-isaac` (o `.local` / IP).
2. En la Pi, recopila y muéstrame: `uname -m` (debe ser `aarch64`), `free -h`, `nproc`, `df -h /`, versión del SO (`cat /etc/os-release`), y si el puerto 25565 está libre: `sudo ss -tlnp | grep 25565`.
3. Según la RAM libre: si mis otros servidores dejan menos de ~3.2GB libres, PREGÚNTAME si los apago o si bajamos `MAX_RAM` en `install.sh` (por defecto `2800M`; alternativas `2560M` / `2048M`). No apagues ningún servicio sin confirmarlo conmigo. Si el 25565 está ocupado, cambia `server-port`.
4. Copia el instalador a la Pi: `scp "C:\Users\isaac\Documents\SM\minecraft-pi-server\install.sh" isaac@pi-isaac:~/`.
5. Ejecuta `sudo bash install.sh` en la Pi y sigue la salida. Si algún mod falla al descargarse, dímelo (el script lista los fallidos al final).
6. Arranca el servidor: `sudo systemctl start minecraft`. Verifica con `journalctl -u minecraft -f` que genera el mundo y carga los mods sin errores hasta que veas `Done`. Muéstrame cualquier crash o error de mod.
7. Ayúdame a administrarlo por la consola (`sudo -u minecraft screen -r minecraft`; se sale con Ctrl-A y luego D): hacerme OP (`op MI_NOMBRE`), añadir amigos a la whitelist (`whitelist add NOMBRE`), y pregenerar el mundo con Chunky (`chunky radius 2000` y `chunky start`).
8. Conexión externa para mis amigos: PREGÚNTAME si prefiero Playit.gg (fácil, funciona con CGNAT) o Tailscale (privado, sin ping extra), y configúralo.
9. Verificación final: confirma el rendimiento con `spark tps` en la consola, que el servicio arranca solo (`systemctl is-enabled minecraft`), y hazme un resumen del estado y de cómo administrarlo día a día.

## Restricciones
- No toques ni rompas los otros servidores que ya corren en la Pi. Confírmame antes de parar cualquier servicio.
- Usa solo `apt-get install` de los paquetes necesarios; no hagas un `apt-get upgrade` completo que pueda afectar a mis otros servidores.
- No expongas el servidor a internet hasta que te avise. Recuérdame cambiar la contraseña SSH (es débil) o configurar claves SSH antes de abrirlo al exterior.
- Si un comando necesita una decisión mía (RAM, puerto, túnel, apagar servicios), pregúntame en vez de asumir.
