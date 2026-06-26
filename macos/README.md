# Wake Up, Neo — macOS

En macOS 26 el subsistema de `.saver` nativos está roto para render custom, así que
esto **no es un `.saver`**. Es una app con un **helper anidado**, cada uno con su propio
bundle id para que no choquen en LaunchServices:

- **`WakeUpNeo` — app de config** (`com.jere.wakeupneo`). Aparece en el listado de
  Aplicaciones / Launchpad como **Wake Up, Neo**. La abrís, sale la ventana de ajustes
  (activar, tiempo de espera, vista previa), configurás y la cerrás. Tiene ícono en el
  Dock **solo mientras está abierta**; al cerrar la ventana, la app termina.
- **`WakeUpNeoAgent` — agente headless** (`com.jere.wakeupneo.agent`, en
  `Contents/Library/Helpers/WakeUpNeoAgent.app`). Corre en segundo plano vía un
  LaunchAgent, **sin Dock**. Detecta inactividad y muestra el efecto a pantalla completa
  en todos los monitores; se va al primer movimiento. Este es el "screensaver real".

La app de config y el agente comparten ajustes en el dominio `com.jere.wakeupneo.prefs`
(UserDefaults), así que lo que cambiás en la ventana lo toma el agente en vivo.

> **Elementos de inicio:** al instalar, macOS puede mostrar un aviso de "actividad en
> segundo plano". Es normal: el agente queda listado en **Ajustes del Sistema › General ›
> Elementos de inicio y extensiones**. Si alguna vez no arranca, verificá que esté
> habilitado ahí.

## Requisitos

Solo las **Command Line Tools** de Xcode (`xcode-select --install`). No hace falta Xcode.

## Compilar e instalar

```bash
cd macos
./build.sh --install
```

Eso compila el bundle, lo copia a `~/Applications/WakeUpNeo.app`, escribe el LaunchAgent
(`~/Library/LaunchAgents/com.jere.wakeupneo.agent.plist`) y lo deja corriendo. Si venías
de la versión vieja ("Matrix"), migra tu tiempo de espera y limpia lo anterior.

Para solo compilar sin instalar:

```bash
./build.sh            # queda en macos/build/WakeUpNeo.app
```

## Usar

Abrí **Wake Up, Neo** desde Aplicaciones (o `open "~/Applications/WakeUpNeo.app"`):

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

El dibujo está en [`NeoRenderer.swift`](NeoRenderer.swift). Después de editar:

```bash
./build.sh --install
```

## Línea de comandos (opcional)

El binario del agente acepta flags útiles para probar:

```bash
APP="$HOME/Applications/WakeUpNeo.app/Contents/Library/Helpers/WakeUpNeoAgent.app/Contents/MacOS/WakeUpNeoAgent"
"$APP" --preview          # muestra el efecto y sale al primer input
"$APP" --now              # lo muestra y sigue como agente
"$APP" --idle 60          # fuerza 60 s de inactividad (ignora los ajustes)
```

## Desinstalar

```bash
launchctl bootout "gui/$(id -u)/com.jere.wakeupneo.agent" 2>/dev/null
launchctl disable "gui/$(id -u)/com.jere.wakeupneo.agent" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/com.jere.wakeupneo.agent.plist"
rm -rf "$HOME/Applications/WakeUpNeo.app"
defaults delete com.jere.wakeupneo.prefs 2>/dev/null
```

## Archivos

| Archivo | Qué es |
|---|---|
| `NeoApp.swift` | App de config visible (ventana de ajustes, maneja el LaunchAgent). |
| `NeoAgent.swift` | Agente headless (detecta inactividad, dibuja a pantalla completa). |
| `NeoRenderer.swift` | El dibujo del efecto, compartido por ambos. |
| `build.sh` | Compila ambos binarios en un bundle y opcionalmente instala. |
