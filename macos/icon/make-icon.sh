#!/bin/bash
# Genera el ícono de la app (AppIcon.icns) sin assets externos: dibuja un PNG 1024
# con AppKit (terminal verde sobre negro, estilo "Wake Up, Neo") y lo convierte a
# .icns con sips + iconutil. Resultado: macos/AppIcon.icns
set -euo pipefail
cd "$(dirname "$0")"

WORK="$(mktemp -d)"
PNG="$WORK/icon-1024.png"
SWIFT="$WORK/render.swift"
OUT="../AppIcon.icns"

cat > "$SWIFT" <<'SWIFTEOF'
import AppKit

let size: CGFloat = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
let green = NSColor(srgbRed: 0, green: 1, blue: 65/255, alpha: 1)
let full = NSRect(x: 0, y: 0, width: size, height: size)

NSColor.clear.set(); full.fill()

// Squircle (esquinas redondeadas estilo macOS), con padding.
let pad: CGFloat = 92
let rect = full.insetBy(dx: pad, dy: pad)
let radius = rect.width * 0.2237
let card = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

NSGraphicsContext.saveGraphicsState()
card.addClip()

// Fondo casi negro con tinte verde.
NSColor(srgbRed: 0.015, green: 0.04, blue: 0.025, alpha: 1).setFill()
rect.fill()

// Glow radial verde al centro.
if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [green.withAlphaComponent(0.16).cgColor, NSColor.clear.cgColor] as CFArray,
    locations: [0, 1]) {
    ctx.drawRadialGradient(grad,
        startCenter: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0,
        endCenter: CGPoint(x: rect.midX, y: rect.midY), endRadius: rect.width * 0.62,
        options: [])
}

// Scanlines sutiles.
NSColor(white: 0, alpha: 0.10).setFill()
var y = rect.minY
while y < rect.maxY { NSRect(x: rect.minX, y: y, width: rect.width, height: 3).fill(); y += 9 }

// Prompt ">" + cursor block, centrados y con glow.
let font = NSFont(name: "Courier-Bold", size: 430)
    ?? NSFont.monospacedSystemFont(ofSize: 430, weight: .bold)
let prompt = ">"
let pSize = (prompt as NSString).size(withAttributes: [.font: font])
let blockW: CGFloat = 150
let blockH: CGFloat = pSize.height * 0.72
let gap: CGFloat = 70
let groupW = pSize.width + gap + blockW
let startX = rect.midX - groupW / 2
let baseY = rect.midY - pSize.height / 2

func glow(_ draw: () -> Void, passes: [(CGFloat, CGFloat)]) {
    for (blur, alpha) in passes {
        NSGraphicsContext.saveGraphicsState()
        let sh = NSShadow()
        sh.shadowColor = green.withAlphaComponent(alpha)
        sh.shadowBlurRadius = blur
        sh.shadowOffset = .zero
        sh.set()
        draw()
        NSGraphicsContext.restoreGraphicsState()
    }
}

glow({
    NSAttributedString(string: prompt, attributes: [.font: font, .foregroundColor: green])
        .draw(at: CGPoint(x: startX, y: baseY))
}, passes: [(70, 0.5), (22, 1.0)])

let block = NSBezierPath(
    roundedRect: NSRect(x: startX + pSize.width + gap, y: baseY + pSize.height * 0.12,
                        width: blockW, height: blockH),
    xRadius: 14, yRadius: 14)
glow({ green.setFill(); block.fill() }, passes: [(80, 0.55), (24, 1.0)])

NSGraphicsContext.restoreGraphicsState()

// Borde interior tenue para definir el squircle sobre fondos claros.
NSColor(white: 1, alpha: 0.05).setStroke()
card.lineWidth = 3
card.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFTEOF

echo "==> Renderizando PNG 1024"
swift "$SWIFT" "$PNG"

echo "==> Armando iconset"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -z 16 16     "$PNG" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32 32     "$PNG" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$PNG" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64 64     "$PNG" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$PNG" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256 256   "$PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$PNG" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512 512   "$PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$PNG" --out "$ICONSET/icon_512x512.png"    >/dev/null
cp "$PNG"                "$ICONSET/icon_512x512@2x.png"
iconutil --convert icns "$ICONSET" --output "$OUT"

rm -rf "$WORK"
echo ""
echo "✅ Ícono generado: macos/AppIcon.icns"
