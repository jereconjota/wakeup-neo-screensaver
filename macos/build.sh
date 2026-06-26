#!/bin/bash
# Compila la app "Wake Up, Neo" para macOS (sin Xcode, solo Command Line Tools).
# Genera UN bundle con un helper anidado, cada uno con su propio bundle id para
# que no colisionen en LaunchServices:
#
#   WakeUpNeo.app                                 (com.jere.wakeupneo)
#     Contents/MacOS/WakeUpNeo                    -> app de config (ventana de ajustes)
#     Contents/Library/Helpers/WakeUpNeoAgent.app (com.jere.wakeupneo.agent, LSUIElement)
#       Contents/MacOS/WakeUpNeoAgent             -> agente headless (efecto fullscreen)
#
# La app de config aparece en el listado de Aplicaciones / Launchpad y solo ocupa el
# Dock mientras está abierta. El agente corre en segundo plano (sin Dock) vía LaunchAgent.
#
# Uso:
#   ./build.sh             # solo compila en build/
#   ./build.sh --install   # compila, copia a ~/Applications y recarga el agente
set -euo pipefail
cd "$(dirname "$0")"

APP="WakeUpNeo.app"
BUILD="build"
APPDST="$HOME/Applications/$APP"
LABEL="com.jere.wakeupneo.agent"
HELPER_REL="Contents/Library/Helpers/WakeUpNeoAgent.app"

echo "==> Limpiando"
rm -rf "$BUILD"
mkdir -p "$BUILD/$APP/Contents/MacOS"
mkdir -p "$BUILD/$APP/Contents/Resources"
mkdir -p "$BUILD/$APP/$HELPER_REL/Contents/MacOS"

echo "==> Ícono"
cp AppIcon.icns "$BUILD/$APP/Contents/Resources/AppIcon.icns"

echo "==> Info.plist (app de config)"
cat > "$BUILD/$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>WakeUpNeo</string>
    <key>CFBundleIdentifier</key><string>com.jere.wakeupneo</string>
    <key>CFBundleName</key><string>Wake Up, Neo</string>
    <key>CFBundleDisplayName</key><string>Wake Up, Neo</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "==> Info.plist (agente helper)"
cat > "$BUILD/$APP/$HELPER_REL/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>WakeUpNeoAgent</string>
    <key>CFBundleIdentifier</key><string>com.jere.wakeupneo.agent</string>
    <key>CFBundleName</key><string>WakeUpNeoAgent</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "==> Compilando app de config (WakeUpNeo)"
swiftc NeoApp.swift NeoRenderer.swift \
    -o "$BUILD/$APP/Contents/MacOS/WakeUpNeo" \
    -framework AppKit \
    -target arm64-apple-macosx12.0

echo "==> Compilando agente headless (WakeUpNeoAgent)"
swiftc NeoAgent.swift NeoRenderer.swift \
    -o "$BUILD/$APP/$HELPER_REL/Contents/MacOS/WakeUpNeoAgent" \
    -framework AppKit -framework IOKit \
    -target arm64-apple-macosx12.0

echo "==> Firmando ad-hoc (helper primero, después el bundle externo)"
codesign --force --sign - "$BUILD/$APP/$HELPER_REL"
codesign --force --sign - "$BUILD/$APP"

echo ""
echo "✅ App: $BUILD/$APP"

if [ "${1:-}" = "--install" ]; then
    PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
    AGENTBIN="$APPDST/$HELPER_REL/Contents/MacOS/WakeUpNeoAgent"

    # --- Limpieza de instalaciones viejas (nombre anterior "Matrix") ---
    for OLD in com.jere.matrixapp; do
        launchctl bootout "gui/$(id -u)/$OLD" 2>/dev/null || true
        launchctl disable "gui/$(id -u)/$OLD" 2>/dev/null || true
        rm -f "$HOME/Library/LaunchAgents/$OLD.plist"
    done
    rm -rf "$HOME/Applications/Matrix Screensaver.app" "$HOME/Applications/Matrix.app"

    echo "==> Instalando en ~/Applications"
    mkdir -p "$HOME/Applications"
    rm -rf "$APPDST"
    cp -R "$BUILD/$APP" "$APPDST"

    # Migrar el tiempo de espera: si ya está en los ajustes nuevos se respeta; si no,
    # se recupera de un dominio viejo; si no hay nada, 120.
    CURIDLE="$(defaults read com.jere.wakeupneo.prefs idleSeconds 2>/dev/null || true)"
    if [ -z "$CURIDLE" ]; then
        SEED="$(defaults read com.jere.matrix.prefs idleSeconds 2>/dev/null \
                || defaults read com.jere.matrix idleSeconds 2>/dev/null \
                || echo 120)"
        defaults write com.jere.wakeupneo.prefs idleSeconds -float "$SEED"
        echo "==> Tiempo de espera inicial: ${SEED}s"
    fi

    # Por si había una versión previa con este mismo label, descargarla.
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true

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
