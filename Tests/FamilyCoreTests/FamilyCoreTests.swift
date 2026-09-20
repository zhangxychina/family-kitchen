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
    func testEveryIngredientHasReferenceNutrition() {
        for ingredient in Catalog.ingredients {
            guard let values = Catalog.nutritionTable[ingredient.id] else {
                XCTFail("Missing nutrition for \(ingredient.id)"); continue
            }
            XCTAssertTrue([values.kcal,values.protein,values.carbs,values.fat,values.fiber,values.sodium].allSatisfy { $0.isFinite && $0 >= 0 })
            XCTAssertGreaterThanOrEqual(values.carbs,values.fiber,"\(ingredient.id): fiber exceeds carbohydrate")
            // Energy recomputed from the macros must land near the stated calories.
            // Atwater factors, counting fiber at 2 kcal/g rather than 4, which is what
            // keeps low-calorie high-fiber foods like lemon and berries honest.
            if values.kcal >= 30 {
                let net = max(0, values.carbs - values.fiber)
                let atwater = values.protein * 4 + net * 4 + values.fiber * 2 + values.fat * 9
                XCTAssertTrue((0.6...1.4).contains(atwater / values.kcal),
                              "\(ingredient.id): \(Int(values.kcal)) kcal stated, \(Int(atwater)) from macros")
            }
        }
        XCTAssertEqual(Set(Catalog.nutritionTable.keys),Set(Catalog.ingredients.map(\.id)))
        XCTAssertTrue(Catalog.recipes.allSatisfy(\.nutritionIsComplete))
    }
    func testMealNutritionIsPerPersonAndPlausible() {
        let sesame = Catalog.recipe("sesame")!
        let single = sesame.nutrition(per:1)
        let family = sesame.nutrition(per:5)
        // Per-person energy barely moves with family size; only whole-item rounding shifts it.
        XCTAssertEqual(single.kcal,family.kcal,accuracy:family.kcal * 0.25)
        XCTAssertGreaterThan(family.protein,15)
        for recipe in Catalog.recipes {
            let perPerson = recipe.nutrition(per:5)
            let range = recipe.breakfast ? 120.0...800.0 : 300.0...1200.0
            XCTAssertTrue(range.contains(perPerson.kcal),"\(recipe.id) at \(Int(perPerson.kcal)) kcal")
            XCTAssertGreaterThan(perPerson.protein,recipe.breakfast ? 4 : 15)
            XCTAssertTrue(perPerson.sodium.isFinite && perPerson.sodium >= 0)
        }
    }
    func testDayAndWeekNutritionCoversPlannedMealsOnly() {
        var s = FamilyState()
        XCTAssertEqual(s.averagePlannedDay,Nutrition.zero)
        let start = FamilyState.nextMonday(after:Date())
        s.plan(start:start)
        let day = s.nutrition(on:start)
        let mealsThatDay = s.meals.filter { Calendar.current.isDate($0.date,inSameDayAs:start) }
        XCTAssertEqual(mealsThatDay.count,2)
        let expected = mealsThatDay.compactMap { Catalog.recipe($0.recipe) }.reduce(Nutrition.zero) { $0 + $1.nutrition(per:s.people) }
        XCTAssertEqual(day.kcal,expected.kcal,accuracy:0.001)
        // Breakfast + dinner only: a day total is well under a full day of eating.
        XCTAssertTrue((500...2200).contains(day.kcal))
        XCTAssertEqual(s.averagePlannedDay.kcal,(0..<7).map { s.nutrition(on:Calendar.current.date(byAdding:.day,value:$0,to:start)!).kcal }.reduce(0,+) / 7,accuracy:0.001)
        // Unplanned days contribute nothing rather than guessing.
        XCTAssertEqual(s.nutrition(on:Calendar.current.date(byAdding:.day,value:30,to:start)!),Nutrition.zero)
    }
    func testOldSavedFileMigratesInsteadOfBreaking() throws {
        // A file written by version 1, including a field the current app no longer
        // writes and votes under the old invented labels.
        let legacy = """
        {"version":1,"people":6,"locations":[],"stock":[],"purchases":[],"photoFiles":[],
         "preferred":["sesame"],
         "meals":[{"id":"\(UUID().uuidString)","date":0,"recipe":"sesame","breakfast":false,
                   "approved":true,"cooked":false,"votes":{"Child 1":"Looks good","Child 2":"Prefer a swap"}}]}
        """
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        try Data(legacy.utf8).write(to:file)
        let restored = try StateFile.load(from:file)
        XCTAssertEqual(restored.version,FamilyState.currentVersion)
        XCTAssertEqual(restored.people,6)
        XCTAssertEqual(restored.preferred,["sesame"])
        // Nothing is invented: exactly the two children who had voted now exist.
        XCTAssertEqual(restored.members.count,2)
        XCTAssertEqual(restored.members.map(\.name).sorted(),["Child 1","Child 2"])
        XCTAssertTrue(restored.members.allSatisfy(\.isChild))
        // And their votes came with them, under the new member ids.
        let votes = restored.meals[0].votes
        XCTAssertEqual(votes.count,2)
        for member in restored.members { XCTAssertNotNil(votes[member.id.uuidString]) }
        XCTAssertTrue(restored.history.isEmpty)
        XCTAssertTrue(restored.excludedAllergens.isEmpty)
        // Saving and reloading is now stable at the current version.
        try StateFile.save(restored,to:file)
        XCTAssertEqual(try StateFile.load(from:file).members.count,2)
    }
    func testFileFromANewerAppIsRefusedRatherThanOverwritten() throws {
        var state = FamilyState(); state.version = FamilyState.currentVersion + 1
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        try StateFile.save(state,to:file)
        XCTAssertThrowsError(try StateFile.load(from:file))
    }
    func testAllergenExclusionsRemoveMealsEverywhere() {
        var s = FamilyState()
        s.excludedAllergens = [.peanut,.shellfish]
        s.plan(start:FamilyState.nextMonday(after:Date()))
        XCTAssertEqual(s.meals.count,14)
        for meal in s.meals {
            let recipe = Catalog.recipe(meal.recipe)!
            XCTAssertTrue(recipe.isSafe(for:s.excludedAllergens),"\(recipe.id) slipped past the filter")
        }
        let dinner = s.meals.first { !$0.breakfast }!
        XCTAssertTrue(s.swapOptions(for:dinner,includeSpicy:true).allSatisfy { $0.isSafe(for:s.excludedAllergens) })
        // A conflicting meal swapped in on purpose is still flagged, not silently allowed.
        let shrimp = Catalog.recipes.first { !$0.breakfast && $0.allergens.contains(.shellfish) }!
        s.replace(dinner.id,with:shrimp.id)
        XCTAssertTrue(s.warnings(for:s.meals.first { $0.id == dinner.id }!).contains { $0.contains("Shellfish") })
        // The table itself has to agree with the ingredients it describes.
        XCTAssertEqual(Set(Catalog.allergenTable.keys).subtracting(Catalog.ingredients.map(\.id)),[])
        XCTAssertTrue(Catalog.allergens(of:"soy").contains(.wheat))
        XCTAssertEqual(Catalog.recipe("sesame")!.ingredients(carrying:.sesame).map(\.id),["sesame"])
    }
    func testSeasonTableIsSaneAndPlanningFollowsTheMonth() {
        for (id,months) in Catalog.peakMonths {
            XCTAssertTrue(Catalog.ingredients.contains { $0.id == id },"unknown ingredient \(id)")
            XCTAssertFalse(months.isEmpty)
            XCTAssertTrue(months.allSatisfy { (1...12).contains($0) })
        }
        XCTAssertTrue(Catalog.produceInSeason(month:7).contains { $0.id == "freshtomato" })
        XCTAssertFalse(Catalog.produceInSeason(month:1).contains { $0.id == "freshtomato" })
        // A recipe with no seasonal produce is neither rewarded nor punished.
        for recipe in Catalog.recipes {
            for month in 1...12 { XCTAssertTrue((0.0...1.0).contains(recipe.seasonalScore(month:month))) }
        }
        // The July menu suits July better than the January menu does.
        func menu(month: Int) -> [Recipe] {
            var state = FamilyState()
            var components = DateComponents(); components.year = 2026; components.month = month; components.day = 6
            state.plan(start:Calendar.current.date(from:components)!)
            return state.meals.filter { !$0.breakfast }.compactMap { Catalog.recipe($0.recipe) }
        }
        func fit(_ menu: [Recipe], month: Int) -> Double {
            menu.map { $0.seasonalScore(month:month) }.reduce(0,+) / Double(max(1,menu.count))
        }
        let july = menu(month:7), january = menu(month:1)
        XCTAssertGreaterThan(fit(july,month:7),fit(january,month:7))
        XCTAssertGreaterThan(fit(january,month:1),fit(july,month:1))
    }
    func testHistoryRecordsMealsAndDiscouragesRepeats() {
        var s = FamilyState()
        let start = FamilyState.nextMonday(after:Date())
        s.plan(start:start)
        XCTAssertTrue(s.history.isEmpty)
        let first = s.meals[0]
        s.finish(first.id,consume:false)
        XCTAssertEqual(s.history.count,1)
        XCTAssertTrue(s.history[0].cooked)
        XCTAssertEqual(s.history[0].recipe,first.recipe)
        // Finishing twice cannot double-count, and the id stays the meal's own.
        s.finish(first.id,consume:false)
        XCTAssertEqual(s.history.count,1)
        XCTAssertEqual(s.history[0].id,first.id)
        // Replanning archives the week that is being replaced, cooked or not.
        let plannedRecipes = Set(s.meals.map(\.recipe))
        s.plan(start:start.addingTimeInterval(7 * 86400))
        XCTAssertEqual(s.history.count,14)
        XCTAssertEqual(s.history.filter(\.cooked).count,1)
        XCTAssertEqual(Set(s.history.map(\.recipe)),plannedRecipes)
        // And the new week avoids what was just eaten.
        XCTAssertTrue(Set(s.meals.map(\.recipe)).isDisjoint(with:plannedRecipes))
        XCTAssertEqual(s.daysSinceLastEaten(first.recipe,asOf:first.date),0)
        XCTAssertNil(s.daysSinceLastEaten("nothing-eaten-yet"))
        XCTAssertEqual(s.timesEaten(first.recipe,asOf:first.date),1)
        // Recency ranks: yesterday hurts more than last month, which beats never.
        let today = Date()
        XCTAssertGreaterThan(s.repeatPenalty(first.recipe,asOf:first.date),
                             s.repeatPenalty(first.recipe,asOf:first.date.addingTimeInterval(40 * 86400)))
        XCTAssertEqual(s.repeatPenalty("nothing-eaten-yet",asOf:today),0)
    }
    func testNoConsumptionWhenPlanningOrSkippingDeduction() {
        var state = FamilyState(); state.stock = [Stock(ingredient:"rice",quantity:2000,confirmed:true)]
        state.plan(start:Date()); XCTAssertEqual(state.stock[0].quantity,2000)
        state.finish(state.meals[0].id,consume:false); XCTAssertEqual(state.stock[0].quantity,2000)
    }

}
