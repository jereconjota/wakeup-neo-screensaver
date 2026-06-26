import AppKit
import IOKit

// Agente headless: corre en segundo plano (lanzado por el LaunchAgent), detecta
// inactividad y muestra el efecto a pantalla completa en todos los monitores;
// se oculta al primer input. El tiempo de espera se lee en vivo de los ajustes
// compartidos (UserDefaults suite "com.jere.matrix.prefs"), que escribe la app de config.
//
// Flags:
//   --now            muestra el efecto ya y sigue como agente normal
//   --preview        muestra el efecto ya y termina al primer input (vista previa)
//   --idle SEGUNDOS  fuerza el tiempo de inactividad (ignora los ajustes)

let kSuite = "com.jere.matrix.prefs"   // distinto del bundle id (com.jere.matrix)
let kIdleKey = "idleSeconds"
let kDefaultIdle = 120.0

final class MatrixEffectView: NSView {
    var cursorOn = true { didSet { needsDisplay = true } }
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        MatrixRenderer.draw(in: bounds, cursorOn: cursorOn)
    }
}

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class Controller: NSObject, NSApplicationDelegate {
    private var windows: [OverlayWindow] = []
    private var views: [MatrixEffectView] = []
    private var pollTimer: Timer?
    private var blinkTimer: Timer?
    private var showing = false
    private var shownAt: CFTimeInterval = 0
    private let fixedIdle: Double?   // si viene por --idle, manda; si no, lee ajustes
    private let startNow: Bool
    private let previewMode: Bool    // vista previa: se muestra ya y sale al primer input
    private let defaults = UserDefaults(suiteName: kSuite)

    init(fixedIdle: Double?, startNow: Bool, previewMode: Bool) {
        self.fixedIdle = fixedIdle
        self.startNow = startNow
        self.previewMode = previewMode
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if startNow || previewMode { show() }
    }

    // Tiempo de inactividad efectivo: --idle si se pasó, si no el de los ajustes.
    private func idleThreshold() -> Double {
        if let f = fixedIdle { return f }
        defaults?.synchronize()
        let v = defaults?.double(forKey: kIdleKey) ?? 0
        return v > 0 ? v : kDefaultIdle
    }

    // Segundos de inactividad del sistema vía IOKit (sin permisos especiales).
    private func systemIdleSeconds() -> Double {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"), &iterator) == KERN_SUCCESS else {
            return 0
        }
        defer { IOObjectRelease(iterator) }
        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any],
              let ns = dict["HIDIdleTime"] as? NSNumber else {
            return 0
        }
        return ns.doubleValue / 1_000_000_000.0 // nanosegundos -> segundos
    }

    private func tick() {
        let idle = systemIdleSeconds()
        if showing {
            if CACurrentMediaTime() - shownAt > 1.5, idle < 1.0 {
                hide()
                if previewMode { NSApp.terminate(nil) }   // la vista previa es de un solo uso
            }
        } else if !previewMode, idle >= idleThreshold() {
            show()
        }
    }

    private func show() {
        guard !showing else { return }
        buildWindows()
        for w in windows { w.orderFrontRegardless() }
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.hide()
        showing = true
        shownAt = CACurrentMediaTime()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.views.forEach { $0.cursorOn.toggle() }
        }
    }

    private func hide() {
        guard showing else { return }
        blinkTimer?.invalidate(); blinkTimer = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll(); views.removeAll()
        NSCursor.unhide()
        showing = false
    }

    private func buildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll(); views.removeAll()
        for screen in NSScreen.screens {
            let w = OverlayWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            w.backgroundColor = .black
            w.isOpaque = true
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            let v = MatrixEffectView(frame: NSRect(origin: .zero, size: screen.frame.size))
            v.autoresizingMask = [.width, .height]
            w.contentView = v
            windows.append(w)
            views.append(v)
        }
    }
}

@main
enum MatrixAgentMain {
    static var controller: Controller!   // se mantiene vivo toda la ejecución

    static func main() {
        // --- argumentos ---
        var fixedIdle: Double? = nil
        var startNow = false
        var previewMode = false
        var args = CommandLine.arguments.dropFirst().makeIterator()
        while let a = args.next() {
            switch a {
            case "--now": startNow = true
            case "--preview": previewMode = true
            case "--idle": if let s = args.next(), let v = Double(s) { fixedIdle = v }
            default: break
            }
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        controller = Controller(fixedIdle: fixedIdle, startNow: startNow, previewMode: previewMode)
        app.delegate = controller
        app.run()
    }
}
