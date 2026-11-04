// Composes a product-style hero image from a raw screenshot of the panel.
// Usage: swiftc -O scripts/make_hero.swift -o /tmp/make_hero && /tmp/make_hero in.png out.png
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let src = NSImage(contentsOfFile: args[1]),
      let srcCG = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("usage: make_hero <in.png> <out.png>"); exit(1)
}

let W = 2400, H = 1400
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.interpolationQuality = .high
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}

// Background gradient
let bg = CGGradient(colorsSpace: cs, colors: [rgb(0.07, 0.09, 0.08), rgb(0.015, 0.02, 0.018)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])

// Green glow behind the panel
let panelW = 810.0, panelH = 1044.0
let px = 1380.0, py = (Double(H) - panelH) / 2
let glow = CGGradient(colorsSpace: cs, colors: [rgb(0.19, 0.84, 0.40, 0.32), rgb(0.19, 0.84, 0.40, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: px + panelW / 2, y: py + panelH / 2), startRadius: 0,
                       endCenter: CGPoint(x: px + panelW / 2, y: py + panelH / 2), endRadius: 900, options: [])

// Crop the panel (inset to drop the system shadow halo) and round the corners
let crop = CGRect(x: 28, y: 47, width: 268, height: 347)
let panelImg = srcCG.cropping(to: crop)!
let rect = CGRect(x: px, y: py, width: panelW, height: panelH)
let radius = 16.0 * (panelW / crop.width)
let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -40), blur: 90, color: rgb(0, 0, 0, 0.7))
ctx.addPath(path); ctx.setFillColor(rgb(0.1, 0.1, 0.1)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(path); ctx.clip()
ctx.draw(panelImg, in: rect)
ctx.restoreGState()
ctx.addPath(path); ctx.setStrokeColor(rgb(1, 1, 1, 0.14)); ctx.setLineWidth(2); ctx.strokePath()

// Text
func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let d = base.fontDescriptor.withDesign(.rounded) { return NSFont(descriptor: d, size: size) ?? base }
    return base
}
func draw(_ s: String, _ font: NSFont, _ color: NSColor, at p: CGPoint, kern: CGFloat = 0) {
    NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .kern: kern]).draw(at: p)
}
let green = NSColor(red: 0.19, green: 0.84, blue: 0.40, alpha: 1)
draw("MENU BAR UTILITY FOR MACOS", rounded(30, .bold), green, at: CGPoint(x: 170, y: 930), kern: 5)
draw("Screen On Time", rounded(150, .bold), .white, at: CGPoint(x: 160, y: 740))
draw("See exactly how long your screen has been", rounded(50, .regular), NSColor(white: 1, alpha: 0.65), at: CGPoint(x: 170, y: 640))
draw("on since you unplugged.", rounded(50, .regular), NSColor(white: 1, alpha: 0.65), at: CGPoint(x: 170, y: 575))

let bullets = ["Appears only on battery power", "Battery level at unplug, now and used",
               "Pauses while the screen sleeps", "No network access. No tracking."]
for (i, b) in bullets.enumerated() {
    let y = 430.0 - Double(i) * 78
    ctx.setFillColor(green.cgColor)
    ctx.fillEllipse(in: CGRect(x: 175, y: y + 12, width: 18, height: 18))
    draw(b, rounded(38, .medium), NSColor(white: 1, alpha: 0.88), at: CGPoint(x: 220, y: y))
}
draw("brew install --cask redmantitu/tap/screen-on-time", NSFont.monospacedSystemFont(ofSize: 30, weight: .medium),
     NSColor(white: 1, alpha: 0.55), at: CGPoint(x: 172, y: 95))

let out = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("wrote \(args[2])")
