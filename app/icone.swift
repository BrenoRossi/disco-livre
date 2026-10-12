// Gera o ícone do app (AppIcon.iconset) — usado pelo build.sh.
import AppKit

let lado: CGFloat = 1024
let img = NSImage(size: NSSize(width: lado, height: lado), flipped: false) { r in
    let caixa = r.insetBy(dx: 100, dy: 100)
    let forma = NSBezierPath(roundedRect: caixa, xRadius: 185, yRadius: 185)
    NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.80, blue: 0.56, alpha: 1),
               ending: NSColor(calibratedRed: 0.04, green: 0.42, blue: 0.72, alpha: 1))!
        .draw(in: forma, angle: -90)
    let config = NSImage.SymbolConfiguration(pointSize: 360, weight: .semibold)
    if let simbolo = NSImage(systemSymbolName: "internaldrive.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let branco = NSImage(size: simbolo.size, flipped: false) { rr in
            simbolo.draw(in: rr)
            NSColor.white.set()
            rr.fill(using: .sourceAtop)
            return true
        }
        let t = simbolo.size
        branco.draw(in: NSRect(x: (lado - t.width) / 2, y: (lado - t.height) / 2 - 20, width: t.width, height: t.height))
    }
    return true
}

let destino = CommandLine.arguments[1]
let tamanhos: [(String, Int)] = [
    ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64),
    ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512),
    ("512x512", 512), ("512x512@2x", 1024),
]
for (nome, px) in tamanhos {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(destino)/icon_\(nome).png"))
}
