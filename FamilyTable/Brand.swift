import SwiftUI

/// Shared look of Zhang Family Kitchen · 张家厨房.
enum Brand {
    static let appName = "Zhang Family Kitchen"
    static let appNameZh = "张家厨房"
    /// Marketing version; keep in step with MARKETING_VERSION in the Xcode project.
    static let version = "0.1"
    static let green = Color(red: 0.24, green: 0.39, blue: 0.28)
    static let deepGreen = Color(red: 0.149, green: 0.306, blue: 0.216)
    static let cream = Color(red: 0.965, green: 0.937, blue: 0.882)
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let amber = Color(red: 0.886, green: 0.604, blue: 0.235)
}

/// The app icon's bowl, drawn in SwiftUI so headers match the icon on the home screen.
/// Shapes mirror `scripts/make_icon.swift`; both are authored on a 1024 grid.
struct BrandMark: View {
    var size: CGFloat = 44
    private func s(_ value: CGFloat) -> CGFloat { value / 1024 * size }
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.243, green: 0.451, blue: 0.314), Brand.deepGreen],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, canvasSize in
                let unit = canvasSize.width / 1024
                func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * unit, y: y * unit) }

                for (index, x) in [CGFloat(312), 512, 712].enumerated() {
                    let height: CGFloat = index == 1 ? 250 : 190
                    var steam = Path()
                    steam.move(to: p(x, 340))
                    steam.addCurve(to: p(x + 46, 340 - height * 0.5),
                                   control1: p(x - 40, 340 - height * 0.2),
                                   control2: p(x + 56, 340 - height * 0.3))
                    steam.addCurve(to: p(x - 20, 340 - height),
                                   control1: p(x + 34, 340 - height * 0.72),
                                   control2: p(x - 46, 340 - height * 0.8))
                    context.stroke(steam, with: .color(Brand.cream.opacity(0.55)),
                                   style: StrokeStyle(lineWidth: 26 * unit, lineCap: .round))
                }
                var chopstick = Path()
                chopstick.move(to: p(690, 470)); chopstick.addLine(to: p(918, 250))
                context.stroke(chopstick, with: .color(Brand.cream),
                               style: StrokeStyle(lineWidth: 22 * unit, lineCap: .round))
                var second = Path()
                second.move(to: p(726, 512)); second.addLine(to: p(952, 296))
                context.stroke(second, with: .color(Brand.amber),
                               style: StrokeStyle(lineWidth: 22 * unit, lineCap: .round))

                var mound = Path()
                mound.move(to: p(318, 556))
                mound.addCurve(to: p(706, 556), control1: p(380, 424), control2: p(644, 424))
                mound.closeSubpath()
                context.fill(mound, with: .color(Brand.amber))
                context.fill(Path(ellipseIn: CGRect(x: 462 * unit, y: 436 * unit, width: 100 * unit, height: 64 * unit)),
                             with: .color(Color(red: 0.745, green: 0.361, blue: 0.243)))

                var bowl = Path()
                bowl.move(to: p(244, 556))
                bowl.addLine(to: p(780, 556))
                bowl.addCurve(to: p(512, 860), control1: p(770, 760), control2: p(664, 860))
                bowl.addCurve(to: p(244, 556), control1: p(360, 860), control2: p(254, 760))
                bowl.closeSubpath()
                context.fill(bowl, with: .color(Brand.cream))
                context.fill(Path(CGRect(x: 244 * unit, y: 556 * unit, width: 536 * unit, height: 30 * unit)),
                             with: .color(Brand.deepGreen.opacity(0.16)))
                context.fill(Path(CGRect(x: 430 * unit, y: 856 * unit, width: 164 * unit, height: 34 * unit)),
                             with: .color(Brand.cream))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: s(230), style: .continuous))
        .accessibilityLabel("\(Brand.appName) · \(Brand.appNameZh)")
    }
}

/// Icon + wordmark, used at the top of Today.
struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            BrandMark(size: 46)
            VStack(alignment: .leading, spacing: 1) {
                Text(Brand.appName).font(.headline)
                Text(Brand.appNameZh).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
