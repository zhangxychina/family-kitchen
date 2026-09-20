import XCTest
@testable import FamilyCore
final class FamilyCoreTests: XCTestCase {
    func testScalingAndAggregation() {
        var s = FamilyState(); s.people = 6
        let date = Date()
        s.meals = [Meal(date:date,recipe:"sesame",breakfast:false),Meal(date:date,recipe:"chickenpasta",breakfast:false)]
        let line = s.shopping().first{$0.ingredient == "chicken"}!
        XCTAssertEqual(line.required,1740,accuracy:0.001)
        s.stock = [Stock(ingredient:"chicken",quantity:500,confirmed:true),Stock(ingredient:"chicken",quantity:900,confirmed:false)]
        XCTAssertEqual(s.shopping().first{$0.ingredient == "chicken"}!.shortage,1240,accuracy:0.001)
    }
    func testPurchasedAndStoredNeverDoubleCount() {
        var s = FamilyState(); s.meals = [Meal(date:Date(),recipe:"sesame",breakfast:false)]
        let loc = Location(name:"Bottom shelf",zone:"Refrigerated"); s.locations = [loc]
        s.buy("chicken"); s.buy("chicken")
        XCTAssertEqual(s.purchases.count,1); XCTAssertTrue(s.stock.isEmpty)
        XCTAssertEqual(s.shopping().first{$0.ingredient == "chicken"}!.shortage,0)
        s.storePurchase(s.purchases[0].id,location:loc.id,actualQuantity:800)
        s.storePurchase(s.purchases[0].id,location:loc.id,actualQuantity:800)
        XCTAssertEqual(s.stock[0].quantity,800)
        let line = s.shopping().first{$0.ingredient == "chicken"}!
        XCTAssertEqual(line.purchased,0); XCTAssertEqual(line.stock,800)
    }
    func testReplaceRecomputesAndClearsVotes() {
        var s = FamilyState(); s.meals = [Meal(date:Date(),recipe:"sesame",breakfast:false)]
        let id = s.meals[0].id; s.meals[0].approved = true; s.meals[0].votes["Child 1"] = "Looks good"
        s.replace(id,with:"beefpasta")
        XCTAssertFalse(s.meals[0].approved); XCTAssertTrue(s.meals[0].votes.isEmpty)
        XCTAssertNil(s.shopping().first{$0.ingredient == "chicken"}); XCTAssertEqual(Catalog.recipe(s.meals[0].recipe)?.minutes,25)
        s.replace(id,with:"oats"); XCTAssertEqual(s.meals[0].recipe,"beefpasta")
    }
    func testPlanDailyAndBalanced() {
        var s = FamilyState(); let start = FamilyState.nextMonday(after:Date()); s.plan(start:start)
        XCTAssertEqual(s.meals.count,14)
        XCTAssertEqual(Set(s.meals.map(\.date)).count,7)
        let dinners = s.meals.filter{!$0.breakfast}
        XCTAssertEqual(Set(dinners.map(\.recipe)).count,7)
        for m in dinners { XCTAssertTrue(s.warnings(for:m).isEmpty); XCTAssertTrue(Catalog.recipe(m.recipe)!.vegetable) }
        XCTAssertEqual(s.meals.filter(\.breakfast).count,7)
    }
    func testCookDeductsOnlyOnceAndConfirmedStockOnly() {
        var s = FamilyState(); s.meals = [Meal(date:Date(),recipe:"sesame",breakfast:false)]
        s.stock = [Stock(ingredient:"chicken",quantity:1000,confirmed:true),Stock(ingredient:"chicken",quantity:800,confirmed:false)]
        let id = s.meals[0].id; s.finish(id,consume:true); s.finish(id,consume:true)
        XCTAssertEqual(s.stock[0].quantity,250); XCTAssertEqual(s.stock[1].quantity,800); XCTAssertTrue(s.shopping().isEmpty)
    }
    func testConfirmDuplicateReplacesTotal() {
        var s = FamilyState(); s.confirmStock(Stock(ingredient:"rice",quantity:1000,confirmed:true)); s.confirmStock(Stock(ingredient:"rice",quantity:700,confirmed:true))
        XCTAssertEqual(s.stock.count,1); XCTAssertEqual(s.stock[0].quantity,700)
    }
    func testPersistenceRoundTripAndCorruption() throws {
        var s = FamilyState(); s.people = 6; s.plan(start:Date()); s.meals[0].votes["Child 2"] = "Prefer a swap"; s.photoFiles = ["test.jpg"]
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        try StateFile.save(s,to:file); let restored = try StateFile.load(from:file)
        XCTAssertEqual(restored.people,6); XCTAssertEqual(restored.meals.count,14); XCTAssertEqual(restored.meals[0].votes["Child 2"],"Prefer a swap"); XCTAssertEqual(restored.photoFiles,["test.jpg"])
        try Data("broken".utf8).write(to:file); XCTAssertThrowsError(try StateFile.load(from:file))
    }
    func testWarningsAndCatalogIntegrity() {
        var s = FamilyState(); let day = Date(); s.meals = [Meal(date:day,recipe:"sesame",breakfast:false),Meal(date:day.addingTimeInterval(86400),recipe:"curry",breakfast:false)]
        XCTAssertFalse(s.warnings(for:s.meals[1]).isEmpty)
        s.people = 8; XCTAssertFalse(s.warnings(for:s.meals[0]).isEmpty)
        for r in Catalog.recipes { XCTAssertFalse(r.steps.isEmpty); for p in r.ingredients { XCTAssertTrue(Catalog.ingredients.contains{$0.id == p.ingredient}); XCTAssertGreaterThan(p.quantity,0) } }
    }
    func testDiscreteUnitsRoundedPerMeal() {
        var s = FamilyState(); s.people = 6
        s.meals = [Meal(date:Date(),recipe:"oats",breakfast:true),Meal(date:Date(),recipe:"yogurt",breakfast:true)]
        XCTAssertEqual(s.shopping().first{$0.ingredient == "banana"}!.required,8)
        XCTAssertEqual(Catalog.recipe("oats")!.scaled(6).first{$0.ingredient == "banana"}!.quantity,4)
    }
    func testNewPlanKeepsPurchasedGroceries() {
        var s = FamilyState(); s.meals = [Meal(date:Date(),recipe:"sesame",breakfast:false)]; s.buy("chicken"); s.plan(start:Date()); XCTAssertEqual(s.purchases.count,1)
    }
    func testRecognitionDoesNotInventResults() async {
        do { _ = try await ManualOnlyRecognizer().candidates(from:Data()); XCTFail("Must fail honestly") } catch { XCTAssertTrue(error is RecognitionError) }
    }
    func testExpandedCatalogCountsAndIdentifiers() {
        XCTAssertEqual(Catalog.recipes.filter { !$0.breakfast }.count, 56)
        XCTAssertEqual(Catalog.recipes.filter(\.breakfast).count, 20)
        XCTAssertEqual(Set(Catalog.recipes.map(\.id)).count, 76)
        XCTAssertEqual(Set(Catalog.ingredients.map(\.id)).count, Catalog.ingredients.count)
        for recipe in Catalog.recipes {
            XCTAssertTrue(!recipe.en.isEmpty && !recipe.zh.isEmpty)
            XCTAssertTrue(recipe.minutes > 0 && recipe.minutes <= 30)
            XCTAssertTrue(recipe.steps.count >= 2)
            XCTAssertEqual(Set(recipe.ingredients.map(\.ingredient)).count, recipe.ingredients.count)
            XCTAssertTrue(recipe.ingredients.allSatisfy { $0.quantity.isFinite && $0.quantity > 0 })
            for people in [1, 5, 6, 12] {
                var state = FamilyState(); state.people = people
                state.meals = [Meal(date:Date(), recipe:recipe.id, breakfast:recipe.breakfast)]
                XCTAssertTrue(state.shopping().allSatisfy { $0.shortage.isFinite && $0.shortage > 0 })
            }
        }
    }
    func testSpicyMealsAreOptInAndScaleForOne() throws {
        let spicy = Catalog.recipes.filter(\.isSpicy)
        XCTAssertEqual(spicy.count, 6)
        XCTAssertEqual(spicy.filter { $0.cuisine == "Hunan · 湘菜" }.count, 3)
        XCTAssertEqual(spicy.filter { $0.cuisine == "Sichuan · 川菜" }.count, 3)
        var state = FamilyState()
        state.preferred = Set(spicy.map(\.id))
        for week in 0..<60 {
            state.plan(start:Date(timeIntervalSince1970:1_789_776_000 + Double(week * 604800)))
            XCTAssertTrue(state.meals.allSatisfy { Catalog.recipe($0.recipe)?.isSpicy == false })
        }
        state.people = 1
        let dinner = state.meals.first { !$0.breakfast }!
        for recipe in spicy {
            state.replace(dinner.id, with:recipe.id)
            let meal = state.meals.first { $0.id == dinner.id }!
            XCTAssertFalse(state.warnings(for:meal).isEmpty)
            for portion in recipe.scaled(1) {
                let original = recipe.ingredients.first { $0.ingredient == portion.ingredient }!
                XCTAssertEqual(portion.quantity, original.quantity / 5, accuracy:0.001)
            }
            XCTAssertTrue(state.shopping().contains { $0.ingredient == "rice" })
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:url) }
        try StateFile.save(state,to:url)
        let restored = try StateFile.load(from:url)
        XCTAssertEqual(restored.meals.first { $0.id == dinner.id }?.recipe, "sichuanyuxiang")
    }
    func testRotationUsesWholeCatalog() {
        var dinners: Set<String> = []; var breakfasts: Set<String> = []
        let start = Date(timeIntervalSince1970:1_789_776_000)
        for week in 0..<60 {
            var state = FamilyState()
            state.plan(start:start.addingTimeInterval(Double(week) * 7 * 86400))
            XCTAssertEqual(state.meals.count,14)
            XCTAssertEqual(Set(state.meals.map(\.recipe)).count,14)
            for meal in state.meals {
                if meal.breakfast { breakfasts.insert(meal.recipe) }
                else { dinners.insert(meal.recipe); XCTAssertTrue(state.warnings(for:meal).isEmpty) }
            }
        }
        XCTAssertEqual(dinners.count,50)
        XCTAssertEqual(breakfasts.count,20)
    }
    func testConsecutiveWeeksVaryAndMaintainProteinRange() {
        var state = FamilyState(); let start = Date(timeIntervalSince1970:1_789_776_000)
        state.plan(start:start)
        let old = Set(state.meals.map(\.recipe))
        state.plan(start:start.addingTimeInterval(7 * 86400))
        XCTAssertTrue(Set(state.meals.map(\.recipe)).subtracting(old).count >= 7)
        let proteins = Set(state.meals.filter { !$0.breakfast }.compactMap { Catalog.recipe($0.recipe)?.protein })
        XCTAssertTrue(proteins.count >= 4)
    }
    func testAllSwapsScaleAndPreservePurchasedGroceries() {
        var state = FamilyState(); state.people = 6
        state.meals = [Meal(date:Date(), recipe:"sesame", breakfast:false)]
        state.buy("chicken")
        let id = state.meals[0].id
        for recipe in Catalog.recipes.filter({ !$0.breakfast }) {
            state.replace(id,with:recipe.id)
            XCTAssertEqual(state.meals[0].recipe,recipe.id)
            XCTAssertTrue(state.shopping().allSatisfy { $0.shortage >= 0 && $0.shortage.isFinite })
        }
        XCTAssertEqual(state.purchases.count,1)
    }
    func testInvalidPersistentDataIsRejected() throws {
        var state = FamilyState(); state.people = 0
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        try StateFile.save(state,to:file); XCTAssertThrowsError(try StateFile.load(from:file))
        state.people = 5; state.stock = [Stock(ingredient:"unknown",quantity:5,confirmed:true)]
        try StateFile.save(state,to:file); XCTAssertThrowsError(try StateFile.load(from:file))
    }
    func testApprovalProgressAndConfirmAll() {
        var s = FamilyState()
        XCTAssertFalse(s.isPlanned); XCTAssertNil(s.planStart); XCTAssertEqual(s.itemsToBuy,0)
        let start = FamilyState.nextMonday(after:Date())
        s.plan(start:start)
        XCTAssertTrue(s.isPlanned)
        XCTAssertEqual(s.planStart,Calendar.current.startOfDay(for:start))
        XCTAssertEqual(s.approvalProgress.approved,0); XCTAssertEqual(s.approvalProgress.total,14)
        XCTAssertEqual(s.awaitingApproval.count,14)
        XCTAssertEqual(s.itemsToBuy,s.shopping().filter{$0.shortage > 0}.count)
        XCTAssertGreaterThan(s.itemsToBuy,0)
        s.finish(s.meals[0].id,consume:false)
        s.approveAll()
        XCTAssertEqual(s.approvalProgress.approved,14)
        XCTAssertTrue(s.awaitingApproval.isEmpty)
        // Cooking is not undone by confirming, and confirming never changes the menu.
        XCTAssertTrue(s.meals[0].cooked)
        XCTAssertEqual(Set(s.meals.map(\.recipe)).count,14)
    }
    func testSwapOptionsStayInSlotAndAvoidRepeats() {
        var s = FamilyState(); s.plan(start:FamilyState.nextMonday(after:Date()))
        let dinner = s.meals.first { !$0.breakfast }!
        let onPlan = Set(s.meals.filter { $0.id != dinner.id }.map(\.recipe))
        let options = s.swapOptions(for:dinner)
        XCTAssertFalse(options.isEmpty)
        XCTAssertTrue(options.allSatisfy { !$0.breakfast && $0.id != dinner.recipe })
        XCTAssertTrue(options.allSatisfy { !$0.isSpicy })
        // Meals already on the plan are ranked last, never suggested first.
        XCTAssertFalse(onPlan.contains(options[0].id))
        XCTAssertEqual(s.swapOptions(for:dinner,limit:6).count,6)
        XCTAssertTrue(s.swapOptions(for:dinner,includeSpicy:true).contains { $0.isSpicy })
        let breakfast = s.meals.first(where:\.breakfast)!
        XCTAssertTrue(s.swapOptions(for:breakfast).allSatisfy(\.breakfast))
        // Every suggestion is a legal replacement.
        for option in s.swapOptions(for:dinner,limit:5) {
            var copy = s; copy.replace(dinner.id,with:option.id)
            XCTAssertEqual(copy.meals.first { $0.id == dinner.id }?.recipe,option.id)
        }
    }
    func testNoConsumptionWhenPlanningOrSkippingDeduction() {
        var state = FamilyState(); state.stock = [Stock(ingredient:"rice",quantity:2000,confirmed:true)]
        state.plan(start:Date()); XCTAssertEqual(state.stock[0].quantity,2000)
        state.finish(state.meals[0].id,consume:false); XCTAssertEqual(state.stock[0].quantity,2000)
    }

}
