#!/bin/bash
# Arma un .dmg de "Wake Up, Neo" con la clásica ventana de arrastrar a Aplicaciones.
# Requiere haber compilado antes (./build.sh). Resultado: build/WakeUpNeo.dmg
set -euo pipefail
cd "$(dirname "$0")"

APP="build/WakeUpNeo.app"
DMG="build/WakeUpNeo.dmg"
VOL="Wake Up, Neo"

if [ ! -d "$APP" ]; then
    echo "❌ No existe $APP. Compilá primero: ./build.sh"
    exit 1
fi

STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # para arrastrar e instalar

echo "==> Creando $DMG"
rm -f "$DMG"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo ""
echo "✅ DMG: $DMG"
echo "   Tamaño: $(du -h "$DMG" | cut -f1)"
