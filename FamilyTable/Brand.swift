import SwiftUI

/// Shared look of Zhang Kitchen · 张家厨房.
///
/// One palette, one card, one set of status pills, so a screen the family has never
/// opened still looks like a place they have been before.
enum Brand {
    static let appName = "Zhang Kitchen"
    static let appNameZh = "张家厨房"
    /// Marketing version; keep in step with MARKETING_VERSION in the Xcode project.
    static let version = "0.2"

    // Surfaces and ink
    static let green = Color(red: 0.24, green: 0.39, blue: 0.28)
    static let deepGreen = Color(red: 0.149, green: 0.306, blue: 0.216)
    static let cream = Color(red: 0.965, green: 0.937, blue: 0.882)
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let amber = Color(red: 0.886, green: 0.604, blue: 0.235)
    static let clay = Color(red: 0.745, green: 0.361, blue: 0.243)

    // Macro colours, validated for colour-vision separation against a light surface.
    // Every segment that uses them also carries a written label, never colour alone.
    static let protein = Color(red: 0.180, green: 0.545, blue: 0.341)  // #2E8B57
    static let carbs   = Color(red: 0.788, green: 0.541, blue: 0.055)  // #C98A0E
    static let fat     = Color(red: 0.659, green: 0.271, blue: 0.184)  // #A8452F

    static let cardRadius: CGFloat = 20
}

extension View {
    /// The one card in this app: white, soft edge, generous padding.
    func kitchenCard(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous).stroke(.black.opacity(0.05)))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

/// State of one step of the weekly rhythm. Icon and wording carry the meaning; the
/// colour only reinforces it.
enum StepState {
    case done, active, waiting
    var tint: Color {
        switch self {
        case .done: return Brand.protein
        case .active: return Brand.clay
        case .waiting: return .secondary
        }
    }
    var symbol: String {
        switch self {
        case .done: return "checkmark.circle.fill"
        case .active: return "arrow.right.circle.fill"
        case .waiting: return "circle.dotted"
        }
    }
}

/// A short status label: symbol + words, so it survives a colour-blind reader,
/// a grayscale screenshot and a glance from across the kitchen.
struct StatusPill: View {
    let text: String
    var state: StepState = .waiting
    var body: some View {
        Label(text, systemImage: state.symbol)
            .font(.caption.weight(.medium))
            .lineLimit(1).fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(state == .waiting ? Color.secondary : state.tint)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background((state == .waiting ? Color.secondary : state.tint).opacity(0.1), in: Capsule())
    }
}

/// English heading with its Chinese line underneath — the app's bilingual voice,
/// applied the same way on every screen.
struct SectionHeading: View {
    let en: String
    let zh: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(en).font(.system(.title3, design: .serif).bold())
            Text(zh).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The honest small print, folded away until someone wants it. Nothing is removed —
/// it simply stops shouting over the part of the screen that is actually useful.
struct InfoNote: View {
    let title: String
    let lines: [String]
    @State private var open = false
    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(lines, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
            }.padding(.top, 6).frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(title, systemImage: "info.circle").font(.footnote.weight(.medium)).foregroundStyle(.secondary)
        }
    }
}

/// One stacked bar for protein / carbohydrate / fat, each segment labelled in words.
/// Segments are separated by a small gap and the ends are rounded, so the three parts
/// stay legible even when one of them is thin.
struct MacroBar: View {
    let nutrition: Nutrition
    var height: CGFloat = 14
    private var parts: [(name: String, grams: Double, energy: Double, color: Color)] {
        let macros = nutrition.macroCalories
        return [("Protein", nutrition.protein, macros.protein, Brand.protein),
                ("Carbs", nutrition.carbs, macros.carbs, Brand.carbs),
                ("Fat", nutrition.fat, macros.fat, Brand.fat)]
    }
    private var total: Double { max(1, parts.reduce(0) { $0 + $1.energy }) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                let gap: CGFloat = 2
                let usable = max(0, geometry.size.width - gap * CGFloat(parts.count - 1))
                HStack(spacing: gap) {
                    ForEach(parts, id: \.name) { part in
                        Capsule().fill(part.color).frame(width: usable * CGFloat(part.energy / total))
                    }
                }
            }.frame(height: height)
            HStack(spacing: 14) {
                ForEach(parts, id: \.name) { part in
                    HStack(spacing: 5) {
                        Circle().fill(part.color).frame(width: 8, height: 8)
                        Text("\(part.name) \(Int(part.grams.rounded()))g").font(.caption).foregroundStyle(.primary)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(parts.map { "\($0.name) \(Int($0.grams.rounded())) grams" }.joined(separator: ", "))
    }
}

/// Calories as the headline, macros as the supporting bar, and one plain sentence
/// about what the number does and does not mean.
struct NutritionCard: View {
    let title: String
    let zh: String
    let nutrition: Nutrition
    var note: String? = nil
    var complete: Bool = true
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
                    Text(zh).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                // The headline number never shrinks or wraps; the title reflows around it.
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(nutrition.kcal.rounded()))")
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                        .foregroundStyle(Brand.deepGreen)
                    Text("kcal").font(.caption).foregroundStyle(.secondary)
                }.fixedSize()
            }
            MacroBar(nutrition: nutrition)
            HStack(spacing: 16) {
                Label("\(Int(nutrition.fiber.rounded()))g fiber · 膳食纤维", systemImage: "leaf")
                Label("\(Int(nutrition.sodium.rounded()))mg sodium · 钠", systemImage: "drop")
            }.font(.caption).foregroundStyle(.secondary)
            if !complete {
                Label("Some ingredients have no reference values, so this is an undercount.",
                      systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Brand.clay)
            }
            if let note { Text(note).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

/// One step of the weekly rhythm, shown on Today so the app explains itself.
struct JourneyStep: Identifiable {
    let id = UUID()
    let title: String
    let zh: String
    let detail: String
    let symbol: String
    let state: StepState
    let tab: Int
}

/// The app in one glance: plan the week, confirm the meals, shop, put it away, cook.
/// Tapping a step opens the screen that does it, so the rhythm teaches itself.
struct JourneyStrip: View {
    let steps: [JourneyStep]
    let go: (Int) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW OUR WEEK WORKS · 一周怎么转")
                .font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                Button { go(step.tab) } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(step.state.tint.opacity(step.state == .waiting ? 0.08 : 0.14))
                                .frame(width: 38, height: 38)
                            Image(systemName: step.state == .done ? "checkmark" : step.symbol)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(step.state.tint)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("\(index + 1). \(step.title)").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text(step.zh).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(step.detail).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    }
                }.buttonStyle(.plain)
            }
        }
    }
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
                             with: .color(Brand.clay))

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
    var subtitle: String? = nil
    var body: some View {
        HStack(spacing: 12) {
            BrandMark(size: 46)
            VStack(alignment: .leading, spacing: 1) {
                Text(Brand.appName).font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                Text(subtitle ?? Brand.appNameZh).font(.subheadline).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
        }
    }
}
