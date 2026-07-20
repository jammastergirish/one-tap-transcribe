import AppKit

// Renders the "Graphite & Ember" app mark (near-black squircle + ember waveform
// bars) into a .iconset directory. Run via build_app.sh; iconutil turns the
// result into AppIcon.icns so the icon shows in the Dock, Finder, and the
// standard About panel.

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func draw(_ side: Int) -> NSBitmapImageRep {
    let s = CGFloat(side)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let inset = s * 0.055
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    NSColor(srgbRed: 31/255, green: 31/255, blue: 30/255, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.23, yRadius: rect.width * 0.23).fill()

    let rel: [CGFloat] = [0.45, 1.0, 0.68, 0.32]
    let barW = rect.width * 0.10
    let gap = rect.width * 0.065
    let total = CGFloat(rel.count) * barW + CGFloat(rel.count - 1) * gap
    var x = rect.midX - total / 2
    NSColor(srgbRed: 232/255, green: 116/255, blue: 46/255, alpha: 1).setFill()
    for h in rel {
        let bh = rect.height * 0.42 * h
        NSBezierPath(roundedRect: NSRect(x: x, y: rect.midY - bh / 2, width: barW, height: bh),
                     xRadius: barW / 2, yRadius: barW / 2).fill()
        x += barW + gap
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for (name, px) in sizes {
    let rep = draw(px)
    guard let data = rep.representation(using: .png, properties: [:]) else { continue }
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
print("wrote iconset to \(outDir)")
