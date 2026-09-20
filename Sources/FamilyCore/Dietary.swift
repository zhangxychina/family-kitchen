import Foundation

/// The major food allergens the app can recognise from its own ingredient list.
///
/// This is an ingredient-level filter, not a safety guarantee. Brands differ, recipes
/// get adapted, and shared equipment causes cross-contact that no app can see. A family
/// managing a real allergy still reads every label.
public enum Allergen: String, Codable, CaseIterable, Sendable, Hashable {
    case milk, egg, fish, shellfish, peanut, treenut, wheat, soy, sesame

    public var en: String {
        switch self {
        case .milk: return "Milk"
        case .egg: return "Egg"
        case .fish: return "Fish"
        case .shellfish: return "Shellfish"
        case .peanut: return "Peanut"
        case .treenut: return "Tree nuts"
        case .wheat: return "Wheat / gluten"
        case .soy: return "Soy"
        case .sesame: return "Sesame"
        }
    }
    public var zh: String {
        switch self {
        case .milk: return "奶"
        case .egg: return "蛋"
        case .fish: return "鱼"
        case .shellfish: return "甲壳类"
        case .peanut: return "花生"
        case .treenut: return "坚果"
        case .wheat: return "小麦／麸质"
        case .soy: return "大豆"
        case .sesame: return "芝麻"
        }
    }
    public var name: String { "\(en) · \(zh)" }
}

extension Catalog {
    /// Allergens carried by each ingredient, as normally sold in a US supermarket.
    ///
    /// Two entries deserve a note, because they surprise people: ordinary soy sauce is
    /// brewed with wheat, and most dried soba is cut with wheat flour. Oats are not
    /// wheat, but they are frequently milled alongside it — a coeliac family should buy
    /// certified oats, which is a label question this table cannot answer.
    public static let allergenTable: [String: Set<Allergen>] = [
        "milk": [.milk], "yogurt": [.milk], "cheddar": [.milk], "cottage": [.milk],
        "egg": [.egg],
        "salmon": [.fish], "cod": [.fish], "tuna": [.fish],
        "shrimp": [.shellfish],
        "peanut": [.peanut], "peanutbutter": [.peanut],
        "sesame": [.sesame],
        "tofu": [.soy],
        "soy": [.soy, .wheat],          // brewed soy sauce contains wheat
        "douban": [.soy, .wheat],       // chili bean paste is usually wheat-thickened
        "spaghetti": [.wheat], "penne": [.wheat], "orzo": [.wheat], "noodles": [.wheat],
        "udon": [.wheat], "soba": [.wheat], "couscous": [.wheat], "bread": [.wheat],
        "tortilla": [.wheat], "pita": [.wheat], "englishmuffin": [.wheat]
    ]

    public static func allergens(of ingredient: String) -> Set<Allergen> {
        allergenTable[ingredient] ?? []
    }
}

extension Recipe {
    /// Every allergen present in this recipe's ingredients.
    public var allergens: Set<Allergen> {
        ingredients.reduce(into: Set<Allergen>()) { $0.formUnion(Catalog.allergens(of: $1.ingredient)) }
    }
    /// The excluded allergens this recipe would bring to the table.
    public func conflicts(with excluded: Set<Allergen>) -> Set<Allergen> {
        allergens.intersection(excluded)
    }
    public func isSafe(for excluded: Set<Allergen>) -> Bool {
        conflicts(with: excluded).isEmpty
    }
    /// Which of this recipe's ingredients carry a given allergen — what a parent needs
    /// in order to judge whether a substitution is possible.
    public func ingredients(carrying allergen: Allergen) -> [Ingredient] {
        ingredients.map { Catalog.ingredient($0.ingredient) }
            .filter { Catalog.allergens(of: $0.id).contains(allergen) }
    }
}
