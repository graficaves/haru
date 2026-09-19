#!/bin/bash
# Instala Haru en ~/Applications (así Spotlight la encuentra y el ítem de
# inicio de sesión apunta a un lugar fijo), cierra la instancia anterior y la abre.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Haru.app"
DESTINO="$HOME/Applications/Haru.app"

if [ ! -d "$APP" ]; then
  echo "❌ Haru no está compilada. Corré ./compilar.sh primero."
  exit 1
fi

pkill -x Haru 2>/dev/null || true
sleep 0.5
mkdir -p "$HOME/Applications"
rm -rf "$DESTINO"
cp -R "$APP" "$DESTINO"
open "$DESTINO"
echo "✅ Haru corriendo. Apretá ⌥⌘P o buscá la hojita en la barra de menú."
