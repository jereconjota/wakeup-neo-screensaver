#!/bin/bash
# Compila la app "Matrix Screensaver" para macOS (sin Xcode, solo Command Line
# Tools). El bundle contiene dos binarios:
#   - Matrix       -> app de configuración VISIBLE (ventana de ajustes)
#   - MatrixAgent  -> agente headless que muestra el efecto tras inactividad
#
# Uso:
#   ./build.sh             # solo compila en build/Matrix.app
#   ./build.sh --install   # compila, copia a ~/Applications y recarga el agente
set -euo pipefail
cd "$(dirname "$0")"

NAME="Matrix"
APP="Matrix Screensaver.app"
BUILD="build"
APPDST="$HOME/Applications/$APP"
LABEL="com.jere.matrixapp"

echo "==> Limpiando"
rm -rf "$BUILD"
mkdir -p "$BUILD/$APP/Contents/MacOS"

echo "==> Info.plist"
cat > "$BUILD/$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$NAME</string>
    <key>CFBundleIdentifier</key><string>com.jere.matrix</string>
    <key>CFBundleName</key><string>Matrix Screensaver</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "==> Compilando app de config (Matrix)"
swiftc MatrixApp.swift MatrixRenderer.swift \
    -o "$BUILD/$APP/Contents/MacOS/Matrix" \
    -framework AppKit \
    -target arm64-apple-macosx12.0

echo "==> Compilando agente headless (MatrixAgent)"
swiftc MatrixAgent.swift MatrixRenderer.swift \
    -o "$BUILD/$APP/Contents/MacOS/MatrixAgent" \
    -framework AppKit -framework IOKit \
    -target arm64-apple-macosx12.0

echo "==> Firmando ad-hoc"
codesign --force --deep --sign - "$BUILD/$APP"

echo ""
echo "✅ App: $BUILD/$APP"

if [ "${1:-}" = "--install" ]; then
    PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
    AGENTBIN="$APPDST/Contents/MacOS/MatrixAgent"

    echo "==> Instalando en ~/Applications"
    mkdir -p "$HOME/Applications"
    rm -rf "$APPDST"
    cp -R "$BUILD/$APP" "$APPDST"

    # Migrar el tiempo de espera: si ya está en los ajustes nuevos se respeta; si no,
    # se intenta recuperar de un dominio viejo o del plist viejo (--idle N); si no, 120.
    CURIDLE="$(defaults read com.jere.matrix.prefs idleSeconds 2>/dev/null || true)"
    if [ -z "$CURIDLE" ]; then
        SEED="$(defaults read com.jere.matrix idleSeconds 2>/dev/null \
                || /usr/libexec/PlistBuddy -c 'Print :ProgramArguments:2' "$PLIST" 2>/dev/null \
                || echo 120)"
        defaults write com.jere.matrix.prefs idleSeconds -float "$SEED"
        echo "==> Tiempo de espera inicial: ${SEED}s"
    fi

    # Si había un agente cargado (versión vieja), descargarlo.
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    # Limpiar el bundle viejo si quedó.
    rm -rf "$HOME/Applications/Matrix.app"

    echo "==> Escribiendo LaunchAgent y cargándolo"
    cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array><string>$AGENTBIN</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLISTEOF
    launchctl enable "gui/$(id -u)/$LABEL" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST"
    launchctl kickstart -k "gui/$(id -u)/$LABEL" || true

    echo ""
    echo "✅ Instalado y corriendo: $APPDST"
    echo "   Abrí la config:  open '$APPDST'"
else
    echo "   Probar la config:  open '$BUILD/$APP'"
    echo "   Instalar:          ./build.sh --install"
fi
