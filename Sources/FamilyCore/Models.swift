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
    /// English steps for a dish the family added themselves. Built-in recipes keep
    /// theirs in `Catalog.stepsEN` instead.
    public var stepsEnglish: [String]? = nil
    /// Where a dish came from, when it was brought in from a web page.
    public var sourceURL: String? = nil
    /// Ingredient lines that could not be matched to the app's own ingredients.
    /// They are shown with the recipe but left out of the shopping list and the
    /// nutrition estimate, which says so rather than quietly undercounting.
    public var unmatchedIngredients: [String]? = nil
    /// True for a dish this family added themselves.
    public var isFamilyAdded: Bool { id.hasPrefix("family-") }

    /// Lenient decoding, so a dish saved by an older version still opens when new
    /// fields are added later.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        en = try c.decode(String.self, forKey: .en)
        zh = try c.decode(String.self, forKey: .zh)
        breakfast = try c.decodeIfPresent(Bool.self, forKey: .breakfast) ?? false
        minutes = try c.decodeIfPresent(Int.self, forKey: .minutes) ?? 30
        starch = try c.decodeIfPresent(String.self, forKey: .starch) ?? "Other"
        protein = try c.decodeIfPresent(String.self, forKey: .protein) ?? "Other"
        vegetable = try c.decodeIfPresent(Bool.self, forKey: .vegetable) ?? false
        ingredients = try c.decodeIfPresent([Portion].self, forKey: .ingredients) ?? []
        steps = try c.decodeIfPresent([String].self, forKey: .steps) ?? []
        favorite = try c.decodeIfPresent(Bool.self, forKey: .favorite) ?? false
        cuisine = try c.decodeIfPresent(String.self, forKey: .cuisine)
        heat = try c.decodeIfPresent(Int.self, forKey: .heat) ?? 0
        stepsEnglish = try c.decodeIfPresent([String].self, forKey: .stepsEnglish)
        sourceURL = try c.decodeIfPresent(String.self, forKey: .sourceURL)
        unmatchedIngredients = try c.decodeIfPresent([String].self, forKey: .unmatchedIngredients)
    }
    public init(id: String, en: String, zh: String, breakfast: Bool, minutes: Int, starch: String,
                protein: String, vegetable: Bool, ingredients: [Portion], steps: [String],
                favorite: Bool, cuisine: String? = nil, heat: Int = 0, stepsEnglish: [String]? = nil,
                sourceURL: String? = nil, unmatchedIngredients: [String]? = nil) {
        self.id = id; self.en = en; self.zh = zh; self.breakfast = breakfast; self.minutes = minutes
        self.starch = starch; self.protein = protein; self.vegetable = vegetable
        self.ingredients = ingredients; self.steps = steps; self.favorite = favorite
        self.cuisine = cuisine; self.heat = heat; self.stepsEnglish = stepsEnglish
        self.sourceURL = sourceURL; self.unmatchedIngredients = unmatchedIngredients
    }
    public var isSpicy: Bool { heat > 0 }
    public var flavor: String { heat == 0 ? "Mild · 不辣" : "\(cuisine ?? "Spicy") · \(heat == 1 ? "Medium · 中辣" : "Hot · 辣")" }
    public var name: String { "\(en) · \(zh)" }
    /// Ingredient amounts for a number of adult portions. The catalogue is written
    /// for five, and whole items are rounded up per meal — half an egg is not a
    /// thing a kitchen can buy.
    public func scaled(_ servings: Double) -> [Portion] {
        ingredients.map { item in
            let unit = Catalog.ingredient(item.ingredient).unit
            let quantity = item.quantity * max(0.25, servings) / 5
            return Portion(item.ingredient, (unit == "each" || unit == "slice") ? ceil(quantity) : quantity)
        }
    }
}
public struct Location: Codable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var name: String
    public var zone: String
    /// Which fridge, freezer or pantry this shelf belongs to. Nil for a place that
    /// stands on its own, such as a fruit bowl on the counter.
    public var applianceID: UUID?
    /// Only set while reading a file written before appliances had records of their
    /// own, where the appliance was just a name repeated on every shelf. `migrate()`
    /// turns it into a real appliance and then clears this.
    public var legacyApplianceName: String?

    public init(name: String, zone: String, applianceID: UUID? = nil) {
        self.name = name; self.zone = zone; self.applianceID = applianceID
    }

    private enum CodingKeys: String, CodingKey { case id, name, zone, applianceID, appliance }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        zone = try c.decodeIfPresent(String.self, forKey: .zone) ?? "Pantry"
        applianceID = try c.decodeIfPresent(UUID.self, forKey: .applianceID)
        legacyApplianceName = try c.decodeIfPresent(String.self, forKey: .appliance)
    }
    /// The legacy name is deliberately never written back out: once migrated, the
    /// appliance is a record of its own and two copies of the truth would drift.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(zone, forKey: .zone)
        try c.encodeIfPresent(applianceID, forKey: .applianceID)
    }
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
    /// A child's age in years, which sets how much food is cooked for them.
    /// Adults do not need one.
    public var age: Int?
    /// Overrides the age-based amount when a family knows better — a teenager who
    /// eats like two adults, or an adult with a small appetite.
    public var portionOverride: Double?

    public init(id: UUID = UUID(), name: String, isChild: Bool, age: Int? = nil, portionOverride: Double? = nil) {
        self.id = id; self.name = name; self.isChild = isChild
        self.age = age; self.portionOverride = portionOverride
    }

    /// How much of an adult portion this person eats.
    ///
    /// These are rough household planning figures, not nutrition requirements: a
    /// four-year-old does not eat an adult's dinner, and a fifteen-year-old often
    /// eats more than one. Anyone can be adjusted by hand.
    public var portionFactor: Double {
        if let portionOverride, portionOverride > 0 { return portionOverride }
        guard isChild else { return 1.0 }
        guard let age else { return 0.7 }
        switch age {
        case ..<2: return 0.25
        case 2...3: return 0.4
        case 4...8: return 0.65
        case 9...13: return 0.85
        default: return 1.0
        }
    }
    public var portionDescription: String {
        let factor = portionFactor
        return "\(factor.formatted(.number.precision(.fractionLength(0...2)))) adult portion\(factor == 1 ? "" : "s")"
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
/// Which language the recipe is written in when the family reads it.
public enum RecipeLanguage: String, Codable, CaseIterable, Sendable {
    case both, chinese, english
    public var en: String {
        switch self {
        case .both: return "Both"
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
    public var zh: String {
        switch self {
        case .both: return "双语"
        case .chinese: return "中文"
        case .english: return "英文"
        }
    }
    public var showsChinese: Bool { self != .english }
    public var showsEnglish: Bool { self != .chinese }
}

/// Day, night, the clock, or whatever the phone is doing.
public enum Appearance: String, Codable, CaseIterable, Sendable {
    /// Follow iOS, including its own sunrise/sunset Automatic setting.
    case system
    /// Switch on this app's own schedule, for a phone left in Light mode.
    case automatic
    case day, night
    public var en: String {
        switch self {
        case .system: return "Match phone"
        case .automatic: return "By time"
        case .day: return "Day"
        case .night: return "Night"
        }
    }
    public var zh: String {
        switch self {
        case .system: return "跟随系统"
        case .automatic: return "按时间"
        case .day: return "白天"
        case .night: return "夜间"
        }
    }
    public var detail: String {
        switch self {
        case .system: return "Follows your iPhone, including its own sunrise-to-sunset switching."
        case .automatic: return "Switches on the hours you choose, whatever the phone is set to."
        case .day: return "Always the light view."
        case .night: return "Always the dark view."
        }
    }
}

public struct FamilyState: Codable, Sendable {
    /// Bump this when the stored shape changes, and teach `migrate()` how to get here
    /// from the version before. Saved files are never rejected for being older.
    public static let currentVersion = 3
    public var version = FamilyState.currentVersion
    /// What this family calls their kitchen, shown in place of the app's own name.
    public var kitchenName: String = ""
    /// Headcount, used when no family list exists yet.
    public var people = 5
    /// Extra mouths this week — visiting grandparents, a friend staying for dinner.
    public var guests: Int = 0
    /// The fridges, freezers and pantries this family keeps food in.
    public var appliances: [Appliance] = []
    /// Every shelf, drawer and door inside them, plus any place standing alone.
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
    /// Dishes this family added themselves.
    public var customRecipes: [Recipe] = []
    /// Allergens this household avoids entirely.
    public var excludedAllergens: Set<Allergen> = []
    /// Day or night view.
    public var appearance: Appearance = .system
    /// When the app switches itself over, for the "By time" setting. Hours of the
    /// local clock; the app has no location, so it cannot know your real sunset.
    public var nightStartHour: Int = 19
    public var nightEndHour: Int = 7
    /// Which language recipes are shown in.
    public var recipeLanguage: RecipeLanguage = .both
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case version, people, appliances, locations, stock, meals, purchases, photoFiles, preferred
        case members, history, excludedAllergens, appearance, recipeLanguage
        case kitchenName, guests, customRecipes, nightStartHour, nightEndHour
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
        appliances = try container.decodeIfPresent([Appliance].self, forKey: .appliances) ?? []
        locations = try container.decodeIfPresent([Location].self, forKey: .locations) ?? []
        stock = try container.decodeIfPresent([Stock].self, forKey: .stock) ?? []
        meals = try container.decodeIfPresent([Meal].self, forKey: .meals) ?? []
        purchases = try container.decodeIfPresent([Purchase].self, forKey: .purchases) ?? []
        photoFiles = try container.decodeIfPresent([String].self, forKey: .photoFiles) ?? []
        preferred = try container.decodeIfPresent(Set<String>.self, forKey: .preferred) ?? []
        members = try container.decodeIfPresent([FamilyMember].self, forKey: .members) ?? []
        history = try container.decodeIfPresent([MealRecord].self, forKey: .history) ?? []
        excludedAllergens = try container.decodeIfPresent(Set<Allergen>.self, forKey: .excludedAllergens) ?? []
        appearance = try container.decodeIfPresent(Appearance.self, forKey: .appearance) ?? .system
        nightStartHour = try container.decodeIfPresent(Int.self, forKey: .nightStartHour) ?? 19
        nightEndHour = try container.decodeIfPresent(Int.self, forKey: .nightEndHour) ?? 7
        recipeLanguage = try container.decodeIfPresent(RecipeLanguage.self, forKey: .recipeLanguage) ?? .both
        kitchenName = try container.decodeIfPresent(String.self, forKey: .kitchenName) ?? ""
        guests = try container.decodeIfPresent(Int.self, forKey: .guests) ?? 0
        customRecipes = try container.decodeIfPresent([Recipe].self, forKey: .customRecipes) ?? []
        // Family dishes must be known to the catalogue before anything looks a meal up.
        Catalog.setCustomRecipes(customRecipes)
        migrate()
    }

    /// Bring a decoded file up to the current shape. Additive changes need nothing
    /// here; conversions do.
    /// Adds or replaces one of the family's own dishes.
    public mutating func saveCustomRecipe(_ recipe: Recipe) {
        if let index = customRecipes.firstIndex(where: { $0.id == recipe.id }) { customRecipes[index] = recipe }
        else { customRecipes.append(recipe) }
        Catalog.setCustomRecipes(customRecipes)
    }
    /// Removes one, along with any planned meal that used it, so nothing refers to a
    /// dish that no longer exists.
    public mutating func deleteCustomRecipe(_ id: String) {
        customRecipes.removeAll { $0.id == id }
        meals.removeAll { $0.recipe == id }
        preferred.remove(id)
        Catalog.setCustomRecipes(customRecipes)
    }
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
        if version < 3 {
            // Version 2 knew an appliance only as a name repeated on each of its
            // shelves. Turn each distinct name into a real appliance, and work out
            // what kind it was from the temperatures its shelves were kept at.
            var byName: [String: UUID] = [:]
            for index in locations.indices {
                let legacy = (locations[index].legacyApplianceName ?? "").trimmingCharacters(in: .whitespaces)
                guard !legacy.isEmpty else { continue }
                if let existing = byName[legacy] { locations[index].applianceID = existing; continue }
                let zones = Set(locations.filter { ($0.legacyApplianceName ?? "") == legacy }.map(\.zone))
                let kind: ApplianceKind = zones == ["Frozen"] ? .freezer : (zones == ["Pantry"] ? .pantry : .fridge)
                let appliance = Appliance(kind: kind, name: legacy)
                appliances.append(appliance)
                byName[legacy] = appliance.id
                locations[index].applianceID = appliance.id
            }
            for index in locations.indices { locations[index].legacyApplianceName = nil }
        }
        version = FamilyState.currentVersion
    }
    public func shopping() -> [ShoppingLine] {
        var totals: [String: Double] = [:]
        for meal in meals where !meal.cooked {
            guard let recipe = Catalog.recipe(meal.recipe) else { continue }
            for item in recipe.scaled(servings) { totals[item.ingredient, default: 0] += item.quantity }
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
    /// Unticks an item: removes the most recent purchase that has not been put away.
    /// Anything already stored stays, because that is real food on a real shelf —
    /// correct it in the pantry instead.
    @discardableResult public mutating func unbuy(_ ingredient: String) -> Bool {
        guard let index = purchases.lastIndex(where: { $0.ingredient == ingredient && !$0.stored }) else { return false }
        purchases.remove(at: index)
        return true
    }
    /// Whether ticking this line off can still be undone here.
    public func canUnbuy(_ ingredient: String) -> Bool {
        purchases.contains { $0.ingredient == ingredient && !$0.stored }
    }
    public mutating func storePurchase(_ id: UUID, location: UUID, actualQuantity: Double) {
        guard actualQuantity.isFinite, actualQuantity > 0, locations.contains(where: { $0.id == location }), let index = purchases.firstIndex(where: { $0.id == id && !$0.stored }) else { return }
        let item = purchases[index]
        if let i = stock.firstIndex(where: { $0.ingredient == item.ingredient && $0.location == location && $0.confirmed }) { stock[i].quantity += actualQuantity }
        else { stock.append(Stock(ingredient: item.ingredient, quantity: actualQuantity, confirmed: true, location: location)) }
        purchases[index].quantity = actualQuantity
        purchases[index].stored = true
    }
    /// How many adult portions to cook. Built from the family list when there is
    /// one — each child counted by age — plus any guests. Recipes are written for
    /// five adult portions, so this is the number they are scaled against.
    public var servings: Double {
        let family = members.isEmpty ? Double(max(1, people)) : members.reduce(0) { $0 + $1.portionFactor }
        return max(0.25, family + Double(max(0, guests)))
    }
    /// How this figure was arrived at, in words the family can check.
    public var servingsExplanation: String {
        guard !members.isEmpty else { return "\(people) people" }
        let adults = members.filter { !$0.isChild }.count
        let children = members.filter(\.isChild).count
        var parts: [String] = []
        if adults > 0 { parts.append("\(adults) adult\(adults == 1 ? "" : "s")") }
        if children > 0 { parts.append("\(children) child\(children == 1 ? "" : "ren") by age") }
        if guests > 0 { parts.append("\(guests) guest\(guests == 1 ? "" : "s")") }
        return parts.joined(separator: " + ")
    }
    /// Whether the night hours cover this moment. The window usually crosses
    /// midnight — 19:00 to 07:00 — which is why this is not a simple comparison.
    public func isNightHour(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        let start = min(23, max(0, nightStartHour))
        let end = min(23, max(0, nightEndHour))
        if start == end { return false }
        return start < end ? (hour >= start && hour < end) : (hour >= start || hour < end)
    }

    /// Which view to show: true for night, false for day, and nil to hand the
    /// decision to the phone.
    public func prefersNight(at date: Date = Date(), calendar: Calendar = .current) -> Bool? {
        switch appearance {
        case .system: return nil
        case .day: return false
        case .night: return true
        case .automatic: return isNightHour(at: date, calendar: calendar)
        }
    }

    /// The next moment the automatic setting would change the view, so the app can
    /// wake up exactly then instead of polling.
    public func nextAppearanceChange(after date: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard appearance == .automatic, nightStartHour != nightEndHour else { return nil }
        let target = isNightHour(at: date, calendar: calendar) ? nightEndHour : nightStartHour
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = min(23, max(0, target)); components.minute = 0; components.second = 0
        guard let candidate = calendar.date(from: components) else { return nil }
        return candidate > date ? candidate : calendar.date(byAdding: .day, value: 1, to: candidate)
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
            let pantry = recipe.scaled(servings).reduce(0.0) { total, portion in
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
            for portion in recipe.scaled(servings) {
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
            if r.minutes > 30 || servings > 6 { result.append("30-minute target may not be met at this serving size.") }
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
        // Days that have already happened become history, so the family keeps its
        // record and the next plan knows what has just been eaten. Meals still in the
        // future are simply discarded: replacing a menu you never cooked must not
        // enter it as something the family ate.
        let today = calendar.startOfDay(for: Date())
        for meal in meals where meal.cooked || meal.date < today {
            remember(meal, cooked: meal.cooked)
        }
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
            let score = recipe.scaled(servings).reduce(0.0) { total, portion in
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
              Set(state.appliances.map(\.id)).count == state.appliances.count,
              state.locations.allSatisfy({ location in
                  location.applianceID == nil || state.appliances.contains { $0.id == location.applianceID }
              }),
              Set(state.meals.map(\.id)).count == state.meals.count,
              Set(state.purchases.map(\.id)).count == state.purchases.count else { throw StateError.invalidData }
        return state
    }
}
/// Something that can say what a photo appears to show. The app's own version runs
/// on the phone; this stays a protocol so the kitchen logic never depends on it.
public protocol PantryRecognizing {
    func labels(from image: Data) async throws -> [(label: String, confidence: Double)]
}
/// For anywhere recognition is unavailable — the family types what they see instead.
public struct ManualOnlyRecognizer: PantryRecognizing {
    public init() {}
    public func labels(from image: Data) async throws -> [(label: String, confidence: Double)] {
        throw RecognitionError.notConfigured
    }
}
public enum StateError: Error, Equatable {
    case invalidData
    /// The saved file was written by a later version of the app.
    case newerVersion
}
public enum RecognitionError: Error { case notConfigured }
