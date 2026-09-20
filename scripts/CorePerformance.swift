import Foundation
@main struct Performance {
    static func main() {
        var durations: [Double] = []
        for i in 0..<100 {
            var state = FamilyState()
            state.people = 6
            state.stock = Catalog.ingredients.map { Stock(ingredient:$0.id, quantity:250, confirmed:true) }
            let begin = Date().timeIntervalSinceReferenceDate
            state.plan(start:Date(timeIntervalSince1970:1789776000 + Double(i)*604800))
            _ = state.shopping()
            durations.append((Date().timeIntervalSinceReferenceDate - begin)*1000)
        }
        durations.sort()
        print("Mac core benchmark only; release optimization; 100 runs; 70 recipes, 68 stock records, 6 people")
        print(String(format:"Plan + shopping median %.2f ms; p95 %.2f ms; max %.2f ms",durations[50],durations[95],durations[99]))
        print("This is not a measurement of iPhone scrolling, launch, or memory performance.")
    }
}
