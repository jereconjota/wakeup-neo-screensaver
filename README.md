# Wake Up, Neo

Un protector de pantalla estilo terminal: fondo negro con el clásico
**`Wake up, Neo...`** en verde fosforescente, glow CRT, viñeta y scanlines.
Aparece tras unos segundos de inactividad y se va al primer movimiento.

Funciona en **macOS** (app nativa con ventana de configuración) y en **Linux/X11**
(abre `index.html` en Chrome a pantalla completa).

**▶ Demo en vivo:** https://jereconjota.github.io/wakeup-neo-screensaver/

```
 Wake up, Neo... █
```

## macOS

En macOS 26 los `.saver` nativos no renderizan render custom, así que esto es una
**app** con una ventana de ajustes visible en Aplicaciones + un agente headless que
hace el trabajo en segundo plano.

```bash
cd macos
./build.sh --install
open "$HOME/Applications/WakeUpNeo.app"
```

Desde la ventana podés **activar/desactivar**, fijar el **tiempo de espera** y ver una
**vista previa**. Detalles completos en [`macos/README.md`](macos/README.md).

> Solo necesitás las Command Line Tools (`xcode-select --install`), no Xcode.

## Linux (X11 / GNOME)

Usa `xprintidle` para detectar inactividad y abre [`index.html`](index.html) en
Chrome/Chromium en modo kiosko.

```bash
cd linux
./install.sh           # autostart al login; default 120 s de inactividad
./install.sh 300       # 5 minutos
```

Detalles, cómo frenarlo y cómo sacar el autostart: [`linux/install.sh`](linux/install.sh).

> Para que no compita con GNOME: Energía → "Apagar pantalla cuando esté inactivo" →
> Nunca, y desactivá el bloqueo automático.

## El efecto (`index.html`)

[`index.html`](index.html) es la versión web del efecto, autocontenida (la fuente
Courier Prime va embebida en base64, sin depender de internet). La usa el "screensaver"
de Linux y también se puede abrir directo en cualquier navegador.

## Estructura

```
index.html                  efecto en web (usado por Linux y standalone)
courierprime-latin.woff2     fuente del efecto web
cp.css                       estilos de la fuente
macos/                       app nativa de macOS (config + agente headless)
  NeoApp.swift               ventana de configuración (visible)
  NeoAgent.swift             agente headless (inactividad + fullscreen)
  NeoRenderer.swift          dibujo del efecto, compartido
  build.sh                   compila e instala
linux/                       "screensaver" para Linux/X11
  install.sh
  wakeup-neo.sh
```

## Licencia

MIT — ver [`LICENSE`](LICENSE).
