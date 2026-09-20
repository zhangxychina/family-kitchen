// Renders the Zhang Family Kitchen app icon (张家厨房) without external assets.
// Usage: swift scripts/make_icon.swift <output.png> [size]
// The same shapes are drawn in SwiftUI by BrandMark in FamilyTable/Brand.swift.
import AppKit
import CoreGraphics
import Foundation

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let size = CommandLine.arguments.count > 2 ? (Double(CommandLine.arguments[2]) ?? 1024) : 1024

let space = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                              bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fputs("Could not create bitmap context\n", stderr); exit(1)
}

// The icon is authored on a 1024 grid and scaled to whatever size was requested.
let unit = size / 1024
func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r / 255, g / 255, b / 255, a])!
}
let deepGreen = rgb(38, 78, 55)
let midGreen = rgb(62, 115, 80)
let cream = rgb(246, 239, 225)
let amber = rgb(226, 154, 60)
let clay = rgb(190, 92, 62)

// Background: warm green gradient, rounded to iOS's own mask.
context.saveGState()
let gradient = CGGradient(colorsSpace: space, colors: [midGreen, deepGreen] as CFArray, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
context.restoreGState()

func scaled(_ value: Double) -> CGFloat { CGFloat(value * unit) }
func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: scaled(x), y: scaled(1024 - y)) }

// Steam: three rising wisps above the bowl.
context.setLineCap(.round)
context.setStrokeColor(cream.copy(alpha: 0.55)!)
context.setLineWidth(scaled(26))
for (index, x) in [312.0, 512.0, 712.0].enumerated() {
    let height = index == 1 ? 250.0 : 190.0
    let base = 340.0
    let path = CGMutablePath()
    path.move(to: point(x, base))
    path.addCurve(to: point(x + 46, base - height * 0.5),
                  control1: point(x - 40, base - height * 0.2),
                  control2: point(x + 56, base - height * 0.3))
    path.addCurve(to: point(x - 20, base - height),
                  control1: point(x + 34, base - height * 0.72),
                  control2: point(x - 46, base - height * 0.8))
    context.addPath(path)
    context.strokePath()
}

// Chopsticks resting across the top right.
context.setStrokeColor(cream)
context.setLineWidth(scaled(22))
context.move(to: point(690, 470)); context.addLine(to: point(918, 250)); context.strokePath()
context.setStrokeColor(amber)
context.move(to: point(726, 512)); context.addLine(to: point(952, 296)); context.strokePath()

// Rice / noodle mound sitting in the bowl.
context.setFillColor(amber)
let mound = CGMutablePath()
mound.move(to: point(318, 556))
mound.addCurve(to: point(706, 556), control1: point(380, 424), control2: point(644, 424))
mound.closeSubpath()
context.addPath(mound); context.fillPath()

context.setFillColor(clay)
context.fillEllipse(in: CGRect(x: scaled(462), y: scaled(1024 - 500), width: scaled(100), height: scaled(64)))

// The bowl itself.
context.setFillColor(cream)
let bowl = CGMutablePath()
bowl.move(to: point(244, 556))
bowl.addLine(to: point(780, 556))
bowl.addCurve(to: point(512, 860), control1: point(770, 760), control2: point(664, 860))
bowl.addCurve(to: point(244, 556), control1: point(360, 860), control2: point(254, 760))
bowl.closeSubpath()
context.addPath(bowl); context.fillPath()

// Rim highlight and foot, so the bowl reads as a bowl at small sizes.
context.setFillColor(deepGreen.copy(alpha: 0.16)!)
context.fill(CGRect(x: scaled(244), y: scaled(1024 - 618), width: scaled(536), height: scaled(30)))
context.setFillColor(cream)
context.fill(CGRect(x: scaled(430), y: scaled(1024 - 906), width: scaled(164), height: scaled(34)))

guard let image = context.makeImage() else { fputs("Render failed\n", stderr); exit(1) }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { fputs("PNG encode failed\n", stderr); exit(1) }
try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath) at \(Int(size))px")
