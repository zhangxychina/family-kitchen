import Foundation
@main struct Seed { static func main() throws {
    var s = FamilyState()
    s.kitchenName = "Zhang Family Kitchen"
    s.members = [
        FamilyMember(name: "Frank", isChild: false),
        FamilyMember(name: "Wei", isChild: false),
        FamilyMember(name: "Lily", isChild: true, age: 11),
        FamilyMember(name: "Daniel", isChild: true, age: 7),
        FamilyMember(name: "Nina", isChild: true, age: 3)
    ]
    s.addAppliance(.fridge, named: "Kitchen fridge", place: "Kitchen", detailed: true)
    s.addAppliance(.pantry, named: "Pantry", place: "Kitchen", detailed: true)
    // A week that starts today, so the Today screen has something to show.
    s.plan(start: Calendar.current.startOfDay(for: Date()))
    s.approveAll()
    // A kitchen that is genuinely half-stocked: some confirmed, some still to buy.
    let shelves = s.locations
    func place(_ name: String) -> UUID? { shelves.first { $0.name.lowercased().contains(name) }?.id }
    let fridgeShelf = place("shelf") ?? shelves.first?.id
    let pantryShelf = shelves.last?.id
    for (ingredient, quantity, spot) in [
        ("rice", 1200.0, pantryShelf), ("oil", 500.0, pantryShelf), ("soy", 300.0, pantryShelf),
        ("garlic", 120.0, pantryShelf), ("salt", 400.0, pantryShelf),
        ("egg", 10.0, fridgeShelf), ("milk", 1200.0, fridgeShelf), ("ginger", 80.0, fridgeShelf),
        ("carrot", 400.0, fridgeShelf)
    ] {
        s.confirmStock(Stock(ingredient: ingredient, quantity: quantity, confirmed: true, location: spot))
    }
    // A couple of lines already in the basket, so the list shows both states.
    s.buy("broccoli")
    let file = URL(fileURLWithPath: CommandLine.arguments[1])
    try StateFile.save(s, to: file)
    print("seeded \(s.meals.count) meals, \(s.stock.count) stock rows, \(s.itemsToBuy) to buy → \(file.path)")
} }
