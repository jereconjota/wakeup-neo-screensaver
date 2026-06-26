#!/usr/bin/env bash
# "Screensaver" Wake Up, Neo para Linux/X11 (probado con Ubuntu 24.04 + GNOME + Chrome).
# Cuando el sistema queda inactivo IDLE segundos, abre index.html en Chrome a
# pantalla completa (kiosko). Al primer movimiento del mouse/teclado, lo cierra.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HTML="${NEO_HTML:-$HERE/index.html}"
IDLE_SECS="${1:-120}"
IDLE_MS=$(( IDLE_SECS * 1000 ))
POLL=0.5
PROFILE="/tmp/wakeup-neo-chrome-profile"
CHROME="$(command -v google-chrome || command -v google-chrome-stable || command -v chromium || command -v chromium-browser || true)"

if ! command -v xprintidle >/dev/null 2>&1; then
    echo "Falta xprintidle. Instalá:  sudo apt install -y xprintidle" >&2
    exit 1
fi
if [ -z "$CHROME" ]; then echo "No encontré Chrome/Chromium" >&2; exit 1; fi
if [ ! -f "$HTML" ]; then echo "No existe el HTML: $HTML" >&2; exit 1; fi

CHROME_PID=""

start_saver() {
    [ -n "$CHROME_PID" ] && return 0
    "$CHROME" \
        --kiosk "file://$HTML" \
        --user-data-dir="$PROFILE" \
        --incognito --no-first-run --no-default-browser-check \
        --disable-infobars --noerrdialogs --disable-session-crashed-bubble \
        --disable-features=Translate \
        >/dev/null 2>&1 &
    CHROME_PID=$!
}

stop_saver() {
    [ -z "$CHROME_PID" ] && return 0
    kill "$CHROME_PID" >/dev/null 2>&1 || true
    wait "$CHROME_PID" 2>/dev/null || true
    CHROME_PID=""
}

trap 'stop_saver' EXIT INT TERM

while true; do
    idle="$(xprintidle 2>/dev/null || echo 0)"
    if [ -n "$CHROME_PID" ]; then
        # Si Chrome se cerró por su cuenta, resetear el estado.
        if ! kill -0 "$CHROME_PID" 2>/dev/null; then CHROME_PID=""; fi
        # Hubo actividad -> cerrar el screensaver.
        if [ "$idle" -lt "$IDLE_MS" ]; then stop_saver; fi
    else
        if [ "$idle" -ge "$IDLE_MS" ]; then start_saver; fi
    fi
    sleep "$POLL"
done
