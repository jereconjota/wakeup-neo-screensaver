import AppKit

// App de configuración VISIBLE (aparece en Aplicaciones y en el Dock).
// Abre una ventana con los ajustes del protector de pantalla Matrix:
//   - Activar / desactivar (instala o quita el LaunchAgent que corre el agente)
//   - Tiempo de espera (inactividad antes de activarse)
//   - Vista previa
// El agente headless real es el binario hermano "MatrixAgent" dentro del bundle.

let kSuite = "com.jere.matrix.prefs"   // distinto del bundle id (com.jere.matrix)
let kIdleKey = "idleSeconds"
let kDefaultIdle = 120.0
let kAgentLabel = "com.jere.matrixapp"

// MARK: - Manejo del LaunchAgent

enum LaunchAgent {
    static let label = kAgentLabel
    static var plistPath: String {
        (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }
    // El agente vive en su propio bundle anidado (otro bundle id), para que no
    // colisione con esta app en LaunchServices.
    static var agentBinary: String {
        (Bundle.main.bundlePath as NSString)
            .appendingPathComponent("Contents/Library/Helpers/MatrixAgent.app/Contents/MacOS/MatrixAgent")
    }
    static var domainTarget: String { "gui/\(getuid())" }
    static var serviceTarget: String { "gui/\(getuid())/\(label)" }

    @discardableResult
    static func launchctl(_ argv: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = argv
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        do { try p.run() } catch { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }

    static func writePlist() {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [agentBinary],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Interactive",
        ]
        let dir = (plistPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? data.write(to: URL(fileURLWithPath: plistPath))
        }
    }

    static var isLoaded: Bool {
        launchctl(["print", serviceTarget]) == 0
    }

    static func enable() {
        writePlist()
        launchctl(["bootout", serviceTarget])            // por si quedó cargado
        launchctl(["enable", serviceTarget])             // por si estaba deshabilitado
        launchctl(["bootstrap", domainTarget, plistPath])
        launchctl(["kickstart", "-k", serviceTarget])
    }

    static func disable() {
        launchctl(["bootout", serviceTarget])
        launchctl(["disable", serviceTarget])            // persistente: no arranca ni al login
    }
}

// MARK: - Ventana de ajustes

final class SettingsViewController: NSViewController {
    private let defaults = UserDefaults(suiteName: kSuite)
    private let enableSwitch = NSSwitch()
    private let statusLabel = NSTextField(labelWithString: "")
    private let idleSlider = NSSlider()
    private let idleValueLabel = NSTextField(labelWithString: "")
    private var previewProcess: Process?

    private var idleSeconds: Double {
        get {
            let v = defaults?.double(forKey: kIdleKey) ?? 0
            return v > 0 ? v : kDefaultIdle
        }
        set {
            defaults?.set(newValue, forKey: kIdleKey)
            defaults?.synchronize()
        }
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        refreshState()
    }

    private func buildUI() {
        let title = NSTextField(labelWithString: "Matrix Screensaver")
        title.font = .systemFont(ofSize: 24, weight: .bold)

        let subtitle = NSTextField(labelWithString: "Efecto terminal “Wake up, Neo…” a pantalla completa tras inactividad.")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        // Activar / desactivar
        let enableTitle = NSTextField(labelWithString: "Activar protector")
        enableTitle.font = .systemFont(ofSize: 14, weight: .semibold)
        enableSwitch.target = self
        enableSwitch.action = #selector(toggleEnabled(_:))
        let enableRow = NSStackView(views: [enableTitle, NSView(), enableSwitch])
        enableRow.orientation = .horizontal
        enableRow.distribution = .fill

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor

        // Tiempo de espera
        let idleTitle = NSTextField(labelWithString: "Tiempo de espera")
        idleTitle.font = .systemFont(ofSize: 14, weight: .semibold)
        idleSlider.minValue = 10
        idleSlider.maxValue = 600
        idleSlider.target = self
        idleSlider.action = #selector(idleChanged(_:))
        idleSlider.doubleValue = idleSeconds
        idleValueLabel.alignment = .right
        idleValueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        idleValueLabel.setContentHuggingPriority(.required, for: .horizontal)
        let idleRow = NSStackView(views: [idleSlider, idleValueLabel])
        idleRow.orientation = .horizontal
        idleSlider.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Vista previa
        let previewButton = NSButton(title: "Vista previa", target: self, action: #selector(preview(_:)))
        previewButton.bezelStyle = .rounded
        let previewRow = NSStackView(views: [previewButton, NSView()])
        previewRow.orientation = .horizontal

        // Nota
        let note = NSTextField(wrappingLabelWithString: "Consejo: en Ajustes del Sistema › Pantalla bloqueada, poné “Iniciar protector de pantalla cuando esté inactivo” en Nunca, para que no compita con el de macOS.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .tertiaryLabelColor

        let sep1 = NSBox(); sep1.boxType = .separator
        let sep2 = NSBox(); sep2.boxType = .separator

        let stack = NSStackView(views: [
            title, subtitle, sep1,
            enableRow, statusLabel, sep2,
            idleTitle, idleRow,
            previewRow,
            NSView(),
            note,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24),
        ])
        // Que las filas ocupen todo el ancho
        for row in [enableRow, idleRow, previewRow] {
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        subtitle.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        note.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        updateIdleLabel()
    }

    private func refreshState() {
        let on = LaunchAgent.isLoaded
        enableSwitch.state = on ? .on : .off
        statusLabel.stringValue = on ? "● Activo — corre en segundo plano y al iniciar sesión."
                                     : "○ Inactivo — el protector no se mostrará."
        statusLabel.textColor = on ? .systemGreen : .secondaryLabelColor
    }

    @objc private func toggleEnabled(_ sender: NSSwitch) {
        if sender.state == .on {
            LaunchAgent.enable()
        } else {
            LaunchAgent.disable()
        }
        refreshState()
    }

    @objc private func idleChanged(_ sender: NSSlider) {
        let snapped = (sender.doubleValue / 5).rounded() * 5   // pasos de 5s
        sender.doubleValue = snapped
        idleSeconds = snapped
        updateIdleLabel()
    }

    private func updateIdleLabel() {
        let total = Int(idleSeconds)
        let m = total / 60, s = total % 60
        let text: String
        if m == 0 { text = "\(s) s" }
        else if s == 0 { text = "\(m) min" }
        else { text = "\(m) min \(s) s" }
        idleValueLabel.stringValue = text
    }

    @objc private func preview(_ sender: NSButton) {
        previewProcess?.terminate()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: LaunchAgent.agentBinary)
        p.arguments = ["--preview"]
        try? p.run()
        previewProcess = p
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ note: Notification) {
        let vc = SettingsViewController()
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Matrix Screensaver"
        window.contentViewController = vc
        window.center()
        showWindow()
    }

    // App accessory (sin Dock): hay que forzar la ventana al frente sobre la app activa.
    private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }

    // Si la abren de nuevo desde Aplicaciones estando viva, volver a mostrar la ventana.
    func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showWindow()
        return true
    }
}

@main
enum MatrixAppMain {
    static let delegate = AppDelegate()   // se mantiene viva toda la ejecución
    static func main() {
        let app = NSApplication.shared
        // .regular: la ventana de ajustes se trae al frente de forma confiable y hay
        // ícono en el Dock SOLO mientras está abierta (al cerrarla, la app termina).
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.run()
    }
}
