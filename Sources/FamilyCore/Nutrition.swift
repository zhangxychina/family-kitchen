import Foundation

/// Estimated nutrition for one meal or one day, per person.
///
/// Values are rounded reference figures for ingredients **as purchased** — raw meat,
/// dry pasta, drained canned goods. They are not laboratory measurements of the finished
/// dish, and cooking losses, draining, leftovers and what each person actually eats are
/// not modelled. Breakfast and dinner only: lunch and snacks are outside this app, so a
/// day total here is never a claim about a whole day's needs.
public struct Nutrition: Codable, Sendable, Hashable {
    public var kcal: Double
    public var protein: Double   // g
    public var carbs: Double     // g
    public var fat: Double       // g
    public var fiber: Double     // g
    public var sodium: Double    // mg
    public init(kcal: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0, fiber: Double = 0, sodium: Double = 0) {
        self.kcal = kcal; self.protein = protein; self.carbs = carbs
        self.fat = fat; self.fiber = fiber; self.sodium = sodium
    }
    public static func + (a: Nutrition, b: Nutrition) -> Nutrition {
        Nutrition(kcal: a.kcal + b.kcal, protein: a.protein + b.protein, carbs: a.carbs + b.carbs,
                  fat: a.fat + b.fat, fiber: a.fiber + b.fiber, sodium: a.sodium + b.sodium)
    }
    public func scaled(by factor: Double) -> Nutrition {
        guard factor.isFinite else { return Nutrition() }
        return Nutrition(kcal: kcal * factor, protein: protein * factor, carbs: carbs * factor,
                         fat: fat * factor, fiber: fiber * factor, sodium: sodium * factor)
    }
    public static let zero = Nutrition()
    /// Calories contributed by each macronutrient, using 4/4/9 kcal per gram.
    public var macroCalories: (protein: Double, carbs: Double, fat: Double) {
        (protein * 4, carbs * 4, fat * 9)
    }
}

extension Catalog {
    /// Reference nutrition per ingredient: per 100 g / 100 mL for bulk units, and per
    /// item for `each` / `slice` units (one egg, one slice of bread, one tortilla).
    ///
    /// Figures are typical published values for these foods, rounded to the precision
    /// that home cooking justifies. Brands vary — salted noodles, chili pastes and
    /// cheeses vary most in sodium — so treat every number here as an estimate.
    public static let nutritionTable: [String: Nutrition] = [
        // Protein, raw as purchased
        "chicken":    Nutrition(kcal: 120, protein: 22.5, carbs: 0,    fat: 2.6,  fiber: 0,    sodium: 45),
        "beef":       Nutrition(kcal: 150, protein: 21,   carbs: 0,    fat: 7,    fiber: 0,    sodium: 55),
        "pork":       Nutrition(kcal: 120, protein: 21,   carbs: 0,    fat: 3.5,  fiber: 0,    sodium: 50),
        "groundpork": Nutrition(kcal: 263, protein: 17,   carbs: 0,    fat: 21,   fiber: 0,    sodium: 60),
        "turkey":     Nutrition(kcal: 150, protein: 19,   carbs: 0,    fat: 8,    fiber: 0,    sodium: 70),
        "salmon":     Nutrition(kcal: 208, protein: 20,   carbs: 0,    fat: 13,   fiber: 0,    sodium: 59),
        "cod":        Nutrition(kcal: 82,  protein: 18,   carbs: 0,    fat: 0.7,  fiber: 0,    sodium: 54),
        "shrimp":     Nutrition(kcal: 85,  protein: 20,   carbs: 0.2,  fat: 0.5,  fiber: 0,    sodium: 180),
        "tuna":       Nutrition(kcal: 116, protein: 25.5, carbs: 0,    fat: 0.8,  fiber: 0,    sodium: 247),
        "tofu":       Nutrition(kcal: 130, protein: 15,   carbs: 3,    fat: 7.5,  fiber: 1.5,  sodium: 12),
        // Dairy & eggs
        "egg":        Nutrition(kcal: 72,  protein: 6.3,  carbs: 0.4,  fat: 4.8,  fiber: 0,    sodium: 71),
        "milk":       Nutrition(kcal: 50,  protein: 3.4,  carbs: 4.8,  fat: 2,    fiber: 0,    sodium: 44),
        "yogurt":     Nutrition(kcal: 61,  protein: 3.5,  carbs: 4.7,  fat: 3.3,  fiber: 0,    sodium: 46),
        "cheddar":    Nutrition(kcal: 403, protein: 23,   carbs: 3.1,  fat: 33,   fiber: 0,    sodium: 653),
        "cottage":    Nutrition(kcal: 84,  protein: 11,   carbs: 4.3,  fat: 2.3,  fiber: 0,    sodium: 330),
        // Vegetables
        "broccoli":   Nutrition(kcal: 34,  protein: 2.8,  carbs: 6.6,  fat: 0.4,  fiber: 2.6,  sodium: 33),
        "carrot":     Nutrition(kcal: 41,  protein: 0.9,  carbs: 9.6,  fat: 0.2,  fiber: 2.8,  sodium: 69),
        "potato":     Nutrition(kcal: 77,  protein: 2,    carbs: 17.5, fat: 0.1,  fiber: 2.1,  sodium: 6),
        "spinach":    Nutrition(kcal: 23,  protein: 2.9,  carbs: 3.6,  fat: 0.4,  fiber: 2.2,  sodium: 79),
        "bokchoy":    Nutrition(kcal: 13,  protein: 1.5,  carbs: 2.2,  fat: 0.2,  fiber: 1,    sodium: 65),
        "peas":       Nutrition(kcal: 81,  protein: 5.4,  carbs: 14.5, fat: 0.4,  fiber: 5.1,  sodium: 72),
        "corn":       Nutrition(kcal: 88,  protein: 3.2,  carbs: 21,   fat: 0.8,  fiber: 2.3,  sodium: 3),
        "mushroom":   Nutrition(kcal: 22,  protein: 3.1,  carbs: 3.3,  fat: 0.3,  fiber: 1,    sodium: 5),
        "pepper":     Nutrition(kcal: 31,  protein: 1,    carbs: 6,    fat: 0.3,  fiber: 2.1,  sodium: 4),
        "celery":     Nutrition(kcal: 16,  protein: 0.7,  carbs: 3,    fat: 0.2,  fiber: 1.6,  sodium: 80),
        "cabbage":    Nutrition(kcal: 25,  protein: 1.3,  carbs: 5.8,  fat: 0.1,  fiber: 2.5,  sodium: 18),
        "zucchini":   Nutrition(kcal: 17,  protein: 1.2,  carbs: 3.1,  fat: 0.3,  fiber: 1,    sodium: 8),
        "freshtomato":Nutrition(kcal: 18,  protein: 0.9,  carbs: 3.9,  fat: 0.2,  fiber: 1.2,  sodium: 5),
        "lettuce":    Nutrition(kcal: 17,  protein: 1.2,  carbs: 3.3,  fat: 0.3,  fiber: 2.1,  sodium: 8),
        "cucumber":   Nutrition(kcal: 15,  protein: 0.7,  carbs: 3.6,  fat: 0.1,  fiber: 0.5,  sodium: 2),
        "scallion":   Nutrition(kcal: 32,  protein: 1.8,  carbs: 7.3,  fat: 0.2,  fiber: 2.6,  sodium: 16),
        "ginger":     Nutrition(kcal: 80,  protein: 1.8,  carbs: 18,   fat: 0.8,  fiber: 2,    sodium: 13),
        "garlic":     Nutrition(kcal: 149, protein: 6.4,  carbs: 33,   fat: 0.5,  fiber: 2.1,  sodium: 17),
        "pumpkin":    Nutrition(kcal: 34,  protein: 1.1,  carbs: 8.1,  fat: 0.3,  fiber: 2.9,  sodium: 5),
        // Fruit
        "banana":     Nutrition(kcal: 105, protein: 1.3,  carbs: 27,   fat: 0.4,  fiber: 3.1,  sodium: 1),
        "berries":    Nutrition(kcal: 57,  protein: 0.7,  carbs: 14.5, fat: 0.3,  fiber: 2.4,  sodium: 1),
        "strawberry": Nutrition(kcal: 32,  protein: 0.7,  carbs: 7.7,  fat: 0.3,  fiber: 2,    sodium: 1),
        "orange":     Nutrition(kcal: 62,  protein: 1.2,  carbs: 15.4, fat: 0.2,  fiber: 3.1,  sodium: 0),
        "lemon":      Nutrition(kcal: 17,  protein: 0.6,  carbs: 5.4,  fat: 0.2,  fiber: 1.6,  sodium: 1),
        "apple":      Nutrition(kcal: 95,  protein: 0.5,  carbs: 25,   fat: 0.3,  fiber: 4.4,  sodium: 2),
        "pear":       Nutrition(kcal: 101, protein: 0.6,  carbs: 27,   fat: 0.2,  fiber: 5.5,  sodium: 2),
        "peach":      Nutrition(kcal: 59,  protein: 1.4,  carbs: 14.3, fat: 0.4,  fiber: 2.3,  sodium: 0),
        "avocado":    Nutrition(kcal: 240, protein: 3,    carbs: 12.8, fat: 22,   fiber: 10,   sodium: 11),
        "pineapple":  Nutrition(kcal: 60,  protein: 0.4,  carbs: 15.7, fat: 0.1,  fiber: 1,    sodium: 1),
        // Grains, dry or as packaged
        "rice":       Nutrition(kcal: 360, protein: 6.6,  carbs: 79,   fat: 0.6,  fiber: 1,    sodium: 5),
        "spaghetti":  Nutrition(kcal: 371, protein: 13,   carbs: 75,   fat: 1.5,  fiber: 3.2,  sodium: 6),
        "penne":      Nutrition(kcal: 371, protein: 13,   carbs: 75,   fat: 1.5,  fiber: 3.2,  sodium: 6),
        "orzo":       Nutrition(kcal: 371, protein: 13,   carbs: 75,   fat: 1.5,  fiber: 3.2,  sodium: 6),
        "noodles":    Nutrition(kcal: 355, protein: 12,   carbs: 72,   fat: 1.2,  fiber: 2.5,  sodium: 550),
        "udon":       Nutrition(kcal: 130, protein: 3.5,  carbs: 27,   fat: 0.4,  fiber: 1.2,  sodium: 300),
        "vermicelli": Nutrition(kcal: 364, protein: 3.4,  carbs: 83,   fat: 0.6,  fiber: 1.6,  sodium: 15),
        "soba":       Nutrition(kcal: 340, protein: 14,   carbs: 70,   fat: 0.8,  fiber: 3,    sodium: 450),
        "couscous":   Nutrition(kcal: 376, protein: 12.8, carbs: 77,   fat: 0.6,  fiber: 5,    sodium: 10),
        "oats":       Nutrition(kcal: 379, protein: 13.2, carbs: 67.7, fat: 6.5,  fiber: 10.1, sodium: 6),
        "bread":      Nutrition(kcal: 82,  protein: 4,    carbs: 13.8, fat: 1.1,  fiber: 2,    sodium: 144),
        "tortilla":   Nutrition(kcal: 120, protein: 4,    carbs: 20,   fat: 3,    fiber: 3,    sodium: 250),
        "pita":       Nutrition(kcal: 170, protein: 6.3,  carbs: 35,   fat: 1.7,  fiber: 4.7,  sodium: 340),
        "englishmuffin": Nutrition(kcal: 130, protein: 5.8, carbs: 26, fat: 1.3,  fiber: 4.4,  sodium: 240),
        // Pantry staples
        "tomato":     Nutrition(kcal: 32,  protein: 1.6,  carbs: 7.3,  fat: 0.3,  fiber: 1.9,  sodium: 186),
        "chickpea":   Nutrition(kcal: 139, protein: 7.1,  carbs: 22.5, fat: 2.6,  fiber: 6.4,  sodium: 240),
        "blackbean":  Nutrition(kcal: 132, protein: 8.9,  carbs: 23.7, fat: 0.5,  fiber: 8.7,  sodium: 250),
        "lentil":     Nutrition(kcal: 116, protein: 9,    carbs: 20,   fat: 0.4,  fiber: 7.9,  sodium: 240),
        "peanutbutter": Nutrition(kcal: 588, protein: 25, carbs: 20,   fat: 50,   fiber: 6,    sodium: 430),
        "peanut":     Nutrition(kcal: 587, protein: 24,   carbs: 21,   fat: 50,   fiber: 8,    sodium: 6),
        "sesame":     Nutrition(kcal: 573, protein: 17.7, carbs: 23.4, fat: 49.7, fiber: 11.8, sodium: 11),
        // Seasonings: small amounts, but they carry most of the sodium
        "oil":        Nutrition(kcal: 810, protein: 0,    carbs: 0,    fat: 92,   fiber: 0,    sodium: 0),
        "soy":        Nutrition(kcal: 60,  protein: 8,    carbs: 5.6,  fat: 0.1,  fiber: 0.5,  sodium: 3300),
        "salt":       Nutrition(kcal: 0,   protein: 0,    carbs: 0,    fat: 0,    fiber: 0,    sodium: 38700),
        "sugar":      Nutrition(kcal: 387, protein: 0,    carbs: 100,  fat: 0,    fiber: 0,    sodium: 0),
        "maple":      Nutrition(kcal: 340, protein: 0,    carbs: 88,   fat: 0,    fiber: 0,    sodium: 16),
        "vinegar":    Nutrition(kcal: 40,  protein: 0.5,  carbs: 8,    fat: 0,    fiber: 0,    sodium: 800),
        "cornstarch": Nutrition(kcal: 381, protein: 0.3,  carbs: 91,   fat: 0.1,  fiber: 0.9,  sodium: 9),
        "curry":      Nutrition(kcal: 325, protein: 14,   carbs: 55,   fat: 14,   fiber: 53,   sodium: 52),
        "cinnamon":   Nutrition(kcal: 247, protein: 4,    carbs: 81,   fat: 1.2,  fiber: 53,   sodium: 10),
        "peppercorn": Nutrition(kcal: 300, protein: 10,   carbs: 65,   fat: 6,    fiber: 25,   sodium: 20),
        "freshchili": Nutrition(kcal: 40,  protein: 2,    carbs: 9,    fat: 0.2,  fiber: 1.5,  sodium: 7),
        "driedchili": Nutrition(kcal: 320, protein: 12,   carbs: 57,   fat: 12,   fiber: 27,   sodium: 90),
        "choppedchili": Nutrition(kcal: 45, protein: 1.5, carbs: 6,    fat: 0.8,  fiber: 2,    sodium: 5500),
        "douban":     Nutrition(kcal: 130, protein: 6,    carbs: 15,   fat: 4,    fiber: 4,    sodium: 6000)
    ]

    /// Nutrition for one portion, honouring the ingredient's unit basis.
    /// Returns nil when an ingredient has no reference values, so callers can say so
    /// rather than quietly reporting a meal as lighter than it is.
    public static func nutrition(for portion: Portion) -> Nutrition? {
        guard let reference = nutritionTable[portion.ingredient] else { return nil }
        let unit = ingredient(portion.ingredient).unit
        let factor = (unit == "each" || unit == "slice") ? portion.quantity : portion.quantity / 100
        return reference.scaled(by: factor)
    }
}

extension Recipe {
    /// Estimated nutrition for one person, at the given family size.
    /// Whole-item ingredients are rounded up per meal, so the per-portion figure
    /// shifts slightly with family size — which is what the kitchen actually does.
    public func nutrition(per servings: Double) -> Nutrition {
        let total = scaled(servings).reduce(Nutrition.zero) { running, portion in
            running + (Catalog.nutrition(for: portion) ?? .zero)
        }
        return total.scaled(by: 1 / max(0.25, servings))
    }
    /// True when every ingredient in this recipe has reference values.
    public var nutritionIsComplete: Bool {
        ingredients.allSatisfy { Catalog.nutritionTable[$0.ingredient] != nil }
    }
}

extension FamilyState {
    /// Per-person nutrition for the meals planned on one day (breakfast + dinner only).
    public func nutrition(on date: Date, calendar: Calendar = .current) -> Nutrition {
        meals.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .compactMap { Catalog.recipe($0.recipe) }
            .reduce(Nutrition.zero) { $0 + $1.nutrition(per: servings) }
    }
    /// Average per-person day across the whole plan, for the week's balance view.
    public var averagePlannedDay: Nutrition {
        let days = Set(meals.map { Calendar.current.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return .zero }
        return days.reduce(Nutrition.zero) { $0 + nutrition(on: $1) }.scaled(by: 1 / Double(days.count))
    }
}
