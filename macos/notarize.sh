#!/bin/bash
# Firma con Developer ID + notariza + grapa (staple) la app, para distribuirla a
# otras Macs SIN el aviso de Gatekeeper. Requiere una cuenta de Apple Developer
# Program (de pago) y, por única vez, haber guardado las credenciales (ver abajo).
#
# Setup por única vez (necesitás tu Apple ID, un app-specific password creado en
# https://account.apple.com/account/manage, y tu Team ID de developer.apple.com):
#
#   xcrun notarytool store-credentials wakeupneo \
#       --apple-id "TU_APPLE_ID@mail.com" \
#       --team-id "TUTEAMID" \
#       --password "xxxx-xxxx-xxxx-xxxx"        # app-specific password
#
# Y necesitás un certificado "Developer ID Application" instalado en el Keychain
# (se crea en developer.apple.com › Certificates). Mirá su nombre exacto con:
#   security find-identity -v -p codesigning
#
# Uso:
#   DEV_ID="Developer ID Application: Tu Nombre (TUTEAMID)" ./notarize.sh
#   # opcionales:
#   #   APP=/ruta/a/WakeUpNeo.app   (default: build/WakeUpNeo.app)
#   #   NOTARY_PROFILE=wakeupneo    (default: wakeupneo)
set -euo pipefail
cd "$(dirname "$0")"

APP="${APP:-build/WakeUpNeo.app}"
PROFILE="${NOTARY_PROFILE:-wakeupneo}"
HELPER="$APP/Contents/Library/Helpers/WakeUpNeoAgent.app"
: "${DEV_ID:?Definí DEV_ID con tu identidad 'Developer ID Application: ... (TEAMID)'}"

if [ ! -d "$APP" ]; then
    echo "❌ No existe $APP. Compilá primero: ./build.sh"
    exit 1
fi

echo "==> Firmando con Developer ID + hardened runtime (helper primero)"
codesign --force --options runtime --timestamp --sign "$DEV_ID" "$HELPER"
codesign --force --options runtime --timestamp --sign "$DEV_ID" "$APP"

echo "==> Empaquetando para notarizar"
ZIP="$(mktemp -d)/WakeUpNeo.zip"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Enviando a notarizar (espera el resultado)"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

echo "==> Grapando el ticket a la app"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo ""
echo "✅ Notarizada y grapada: $APP"
echo "   Ya se puede distribuir (zip/dmg) sin el aviso de Gatekeeper."
