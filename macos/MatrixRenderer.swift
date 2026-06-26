import AppKit

// Dibujo del efecto (compartido por la app de config y el agente headless).
// Todo se pinta con AppKit sobre el NSGraphicsContext actual.
enum MatrixRenderer {
    static let text = "Wake up, Neo..."
    static let green = NSColor(srgbRed: 0.0, green: 1.0, blue: 65.0 / 255.0, alpha: 1.0)

    static func font(for bounds: NSRect) -> NSFont {
        let size = max(12.0, bounds.height * 0.018)
        return NSFont(name: "Courier", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    static func draw(in bounds: NSRect, cursorOn: Bool) {
        NSColor.black.setFill()
        bounds.fill()
        drawVignette(in: bounds)
        drawTerminal(in: bounds, cursorOn: cursorOn)
        drawScanlines(in: bounds)
    }

    private static func drawVignette(in bounds: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let colors = [
            NSColor(srgbRed: 0, green: 1, blue: 65 / 255, alpha: 0.07).cgColor,
            NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.0).cgColor,
            NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.6).cgColor,
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.4, 1.0]
        guard let grad = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = max(bounds.width, bounds.height) * 0.75
        ctx.drawRadialGradient(
            grad,
            startCenter: center, startRadius: 0,
            endCenter: center, endRadius: radius,
            options: [.drawsAfterEndLocation]
        )
    }

    private static func drawTerminal(in bounds: NSRect, cursorOn: Bool) {
        let f = font(for: bounds)
        // Padding del texto respecto a los bordes (un poco de aire).
        let padX = bounds.width * 0.035
        let padY = bounds.height * 0.05
        let size = (text as NSString).size(withAttributes: [.font: f])
        let x = padX
        let y = bounds.height - padY - size.height

        drawGlowingText(text, at: CGPoint(x: x, y: y), font: f)

        guard cursorOn else { return }
        let cw = f.pointSize * 0.6
        let ch = f.pointSize
        let gap = f.pointSize * 0.25
        let cursorRect = CGRect(x: x + size.width + gap, y: y, width: cw, height: ch)
        drawGlowingBlock(cursorRect)
    }

    private static func drawGlowingText(_ s: String, at p: CGPoint, font f: NSFont) {
        let passes: [(blur: CGFloat, alpha: CGFloat)] = [
            (f.pointSize * 2.4, 0.45),
            (f.pointSize * 0.9, 0.95),
        ]
        for pass in passes {
            let shadow = NSShadow()
            shadow.shadowColor = green.withAlphaComponent(pass.alpha)
            shadow.shadowBlurRadius = pass.blur
            shadow.shadowOffset = .zero
            let attrs: [NSAttributedString.Key: Any] = [
                .font: f,
                .foregroundColor: green,
                .shadow: shadow,
            ]
            NSAttributedString(string: s, attributes: attrs).draw(at: p)
        }
    }

    private static func drawGlowingBlock(_ rect: CGRect) {
        let blurs: [(blur: CGFloat, alpha: CGFloat)] = [
            (rect.height * 1.4, 0.6),
            (rect.height * 0.5, 0.95),
        ]
        for b in blurs {
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = green.withAlphaComponent(b.alpha)
            shadow.shadowBlurRadius = b.blur
            shadow.shadowOffset = .zero
            shadow.set()
            green.setFill()
            rect.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private static func drawScanlines(in bounds: NSRect) {
        NSColor(white: 0.0, alpha: 0.18).setFill()
        var y: CGFloat = 0
        let step: CGFloat = 3.0
        while y < bounds.height {
            NSRect(x: 0, y: y, width: bounds.width, height: 1).fill()
            y += step
        }
    }
}
