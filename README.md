# Servidor de Minecraft con mods en Raspberry Pi 4

Guía completa para montar tu servidor **Forge 1.20.1** (Create, Tinkers' Construct, SecurityCraft + decoración + optimización) en una **Raspberry Pi 4 de 4GB** con **NVMe**, para jugar tú y 4-6 amigos.

Casi todo está automatizado. Tú haces 3 cosas: **flashear el sistema**, **copiar esta carpeta** y **ejecutar un comando**.

---

## Expectativas realistas (léelo)

- Tu lista de mods es **mediana**, no un modpack gigante tipo RLCraft/ATM. Eso la hace viable en una Pi 4.
- El NVMe elimina el peor cuello de botella (carga de chunks). 
- El límite que queda es la **RAM de 4GB** y la **CPU** cuando hay muchas máquinas de **Create** funcionando a la vez con varios jugadores.
- Esperable: fluido con 2-4 jugadores; con 5-6 y mucha maquinaria de Create puede haber tirones puntuales. Se gestiona bajando la distancia de renderizado y pregenerando el mundo (ambos ya incluidos).

---

## 1. Qué necesitas

- Raspberry Pi 4 (4GB) con su fuente de alimentación oficial.
- Tu **SSD NVMe** + una **carcasa/adaptador USB 3.0 a NVMe con soporte UASP** (importante: la Pi 4 no tiene ranura M.2, se conecta por USB 3.0 — los puertos azules).
- **Disipador + ventilador** (o caja con ventilación). Con Create y varios jugadores la Pi trabaja de forma sostenida y sin refrigeración baja de rendimiento.
- Cable Ethernet al router (recomendado sobre WiFi para un servidor).
- Otro ordenador para flashear el NVMe.

---

## 2. Instalar el sistema en el NVMe

1. Conecta el NVMe (en su carcasa USB) a tu ordenador.
2. Descarga e instala **Raspberry Pi Imager** desde raspberrypi.com.
3. En Imager:
   - **Dispositivo:** Raspberry Pi 4
   - **Sistema operativo:** *Raspberry Pi OS Lite (64-bit)* — en "Raspberry Pi OS (other)". Sin escritorio, para dejar toda la RAM al servidor.
   - **Almacenamiento:** tu NVMe.
4. Pulsa el engranaje / "Editar ajustes" antes de grabar y configura:
   - **Hostname:** por ejemplo `minecraft`
   - **Activar SSH** (con contraseña)
   - **Usuario y contraseña** (apúntalos)
   - **WiFi** solo si no vas a usar cable.
5. Graba. Al terminar, conecta el NVMe a un **puerto USB 3.0 (azul)** de la Pi, **sin tarjeta SD puesta**, y enciende.
   - La Pi 4 arranca por USB automáticamente si no hay SD. Si no arrancara, mira *Solución de problemas → arranque USB*.

Busca la IP de la Pi en tu router (o prueba `ping minecraft.local`). Conéctate por SSH desde tu ordenador:

```
ssh usuario@LA_IP_DE_LA_PI
```

---

## 3. Copiar esta carpeta a la Pi

Desde tu ordenador (misma carpeta donde está este README), súbela por SSH:

```
scp -r minecraft-pi-server usuario@LA_IP_DE_LA_PI:~/
```

(O cópiala con un pendrive.) Luego, ya dentro de la Pi por SSH:

```
cd ~/minecraft-pi-server
sed -i 's/\r$//' *.sh          # por si se colaron saltos de línea de Windows
```

---

## 4. Instalar el servidor (un solo comando)

```
sudo bash setup.sh
```

Esto instala Java 17, Forge 1.20.1, aplica la configuración, descarga todos los mods con sus dependencias y crea el servicio. Tarda unos minutos (según tu conexión).

---

## 5. Arrancar y administrar

```
sudo systemctl start minecraft      # arrancar (la 1ª vez genera el mundo: paciencia)
sudo systemctl stop minecraft       # parar (guarda antes de apagar)
systemctl status minecraft          # ver estado
```

El servidor arranca solo al encender la Pi (está habilitado).

**Ver la consola** para escribir comandos:

```
sudo bash attach-console.sh
```

Para **salir de la consola sin apagar** el servidor: pulsa `Ctrl-A` y luego `D`.

Dentro de la consola, escribe:

```
op TU_NOMBRE_DE_MINECRAFT           # te hace administrador
whitelist add NOMBRE_DE_UN_AMIGO    # permite entrar a ese amigo
whitelist add OTRO_AMIGO
```

Repite `whitelist add` para cada amigo (la whitelist está activada por seguridad).

---

## 6. Pregenerar el mundo (muy recomendado)

Generar chunks al explorar es lo que más lag causa en una Pi. Pregenéralos **una vez**, con nadie conectado, desde la consola (`attach-console.sh`):

```
chunky radius 2000
chunky start
```

Deja que termine (puede tardar bastante; ve el progreso en la consola). Cuando acabe:

```
chunky quit
```

Un radio de 2000 bloques suele bastar para un grupo pequeño. Sal de la consola con `Ctrl-A`, `D`.

---

## 7. Que tus amigos se conecten

### Opción A — Playit.gg (la más fácil, funciona aunque tu router no deje abrir puertos)

En la Pi:

```
curl -SsL https://playit-cloud.github.io/ppa/key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/playit.gpg
echo "deb [signed-by=/usr/share/keyrings/playit.gpg] https://playit-cloud.github.io/ppa/data ./" | sudo tee /etc/apt/sources.list.d/playit-cloud.list
sudo apt update && sudo apt install -y playit
playit
```

Al ejecutar `playit` te mostrará un enlace: ábrelo en el navegador, crea una cuenta gratuita y **añade un túnel de tipo Minecraft Java** apuntando a `127.0.0.1:25565`. Te dará una dirección tipo `algo.joinmc.link` que compartes con tus amigos. Ellos la ponen en *Multijugador → Añadir servidor*. Añade ~10-50 ms de ping.

### Opción B — Tailscale (red privada, sin ping extra, para un grupo fijo de confianza)

En la Pi:

```
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Tus amigos instalan Tailscale, se unen a tu red (los invitas desde el panel de Tailscale) y se conectan a `IP_DE_TAILSCALE_DE_LA_PI:25565`.

### Opción C — Misma casa (LAN)

Se conectan directamente a `IP_LOCAL_DE_LA_PI:25565`.

---

## 8. Los mods incluidos

Se descargan solos con `download_mods.py`. Para **añadir o quitar**, edita la lista `MODS` de ese archivo (usa el "slug" de la URL de Modrinth) y ejecuta:

```
sudo -u minecraft python3 ~/minecraft-pi-server/download_mods.py /opt/minecraft/mods
sudo systemctl restart minecraft
```

Incluidos:

- **Contenido:** Create, Tinkers' Construct, SecurityCraft
- **Decoración:** Supplementaries, Macaw's Furniture
- **Rendimiento/memoria:** FerriteCore, ModernFix, Memory Leak Fix
- **Utilidades:** Chunky (pregenerar), spark (medir rendimiento)

> Importante: tus amigos necesitan **los mismos mods de contenido** en su cliente (Create, Tinkers, SecurityCraft, Supplementaries, Macaw's, y las dependencias). Lo más cómodo es que instales el pack en un lanzador tipo **Prism Launcher** o **CurseForge** y se lo pases. Los mods de rendimiento/servidor no hace falta que los tengan.

---

## 9. Mantenimiento

**Copias de seguridad** (guarda las últimas 7):

```
sudo bash backup.sh
```

Automatizar cada día a las 5:00 — ejecuta `sudo crontab -e` y añade:

```
0 5 * * * /bin/bash /home/TU_USUARIO/minecraft-pi-server/backup.sh >> /var/log/mc-backup.log 2>&1
```

**Ver registros del servidor:**

```
journalctl -u minecraft -f
```

---

## 10. Solución de problemas

- **`bad interpreter` / errores raros al ejecutar un `.sh`:** son saltos de línea de Windows. Ejecuta `sudo apt install -y dos2unix && dos2unix ~/minecraft-pi-server/*.sh`.
- **El servidor se cierra solo / falta memoria (OutOfMemory):** baja la RAM. Edita `/opt/minecraft/user_jvm_args.txt` y cambia `-Xms2800M`/`-Xmx2800M` a `2560M`. Reinicia. Si sigue, reduce la lista de mods de decoración.
- **Va con tirones (TPS bajo):** baja `view-distance` a 5 y `simulation-distance` a 4 en `/opt/minecraft/server.properties`; asegúrate de haber pregenerado con Chunky; y pide que no monten demasiadas máquinas de Create enormes a la vez. Usa `spark tps` en la consola para medir.
- **La Pi se calienta / rendimiento baja con el tiempo:** es *thermal throttling*. Mejora la refrigeración.
- **No arranca por USB (NVMe):** actualiza el bootloader — arranca una vez desde una tarjeta SD con Raspberry Pi OS y ejecuta `sudo rpi-eeprom-update -a`, luego apaga, quita la SD y prueba el NVMe. Alternativa: deja el arranque en SD y usa el NVMe solo para `/opt/minecraft`.
- **Algún mod no se descargó:** el script lo indica al final. Búscalo en modrinth.com (versión 1.20.1, Forge) y copia el `.jar` en `/opt/minecraft/mods`.
- **Un amigo no puede entrar:** ¿lo añadiste con `whitelist add`? ¿Tiene los mismos mods de contenido y la misma versión (Forge 1.20.1)?

---

## Resumen rápido

```
# En la Pi, dentro de ~/minecraft-pi-server:
sudo bash setup.sh                 # instalar todo
sudo systemctl start minecraft     # arrancar
sudo bash attach-console.sh        # consola -> op TU_NOMBRE / whitelist add AMIGO
                                   #            chunky radius 2000 / chunky start
# salir de consola: Ctrl-A, luego D
```

¡A disfrutar!
