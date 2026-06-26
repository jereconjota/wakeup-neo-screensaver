#!/usr/bin/env bash
# Instala el "screensaver" Matrix en Linux/X11 (Ubuntu 24.04 + GNOME):
# copia los archivos, instala xprintidle, deja autostart al login y lo arranca.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IDLE="${1:-120}"
APPDIR="$HOME/.local/share/matrix-screensaver"
AUTOSTART="$HOME/.config/autostart/matrix-screensaver.desktop"

if ! command -v xprintidle >/dev/null 2>&1; then
    echo "==> Instalando xprintidle (pide sudo)"
    sudo apt-get update && sudo apt-get install -y xprintidle
fi

echo "==> Copiando archivos a $APPDIR"
mkdir -p "$APPDIR"
cp "$HERE/matrix-screensaver.sh" "$APPDIR/"
cp "$HERE/../matrix.html" "$APPDIR/matrix.html"
chmod +x "$APPDIR/matrix-screensaver.sh"

echo "==> Creando autostart en $AUTOSTART"
mkdir -p "$(dirname "$AUTOSTART")"
cat > "$AUTOSTART" <<DESK
[Desktop Entry]
Type=Application
Name=Matrix Screensaver
Comment=Muestra matrix.html a pantalla completa tras inactividad
Exec=$APPDIR/matrix-screensaver.sh $IDLE
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESK

echo "==> Arrancando ahora"
pkill -f "matrix-screensaver.sh" 2>/dev/null || true
nohup "$APPDIR/matrix-screensaver.sh" "$IDLE" >/dev/null 2>&1 &

echo ""
echo "✅ Listo. Se activa tras ${IDLE}s de inactividad."
echo ""
echo "   IMPORTANTE para que no compita con GNOME:"
echo "   Configuración › Energía › 'Apagar pantalla cuando esté inactivo' -> Nunca"
echo "   Configuración › Privacidad › Bloqueo de pantalla -> desactivar bloqueo automático"
echo ""
echo "   Cambiar el tiempo:  $HERE/install.sh 300   (5 min)"
echo "   Frenar:             pkill -f matrix-screensaver.sh"
echo "   Sacar autostart:    rm '$AUTOSTART'"
