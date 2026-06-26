# Matrix Screensaver — macOS

En macOS 26 el subsistema de `.saver` nativos está roto para render custom, así que
esto **no es un `.saver`**. Es una **app** con dos partes dentro de un mismo bundle:

- **`Matrix` (app de config, visible)** — aparece en Aplicaciones y el Dock. Abre una
  ventana donde activás/desactivás el protector, ajustás el tiempo de espera y probás
  la vista previa.
- **`MatrixAgent` (agente headless)** — corre en segundo plano vía un LaunchAgent.
  Detecta inactividad y muestra el efecto a pantalla completa en todos los monitores;
  se va al primer movimiento.

La app de config y el agente comparten ajustes en el dominio `com.jere.matrix.prefs`
(UserDefaults), así que lo que cambiás en la ventana lo toma el agente en vivo.

## Requisitos

Solo las **Command Line Tools** de Xcode (`xcode-select --install`). No hace falta Xcode.

## Compilar e instalar

```bash
cd macos
./build.sh --install
```

Eso compila el bundle, lo copia a `~/Applications/Matrix Screensaver.app`, escribe el
LaunchAgent (`~/Library/LaunchAgents/com.jere.matrixapp.plist`) y lo deja corriendo.
Si venías de una versión vieja, migra tu tiempo de espera y limpia el bundle anterior.

Para solo compilar sin instalar:

```bash
./build.sh            # queda en macos/build/Matrix Screensaver.app
```

## Usar

Abrí **Matrix Screensaver** desde Aplicaciones (o `open "~/Applications/Matrix Screensaver.app"`):

| Control | Qué hace |
|---|---|
| **Activar protector** | Carga/descarga el LaunchAgent (arranca al iniciar sesión y se mantiene vivo). |
| **Tiempo de espera** | Inactividad antes de que aparezca el efecto (10 s – 10 min). |
| **Vista previa** | Muestra el efecto ya; salís con cualquier tecla o moviendo el mouse. |

## Recordatorio

Para que no compita con el protector nativo de macOS:
**Ajustes del Sistema › Pantalla bloqueada › "Iniciar protector de pantalla cuando esté
inactivo" → Nunca.**

## Cambiar el look del efecto

El dibujo está en [`MatrixRenderer.swift`](MatrixRenderer.swift). Después de editar:

```bash
./build.sh --install
```

## Línea de comandos (opcional)

El binario del agente acepta flags útiles para probar:

```bash
APP="$HOME/Applications/Matrix Screensaver.app/Contents/MacOS/MatrixAgent"
"$APP" --preview          # muestra el efecto y sale al primer input
"$APP" --now              # lo muestra y sigue como agente
"$APP" --idle 60          # fuerza 60 s de inactividad (ignora los ajustes)
```

## Desinstalar

```bash
launchctl bootout "gui/$(id -u)/com.jere.matrixapp" 2>/dev/null
launchctl disable "gui/$(id -u)/com.jere.matrixapp" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/com.jere.matrixapp.plist"
rm -rf "$HOME/Applications/Matrix Screensaver.app"
defaults delete com.jere.matrix.prefs 2>/dev/null
```

## Archivos

| Archivo | Qué es |
|---|---|
| `MatrixApp.swift` | App de config visible (ventana de ajustes, maneja el LaunchAgent). |
| `MatrixAgent.swift` | Agente headless (detecta inactividad, dibuja a pantalla completa). |
| `MatrixRenderer.swift` | El dibujo del efecto, compartido por ambos. |
| `build.sh` | Compila ambos binarios en un bundle y opcionalmente instala. |
