import Foundation

extension Catalog {
    /// Months (1–12) when this produce is at its US peak: cheapest, best tasting, and
    /// most likely to have been grown nearby rather than shipped across a hemisphere.
    ///
    /// Anything absent from this table — frozen vegetables, canned goods, staples like
    /// carrots, onions, mushrooms and bananas — is treated as available all year and
    /// neither rewarded nor penalised. These are national generalisations for the
    /// continental US; a local farmers' market is always the better authority.
    public static let peakMonths: [String: Set<Int>] = [
        // Vegetables
        "broccoli":    [10, 11, 12, 1, 2, 3, 4],
        "bokchoy":     [9, 10, 11, 12, 1, 2, 3],
        "cabbage":     [10, 11, 12, 1, 2, 3],
        "spinach":     [3, 4, 5, 9, 10, 11],
        "lettuce":     [4, 5, 6, 9, 10, 11],
        "celery":      [10, 11, 12, 1, 2, 3],
        "zucchini":    [6, 7, 8, 9],
        "cucumber":    [6, 7, 8, 9],
        "pepper":      [7, 8, 9, 10],
        "freshtomato": [6, 7, 8, 9],
        "freshchili":  [7, 8, 9],
        "potato":      [9, 10, 11],
        "pumpkin":     [9, 10, 11],
        // Fruit
        "strawberry":  [4, 5, 6],
        "berries":     [6, 7, 8],
        "peach":       [6, 7, 8, 9],
        "apple":       [9, 10, 11],
        "pear":        [8, 9, 10, 11],
        "orange":      [12, 1, 2, 3, 4],
        "lemon":       [12, 1, 2, 3, 4, 5],
        "avocado":     [2, 3, 4, 5, 6, 7, 8, 9],
        "pineapple":   [3, 4, 5, 6, 7]
    ]

    /// Ingredients this table has an opinion about — everything else is year-round.
    public static func isSeasonal(_ ingredient: String) -> Bool { peakMonths[ingredient] != nil }

    public static func inSeason(_ ingredient: String, month: Int) -> Bool {
        peakMonths[ingredient]?.contains(month) ?? false
    }

    /// The seasonal produce of a given month, for the "what's good right now" list.
    public static func produceInSeason(month: Int) -> [Ingredient] {
        peakMonths.filter { $0.value.contains(month) }
            .keys.map { ingredient($0) }
            .sorted { $0.en < $1.en }
    }
}

extension Recipe {
    /// Seasonal produce this recipe uses, and which of it is at its peak this month.
    public func seasonalIngredients(month: Int) -> (inSeason: [Ingredient], outOfSeason: [Ingredient]) {
        let seasonal = ingredients.map { Catalog.ingredient($0.ingredient) }.filter { Catalog.isSeasonal($0.id) }
        return (seasonal.filter { Catalog.inSeason($0.id, month: month) },
                seasonal.filter { !Catalog.inSeason($0.id, month: month) })
    }
    /// How well this recipe matches the month: 1 when all its seasonal produce is at
    /// peak, 0 when none is, and 0.5 when the recipe uses only year-round ingredients,
    /// so a pantry meal is never punished for having nothing seasonal to get right.
    public func seasonalScore(month: Int) -> Double {
        let (good, bad) = seasonalIngredients(month: month)
        let total = good.count + bad.count
        guard total > 0 else { return 0.5 }
        return Double(good.count) / Double(total)
    }
    public func isInSeason(month: Int) -> Bool { !seasonalIngredients(month: month).inSeason.isEmpty }
}
