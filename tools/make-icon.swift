// Draws the app icon (3×3 contribution squares on a dark rounded tile) into an AppIcon.appiconset.
// Usage: swiftc tools/make-icon.swift -o /tmp/make-icon && /tmp/make-icon App/Resources/Assets.xcassets/AppIcon.appiconset
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
}
let greens: [UInt32] = [0x151b23, 0x033a16, 0x196c2e, 0x2ea043, 0x56d364]
let pattern = [1, 3, 2, 4, 2, 0, 3, 1, 4]

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // macOS icon grid: 824/1024 tile with ~185/1024 corner radius.
    let inset = s * 100 / 1024
    let tile = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    ctx.addPath(CGPath(roundedRect: tile, cornerWidth: s * 185 / 1024, cornerHeight: s * 185 / 1024, transform: nil))
    ctx.setFillColor(color(0x0d1117))
    ctx.fillPath()
    let pad = tile.width * 0.18, gap = tile.width * 0.05
    let cell = (tile.width - 2 * pad - 2 * gap) / 3
    for (i, level) in pattern.enumerated() {
        let r = i / 3, c = i % 3
        let rect = CGRect(x: tile.minX + pad + CGFloat(c) * (cell + gap),
                          y: tile.maxY - pad - cell - CGFloat(r) * (cell + gap), width: cell, height: cell)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: cell * 0.18, cornerHeight: cell * 0.18, transform: nil))
        ctx.setFillColor(color(level == 0 ? 0x21262d : greens[level]))
        ctx.fillPath()
    }
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try render(points * scale).write(to: out.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let json = try JSONSerialization.data(withJSONObject: ["images": images, "info": ["version": 1, "author": "xcode"]],
                                      options: [.prettyPrinted, .sortedKeys])
try json.write(to: out.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icons to \(out.path)")
