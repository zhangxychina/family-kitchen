import Foundation

public struct Ingredient: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var en: String
    public var zh: String
    public var unit: String
    public var category: String
    public var storage: String
    public var name: String { "\(en) · \(zh)" }
}
public struct Portion: Codable, Hashable, Sendable {
    public var ingredient: String
    public var quantity: Double
    public init(_ ingredient: String, _ quantity: Double) { self.ingredient = ingredient; self.quantity = quantity }
}
public struct Recipe: Codable, Identifiable, Sendable {
    public var id: String
    public var en: String
    public var zh: String
    public var breakfast: Bool
    public var minutes: Int
    public var starch: String
    public var protein: String
    public var vegetable: Bool
    public var ingredients: [Portion]
    public var steps: [String]
    public var favorite: Bool
    public var cuisine: String? = nil
    public var heat: Int = 0
    public var isSpicy: Bool { heat > 0 }
    public var flavor: String { heat == 0 ? "Mild · 不辣" : "\(cuisine ?? "Spicy") · \(heat == 1 ? "Medium · 中辣" : "Hot · 辣")" }
    public var name: String { "\(en) · \(zh)" }
    public func scaled(_ people: Int) -> [Portion] {
        ingredients.map { item in
            let unit = Catalog.ingredient(item.ingredient).unit
            let quantity = item.quantity * Double(max(1, people)) / 5
            return Portion(item.ingredient, (unit == "each" || unit == "slice") ? ceil(quantity) : quantity)
        }
    }
}
public struct Location: Codable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var name: String
    public var zone: String
    public init(name: String, zone: String) { self.name = name; self.zone = zone }
}
public struct Stock: Codable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var ingredient: String
    public var quantity: Double
    public var confirmed: Bool
    public var location: UUID?
    public init(ingredient: String, quantity: Double, confirmed: Bool, location: UUID? = nil) {
        self.ingredient = ingredient; self.quantity = max(0, quantity); self.confirmed = confirmed; self.location = location
    }
}
public struct Meal: Codable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var date: Date
    public var recipe: String
    public var breakfast: Bool
    public var approved: Bool = false
    public var votes: [String: String] = [:]
    public var cooked: Bool = false
    public init(date: Date, recipe: String, breakfast: Bool) { self.date = date; self.recipe = recipe; self.breakfast = breakfast }
}
/// Someone who eats here and, if they are a child, gets a vote on the menu.
public struct FamilyMember: Codable, Identifiable, Sendable, Hashable {
    public var id: UUID = UUID()
    public var name: String
    public var isChild: Bool
    public init(id: UUID = UUID(), name: String, isChild: Bool) {
        self.id = id; self.name = name; self.isChild = isChild
    }
}

/// A meal that has already happened. `cooked` separates "we confirmed cooking this"
/// from "this was on the plan and the week moved on" — the app does not pretend to
/// know which unconfirmed meals were actually eaten.
public struct MealRecord: Codable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var recipe: String
    public var breakfast: Bool
    public var cooked: Bool
    public var people: Int
    public init(id: UUID = UUID(), date: Date, recipe: String, breakfast: Bool, cooked: Bool, people: Int) {
        self.id = id; self.date = date; self.recipe = recipe
        self.breakfast = breakfast; self.cooked = cooked; self.people = people
    }
}

public struct Purchase: Codable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var ingredient: String
    public var quantity: Double
    public var stored: Bool = false
    public init(ingredient: String, quantity: Double) { self.ingredient = ingredient; self.quantity = quantity }
}
public struct ShoppingLine: Identifiable, Sendable {
    public var id: String { ingredient }
    public var ingredient: String
    public var required: Double
    public var stock: Double
    public var purchased: Double
    public var shortage: Double { max(0, required - stock - purchased) }
}
public struct FamilyState: Codable, Sendable {
    /// Bump this when the stored shape changes, and teach `migrate()` how to get here
    /// from the version before. Saved files are never rejected for being older.
    public static let currentVersion = 2
    public var version = FamilyState.currentVersion
    public var people = 5
    public var locations: [Location] = []
    public var stock: [Stock] = []
    public var meals: [Meal] = []
    public var purchases: [Purchase] = []
    public var photoFiles: [String] = []
    public var preferred: Set<String> = []
    /// Who lives here. Empty until the family fills it in — the app invents nobody.
    public var members: [FamilyMember] = []
    /// What has already been eaten, newest last.
    public var history: [MealRecord] = []
    /// Allergens this household avoids entirely.
    public var excludedAllergens: Set<Allergen> = []
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case version, people, locations, stock, meals, purchases, photoFiles, preferred
        case members, history, excludedAllergens
    }
    /// Every field is decoded leniently, so a file written by an older version of the
    /// app opens instead of being discarded. Fields added later simply take their
    /// defaults, and `migrate()` fixes up anything that needs converting.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // A file from a newer version of the app cannot be understood, and must not be
        // migrated or overwritten — it is someone's data, written by a version that
        // knew more than this one does.
        let stored = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        guard stored <= FamilyState.currentVersion else { throw StateError.newerVersion }
        version = stored
        people = try container.decodeIfPresent(Int.self, forKey: .people) ?? 5
        locations = try container.decodeIfPresent([Location].self, forKey: .locations) ?? []
        stock = try container.decodeIfPresent([Stock].self, forKey: .stock) ?? []
        meals = try container.decodeIfPresent([Meal].self, forKey: .meals) ?? []
        purchases = try container.decodeIfPresent([Purchase].self, forKey: .purchases) ?? []
        photoFiles = try container.decodeIfPresent([String].self, forKey: .photoFiles) ?? []
        preferred = try container.decodeIfPresent(Set<String>.self, forKey: .preferred) ?? []
        members = try container.decodeIfPresent([FamilyMember].self, forKey: .members) ?? []
        history = try container.decodeIfPresent([MealRecord].self, forKey: .history) ?? []
        excludedAllergens = try container.decodeIfPresent(Set<Allergen>.self, forKey: .excludedAllergens) ?? []
        migrate()
    }

    /// Bring a decoded file up to the current shape. Additive changes need nothing
    /// here; conversions do.
    public mutating func migrate() {
        if version < 2 {
            // Version 1 kept votes under invented labels — "Child 1", "Child 2".
            // Turn each label that was actually used into a real family member and
            // move the votes across, so nobody loses a choice they already made.
            let labels = Set(meals.flatMap { $0.votes.keys }).sorted()
            var mapping: [String: String] = [:]
            for label in labels where members.first(where: { $0.name == label }) == nil {
                let member = FamilyMember(name: label, isChild: true)
                members.append(member)
                mapping[label] = member.id.uuidString
            }
            for index in meals.indices {
                meals[index].votes = Dictionary(uniqueKeysWithValues: meals[index].votes.map { key, value in
                    (mapping[key] ?? key, value)
                })
            }
        }
        version = FamilyState.currentVersion
    }
    public func shopping() -> [ShoppingLine] {
        var totals: [String: Double] = [:]
        for meal in meals where !meal.cooked {
            guard let recipe = Catalog.recipe(meal.recipe) else { continue }
            for item in recipe.scaled(people) { totals[item.ingredient, default: 0] += item.quantity }
        }
        return totals.map { key, qty in
            ShoppingLine(ingredient: key, required: qty, stock: stock.filter { $0.ingredient == key && $0.confirmed }.reduce(0) { $0 + $1.quantity }, purchased: purchases.filter { $0.ingredient == key && !$0.stored }.reduce(0) { $0 + $1.quantity })
        }.sorted { $0.ingredient < $1.ingredient }
    }
    public mutating func confirmStock(_ item: Stock) {
        // An edit replaces a matching ingredient/location record; it never adds a second photo-derived copy.
        if let index = stock.firstIndex(where: { $0.ingredient == item.ingredient && $0.location == item.location }) { stock[index] = item }
        else { stock.append(item) }
    }
    public mutating func buy(_ ingredient: String) {
        guard let line = shopping().first(where: { $0.ingredient == ingredient }), line.shortage > 0 else { return }
        purchases.append(Purchase(ingredient: ingredient, quantity: line.shortage))
    }
    public mutating func storePurchase(_ id: UUID, location: UUID, actualQuantity: Double) {
        guard actualQuantity.isFinite, actualQuantity > 0, locations.contains(where: { $0.id == location }), let index = purchases.firstIndex(where: { $0.id == id && !$0.stored }) else { return }
        let item = purchases[index]
        if let i = stock.firstIndex(where: { $0.ingredient == item.ingredient && $0.location == location && $0.confirmed }) { stock[i].quantity += actualQuantity }
        else { stock.append(Stock(ingredient: item.ingredient, quantity: actualQuantity, confirmed: true, location: location)) }
        purchases[index].quantity = actualQuantity
        purchases[index].stored = true
    }
    /// Monday of the planned week, or nil when nothing is planned yet.
    public var planStart: Date? { meals.map(\.date).min() }
    public var planEnd: Date? { meals.map(\.date).max() }
    public var isPlanned: Bool { !meals.isEmpty }
    /// How many meals the parent has confirmed, out of the whole plan.
    public var approvalProgress: (approved: Int, total: Int) {
        (meals.filter { $0.approved || $0.cooked }.count, meals.count)
    }
    public var awaitingApproval: [Meal] { meals.filter { !$0.approved && !$0.cooked } }
    /// Items the shopping list still asks the family to buy.
    public var itemsToBuy: Int { shopping().filter { $0.shortage > 0 }.count }
    /// Confirms every meal in the plan, so the shopping list stops being provisional.
    public mutating func approveAll() {
        for index in meals.indices where !meals[index].cooked { meals[index].approved = true }
    }
    /// Ranked alternatives for one meal: same meal slot, mild first, favourites and
    /// pantry coverage ahead of the rest, and never a dish already on this week's plan.
    public func swapOptions(for meal: Meal, includeSpicy: Bool = false, limit: Int? = nil) -> [Recipe] {
        let onPlan = Set(meals.filter { $0.id != meal.id }.map(\.recipe))
        let confirmedAmounts = stock.filter(\.confirmed).reduce(into: [String: Double]()) { result, item in
            result[item.ingredient, default: 0] += item.quantity
        }
        let previousStarch = meals
            .filter { !$0.breakfast && $0.date < meal.date }
            .max { $0.date < $1.date }
            .flatMap { Catalog.recipe($0.recipe)?.starch }
        func score(_ recipe: Recipe) -> Double {
            let pantry = recipe.scaled(people).reduce(0.0) { total, portion in
                total + min(1, confirmedAmounts[portion.ingredient, default: 0] / max(1, portion.quantity))
            } / Double(max(1, recipe.ingredients.count)) * 6
            let month = Calendar.current.component(.month, from: meal.date)
            return pantry
                + (preferred.contains(recipe.id) ? 4 : 0)
                + (recipe.minutes <= 30 ? 2 : 0)
                + recipe.seasonalScore(month: month) * 4
                - repeatPenalty(recipe.id, asOf: meal.date)
                - (recipe.starch == previousStarch ? 3 : 0)
                - (onPlan.contains(recipe.id) ? 20 : 0)
                - (recipe.isSpicy ? 6 : 0)
        }
        let options = Catalog.recipes
            .filter { $0.breakfast == meal.breakfast && $0.id != meal.recipe && (includeSpicy || !$0.isSpicy)
                      && $0.isSafe(for: excludedAllergens) }
            .sorted { score($0) == score($1) ? $0.id < $1.id : score($0) > score($1) }
        guard let limit else { return options }
        return Array(options.prefix(limit))
    }
    public mutating func replace(_ mealID: UUID, with recipeID: String) {
        guard let index = meals.firstIndex(where: { $0.id == mealID && !$0.cooked }), let recipe = Catalog.recipe(recipeID), recipe.breakfast == meals[index].breakfast else { return }
        meals[index].recipe = recipeID; meals[index].approved = false; meals[index].votes = [:]
    }
    /// Records a meal as history exactly once, keyed by the meal's own id.
    public mutating func remember(_ meal: Meal, cooked: Bool) {
        guard Catalog.recipe(meal.recipe) != nil else { return }
        if let existing = history.firstIndex(where: { $0.id == meal.id }) {
            // Cooking confirmed later wins over an archived plan entry.
            if cooked { history[existing].cooked = true }
            return
        }
        history.append(MealRecord(id: meal.id, date: meal.date, recipe: meal.recipe,
                                  breakfast: meal.breakfast, cooked: cooked, people: people))
        pruneHistory()
    }
    /// Keeps roughly two years of meals, so the file cannot grow without limit.
    public mutating func pruneHistory() {
        history.sort { $0.date < $1.date }
        let cutoff = Calendar.current.date(byAdding: .day, value: -730, to: Date()) ?? .distantPast
        history.removeAll { $0.date < cutoff }
        if history.count > 1500 { history.removeFirst(history.count - 1500) }
    }
    /// Days since this recipe was last eaten, or nil when it is new to the family.
    public func daysSinceLastEaten(_ recipeID: String, asOf date: Date = Date(), calendar: Calendar = .current) -> Int? {
        let previous = history.filter { $0.recipe == recipeID && $0.date <= date }.map(\.date).max()
        guard let previous else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: previous),
                                       to: calendar.startOfDay(for: date)).day
    }
    /// How often a recipe has come round lately, for the repeat warning.
    public func timesEaten(_ recipeID: String, withinDays days: Int = 90, asOf date: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: date) else { return 0 }
        return history.filter { $0.recipe == recipeID && $0.date >= cutoff && $0.date <= date }.count
    }
    public mutating func finish(_ id: UUID, consume: Bool) {
        guard let i = meals.firstIndex(where: { $0.id == id && !$0.cooked }), let recipe = Catalog.recipe(meals[i].recipe) else { return }
        if consume {
            for portion in recipe.scaled(people) {
                var remaining = portion.quantity
                for j in stock.indices where stock[j].ingredient == portion.ingredient && stock[j].confirmed {
                    let used = min(remaining, stock[j].quantity); stock[j].quantity -= used; remaining -= used
                }
            }
        }
        meals[i].cooked = true
        remember(meals[i], cooked: true)
    }
    public func warnings(for meal: Meal) -> [String] {
        guard let r = Catalog.recipe(meal.recipe) else { return ["Recipe unavailable"] }
        var result: [String] = []
        let conflicts = r.conflicts(with: excludedAllergens)
        if !conflicts.isEmpty {
            result.append("Contains \(conflicts.map(\.name).sorted().joined(separator: ", ")) — an allergen this household avoids. 含家庭需回避的过敏原。")
        }
        if let days = daysSinceLastEaten(r.id, asOf: meal.date), days <= 14 {
            result.append(days == 0 ? "Eaten earlier today." : "Eaten \(days) day\(days == 1 ? "" : "s") ago — consider a change.")
        }
        if r.isSpicy { result.append("Spicy meal · 辣味整餐；请先确认家人接受。默认推荐不包含辣菜。") }
        if !meal.breakfast {
            if r.minutes > 30 || people > 6 { result.append("30-minute target may not be met at this serving size.") }
            if !r.vegetable { result.append("Add vegetables to complete this dinner.") }
            let previous = meals.filter { !$0.breakfast && $0.date < meal.date }.max { $0.date < $1.date }
            if let p = previous, Catalog.recipe(p.recipe)?.starch == r.starch { result.append("Same starch as the previous dinner; consider a swap.") }
        }
        return result
    }
    /// How hard to push a recipe down for having been eaten recently. The steps are
    /// deliberately coarse: a fortnight feels repetitive, two months does not.
    public func repeatPenalty(_ recipeID: String, asOf date: Date) -> Double {
        guard let days = daysSinceLastEaten(recipeID, asOf: date) else { return 0 }
        let recency: Double = days <= 7 ? 26 : days <= 14 ? 18 : days <= 28 ? 9 : days <= 56 ? 3 : 0
        // Something served four times this quarter is a rut, even if not lately.
        return recency + Double(max(0, timesEaten(recipeID, withinDays: 90, asOf: date) - 1)) * 2
    }
    public mutating func plan(start: Date, calendar: Calendar = .current) {
        let oldRecipes = Set(meals.map(\.recipe))
        let anchor = calendar.startOfDay(for: start)
        let month = calendar.component(.month, from: anchor)
        // Whatever is being replaced becomes history, so the family keeps its record
        // and the next plan knows what has just been eaten.
        for meal in meals { remember(meal, cooked: meal.cooked) }
        let dayNumber = calendar.ordinality(of: .day, in: .era, for: anchor) ?? 0
        let week = dayNumber / 7
        var planned: [Meal] = []
        var used: Set<String> = []
        var proteins: [String: Int] = [:]
        var previousStarch = ""
        var previousProtein = ""
        let breakfasts = Catalog.recipes.filter { $0.breakfast && $0.isSafe(for: excludedAllergens) }
        let dinners = Catalog.recipes.filter { !$0.breakfast && !$0.isSpicy && $0.minutes <= 30 && $0.isSafe(for: excludedAllergens) }
        // Rotating tie-breakers make every catalog entry eligible over successive weeks.
        func rotationRank(_ recipe: Recipe, in options: [Recipe], salt: Int) -> Int {
            guard let index = options.firstIndex(where: { $0.id == recipe.id }), !options.isEmpty else { return 0 }
            let offset = ((week * 7 + salt) % options.count + options.count) % options.count
            return (index - offset + options.count) % options.count
        }
        let confirmedAmounts = stock.filter(\.confirmed).reduce(into: [String: Double]()) { result, item in
            result[item.ingredient, default: 0] += item.quantity
        }
        let pantryScores = Dictionary(uniqueKeysWithValues: Catalog.recipes.map { recipe in
            let score = recipe.scaled(people).reduce(0.0) { total, portion in
                total + min(1, confirmedAmounts[portion.ingredient, default: 0] / max(1, portion.quantity))
            } / Double(max(1, recipe.ingredients.count)) * 6
            return (recipe.id, score)
        })
        func pantryScore(_ recipe: Recipe) -> Double { pantryScores[recipe.id, default: 0] }
        for day in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: day, to: anchor) else { continue }
            let breakfastOptions = breakfasts.filter { !used.contains($0.id) }
            let breakfast = breakfastOptions.sorted { a, b in
                func score(_ recipe: Recipe) -> Double {
                    (preferred.contains(recipe.id) ? 3 : 0) + pantryScore(recipe)
                        + recipe.seasonalScore(month: month) * 3
                        - repeatPenalty(recipe.id, asOf: date)
                        - (oldRecipes.contains(recipe.id) ? 12 : 0)
                }
                return score(a) == score(b) ? rotationRank(a, in: breakfasts, salt: 0) < rotationRank(b, in: breakfasts, salt: 0) : score(a) > score(b)
            }.first
            if let recipe = breakfast { planned.append(Meal(date: date, recipe: recipe.id, breakfast: true)); used.insert(recipe.id) }
            let candidates = dinners.filter { !used.contains($0.id) }
            let selected = candidates.sorted { a, b in
                func score(_ recipe: Recipe) -> Double {
                    let balance = recipe.starch == previousStarch ? -100.0 : 0
                    let proteinVariety = -Double(proteins[recipe.protein, default: 0]) * 8 - (recipe.protein == previousProtein ? 12 : 0)
                    let rotation = -Double(rotationRank(recipe, in: dinners, salt: day)) * 0.35
                    let featured = day == 0 && rotationRank(recipe, in: dinners, salt: 0) == 0 ? 40.0 : 0
                    // Produce at its peak is cheaper and tastes better, so it earns a
                    // real but modest nudge — never enough to override variety.
                    let season = recipe.seasonalScore(month: month) * 5
                    return featured + balance + proteinVariety + rotation + pantryScore(recipe) + season
                        - repeatPenalty(recipe.id, asOf: date)
                        + (preferred.contains(recipe.id) ? 5 : 0) - (oldRecipes.contains(recipe.id) ? 14 : 0)
                }
                return score(a) == score(b) ? a.id < b.id : score(a) > score(b)
            }.first
            if let recipe = selected {
                planned.append(Meal(date: date, recipe: recipe.id, breakfast: false))
                used.insert(recipe.id); previousStarch = recipe.starch; previousProtein = recipe.protein
                proteins[recipe.protein, default: 0] += 1
            }
        }
        meals = planned
    }
    public static func nextMonday(after date: Date, calendar: Calendar = .current) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let offset = ((9 - weekday) % 7 == 0) ? 7 : (9 - weekday) % 7
        return calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date))!
    }
}
public enum StateFile {
    public static func save(_ state: FamilyState, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
    }
    public static func load(from url: URL) throws -> FamilyState {
        let state = try JSONDecoder().decode(FamilyState.self, from: Data(contentsOf: url))
        let ingredientIDs = Set(Catalog.ingredients.map(\.id))
        guard state.version <= FamilyState.currentVersion, (1...12).contains(state.people),
              state.stock.allSatisfy({ ingredientIDs.contains($0.ingredient) && $0.quantity.isFinite && $0.quantity >= 0 }),
              state.purchases.allSatisfy({ ingredientIDs.contains($0.ingredient) && $0.quantity.isFinite && $0.quantity > 0 }),
              state.meals.allSatisfy({ Catalog.recipe($0.recipe)?.breakfast == $0.breakfast }),
              state.photoFiles.allSatisfy({ !$0.contains("/") && !$0.contains("..") }),
              Set(state.stock.map(\.id)).count == state.stock.count,
              Set(state.locations.map(\.id)).count == state.locations.count,
              Set(state.meals.map(\.id)).count == state.meals.count,
              Set(state.purchases.map(\.id)).count == state.purchases.count else { throw StateError.invalidData }
        return state
    }
}
public protocol PantryRecognizing { func candidates(from image: Data) async throws -> [String] }
public struct ManualOnlyRecognizer: PantryRecognizing {
    public init() {}
    public func candidates(from image: Data) async throws -> [String] { throw RecognitionError.notConfigured }
}
public enum StateError: Error, Equatable {
    case invalidData
    /// The saved file was written by a later version of the app.
    case newerVersion
}
public enum RecognitionError: Error { case notConfigured }
