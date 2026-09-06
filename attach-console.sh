#!/usr/bin/env bash
#
# attach-console.sh - Abre la consola del servidor para escribir comandos
# (op, whitelist, chunky, etc.).
#
# Uso:   sudo bash attach-console.sh
# Para SALIR de la consola sin apagar el servidor: pulsa Ctrl-A y luego D.
#
exec sudo -u minecraft screen -r minecraft
