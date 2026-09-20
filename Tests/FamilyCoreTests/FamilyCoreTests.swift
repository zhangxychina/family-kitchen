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
        do { _ = try await ManualOnlyRecognizer().labels(from:Data()); XCTFail("Must fail honestly") } catch { XCTAssertTrue(error is RecognitionError) }
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
        let expected = mealsThatDay.compactMap { Catalog.recipe($0.recipe) }.reduce(Nutrition.zero) { $0 + $1.nutrition(per:s.servings) }
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
        // Replanning a week that has not happened yet discards it: only the meal
        // actually confirmed as cooked is remembered.
        s.plan(start:start.addingTimeInterval(7 * 86400))
        XCTAssertEqual(s.history.count,1)
        XCTAssertEqual(s.history[0].recipe,first.recipe)
        // And the new week avoids what was just eaten.
        XCTAssertFalse(s.meals.contains { $0.recipe == first.recipe })
        // A week that has already passed is archived when it is replaced, marked as
        // planned rather than cooked, because nobody confirmed it.
        var past = FamilyState()
        let lastMonth = Calendar.current.date(byAdding:.day,value:-30,to:Date())!
        past.plan(start:lastMonth)
        let passedRecipes = Set(past.meals.map(\.recipe))
        past.plan(start:FamilyState.nextMonday(after:Date()))
        XCTAssertEqual(past.history.count,14)
        XCTAssertEqual(past.history.filter(\.cooked).count,0)
        XCTAssertEqual(Set(past.history.map(\.recipe)),passedRecipes)
        XCTAssertEqual(s.daysSinceLastEaten(first.recipe,asOf:first.date),0)
        XCTAssertNil(s.daysSinceLastEaten("nothing-eaten-yet"))
        XCTAssertEqual(s.timesEaten(first.recipe,asOf:first.date),1)
        // Recency ranks: yesterday hurts more than last month, which beats never.
        let today = Date()
        XCTAssertGreaterThan(s.repeatPenalty(first.recipe,asOf:first.date),
                             s.repeatPenalty(first.recipe,asOf:first.date.addingTimeInterval(40 * 86400)))
        XCTAssertEqual(s.repeatPenalty("nothing-eaten-yet",asOf:today),0)
    }
    func testEveryRecipeIsFullyBilingual() {
        for recipe in Catalog.recipes {
            guard let english = recipe.englishSteps else {
                XCTFail("No English steps for \(recipe.id)"); continue
            }
            XCTAssertEqual(english.count,recipe.steps.count,"\(recipe.id): \(english.count) English steps vs \(recipe.steps.count) Chinese")
            XCTAssertTrue(english.allSatisfy { $0.count > 20 },"\(recipe.id) has a suspiciously short English step")
            // Safety temperatures must survive translation.
            for (index, chinese) in recipe.steps.enumerated() {
                for temperature in ["74°C","63°C","71°C"] where chinese.contains(temperature) {
                    XCTAssertTrue(english[index].contains(temperature),"\(recipe.id) step \(index + 1) lost \(temperature)")
                }
            }
        }
        XCTAssertEqual(Set(Catalog.stepsEN.keys),Set(Catalog.recipes.map(\.id)))
    }
    func testRecipeLanguagePreferenceSelectsText() {
        let recipe = Catalog.recipe("sesame")!
        XCTAssertEqual(recipe.title(in:.chinese),recipe.zh)
        XCTAssertEqual(recipe.title(in:.english),recipe.en)
        XCTAssertEqual(recipe.title(in:.both),recipe.name)
        let both = recipe.steps(in:.both)
        XCTAssertEqual(both.count,recipe.steps.count)
        XCTAssertTrue(both.allSatisfy { $0.zh != nil && $0.en != nil })
        XCTAssertTrue(recipe.steps(in:.chinese).allSatisfy { $0.zh != nil && $0.en == nil })
        XCTAssertTrue(recipe.steps(in:.english).allSatisfy { $0.en != nil && $0.zh == nil })
        // A dish with no translation still shows its method rather than nothing.
        var untranslated = recipe
        untranslated.id = "family-added-dish"
        XCTAssertNil(untranslated.englishSteps)
        XCTAssertEqual(untranslated.steps(in:.english).count,recipe.steps.count)
        XCTAssertTrue(untranslated.steps(in:.english).allSatisfy { $0.zh != nil })
    }
    func testPortionsFollowAdultsChildrenAndGuests() {
        var s = FamilyState()
        // With no family list, the headcount is used as-is.
        s.people = 4
        XCTAssertEqual(s.servings,4,accuracy:0.001)
        s.members = [
            FamilyMember(name:"Parent A",isChild:false),
            FamilyMember(name:"Parent B",isChild:false),
            FamilyMember(name:"Teen",isChild:true,age:14),
            FamilyMember(name:"Middle",isChild:true,age:9),
            FamilyMember(name:"Little",isChild:true,age:3)
        ]
        // 1 + 1 + 1 + 0.85 + 0.4
        XCTAssertEqual(s.servings,4.25,accuracy:0.001)
        s.guests = 2
        XCTAssertEqual(s.servings,6.25,accuracy:0.001)
        s.guests = 0
        // A smaller household buys less: shopping follows servings, not heads.
        var big = s; big.members = s.members.map { var m = $0; m.isChild = false; m.age = nil; m.portionOverride = nil; return m }
        let meal = Meal(date:Date(),recipe:"sesame",breakfast:false)
        s.meals = [meal]; big.meals = [meal]
        let small = s.shopping().first { $0.ingredient == "chicken" }!.required
        let large = big.shopping().first { $0.ingredient == "chicken" }!.required
        XCTAssertLessThan(small,large)
        XCTAssertEqual(large / small,5 / 4.25,accuracy:0.01)
        // A hand-set portion wins over the age rule, and a young child eats least.
        XCTAssertEqual(FamilyMember(name:"X",isChild:true,age:3,portionOverride:1.5).portionFactor,1.5)
        XCTAssertLessThan(FamilyMember(name:"Toddler",isChild:true,age:2).portionFactor,
                          FamilyMember(name:"Teen",isChild:true,age:15).portionFactor)
        XCTAssertEqual(FamilyMember(name:"Adult",isChild:false).portionFactor,1)
        // Nutrition is per adult portion, so it barely moves with household size.
        let recipe = Catalog.recipe("sesame")!
        XCTAssertEqual(recipe.nutrition(per:4.25).kcal,recipe.nutrition(per:5).kcal,accuracy:recipe.nutrition(per:5).kcal * 0.25)
    }
    func testKitchenNameIsTheFamilysOwn() throws {
        var s = FamilyState()
        XCTAssertEqual(s.kitchenName,"")
        s.kitchenName = "Zhang Kitchen"
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        try StateFile.save(s,to:file)
        XCTAssertEqual(try StateFile.load(from:file).kitchenName,"Zhang Kitchen")
    }
    func testImportReadsSchemaRecipeFromAPage() throws {
        let page = """
        <html><head>
        <script type="application/ld+json">
        {"@context":"https://schema.org","@graph":[
          {"@type":"WebPage","name":"Not the recipe"},
          {"@type":["Recipe"],"name":"Ginger Garlic Chicken &amp; Rice","totalTime":"PT1H15M",
           "recipeYield":"4 servings",
           "recipeIngredient":["500 g boneless chicken breast","2 tbsp reduced-sodium soy sauce","1 cup quick-cooking dry rice","a handful of chopped parsley"],
           "recipeInstructions":[{"@type":"HowToStep","text":"Slice the <b>chicken</b> thinly."},
                                 {"@type":"HowToSection","itemListElement":[{"@type":"HowToStep","text":"Fry until cooked through."}]},
                                 "Serve over rice."]}
        ]}
        </script></head><body>ignored</body></html>
        """
        let imported = try RecipeImport.parse(html:page,sourceURL:"https://example.com/dish")
        XCTAssertEqual(imported.name,"Ginger Garlic Chicken & Rice")
        XCTAssertEqual(imported.minutes,75)
        XCTAssertEqual(imported.yieldText,"4 servings")
        XCTAssertEqual(imported.ingredientLines.count,4)
        XCTAssertEqual(imported.steps,["Slice the chicken thinly.","Fry until cooked through.","Serve over rice."])
        XCTAssertEqual(imported.sourceURL,"https://example.com/dish")
        // Matching is conservative: known foods are found, unknown ones are left alone.
        XCTAssertEqual(RecipeImport.matchIngredient(imported.ingredientLines[0])?.id,"chicken")
        XCTAssertEqual(RecipeImport.matchIngredient(imported.ingredientLines[2])?.id,"rice")
        XCTAssertNil(RecipeImport.matchIngredient(imported.ingredientLines[3]))
        XCTAssertEqual(RecipeImport.matchIngredient("2 tbsp smooth peanut butter")?.id,"peanutbutter")
        // A page with no recipe says so rather than inventing one.
        XCTAssertThrowsError(try RecipeImport.parse(html:"<html><body>no recipe here</body></html>",sourceURL:"https://example.com"))
        XCTAssertEqual(RecipeImport.durationMinutes("PT45M"),45)
        XCTAssertEqual(RecipeImport.durationMinutes("PT2H"),120)
        XCTAssertNil(RecipeImport.durationMinutes("nonsense"))
    }
    func testFamilyAddedDishesBehaveLikeAnyOther() throws {
        var s = FamilyState()
        let dish = Recipe(id:"family-test-dish",en:"Grandma's noodles",zh:"外婆的面",breakfast:false,
                          minutes:25,starch:"Noodles",protein:"Chicken",vegetable:true,
                          ingredients:[Portion("chicken",500),Portion("noodles",400),Portion("bokchoy",300)],
                          steps:["把面煮熟。","鸡肉炒香后拌入。"],favorite:false,
                          stepsEnglish:["Boil the noodles.","Fry the chicken and toss together."],
                          sourceURL:"https://example.com/noodles",
                          unmatchedIngredients:["a splash of grandma's secret sauce"])
        s.saveCustomRecipe(dish)
        XCTAssertNotNil(Catalog.recipe("family-test-dish"))
        XCTAssertTrue(dish.isFamilyAdded)
        XCTAssertTrue(Catalog.recipes.contains { $0.id == "family-test-dish" })
        // It shops, scales and feeds like any built-in dish.
        s.meals = [Meal(date:Date(),recipe:dish.id,breakfast:false)]
        XCTAssertEqual(s.shopping().first { $0.ingredient == "noodles" }?.required,400)
        XCTAssertGreaterThan(dish.nutrition(per:5).kcal,100)
        XCTAssertEqual(dish.steps(in:.english).compactMap(\.en).count,2)
        // It survives a save and reload, unmatched lines and all.
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        try StateFile.save(s,to:file)
        let restored = try StateFile.load(from:file)
        XCTAssertEqual(restored.customRecipes.count,1)
        XCTAssertEqual(restored.customRecipes[0].unmatchedIngredients,["a splash of grandma's secret sauce"])
        XCTAssertEqual(restored.customRecipes[0].sourceURL,"https://example.com/noodles")
        // Deleting takes its planned meals with it and leaves the catalogue clean.
        var after = restored
        after.deleteCustomRecipe("family-test-dish")
        XCTAssertTrue(after.meals.isEmpty)
        XCTAssertNil(Catalog.recipe("family-test-dish"))
        XCTAssertEqual(Catalog.recipes.count,76)
    }
    func testDayAndNightFollowTheClockAndThePhone() {
        var s = FamilyState()
        let calendar = Calendar(identifier:.gregorian)
        func at(_ hour: Int) -> Date {
            var c = DateComponents(); c.year = 2026; c.month = 6; c.day = 15; c.hour = hour
            return calendar.date(from:c)!
        }
        // Matching the phone means the app expresses no preference at all.
        XCTAssertEqual(s.appearance,.system)
        XCTAssertNil(s.prefersNight(at:at(23),calendar:calendar))
        XCTAssertNil(s.nextAppearanceChange(after:at(23),calendar:calendar))
        // Fixed choices ignore the clock.
        s.appearance = .night
        XCTAssertEqual(s.prefersNight(at:at(9),calendar:calendar),true)
        s.appearance = .day
        XCTAssertEqual(s.prefersNight(at:at(23),calendar:calendar),false)
        // By time: the default window crosses midnight, 19:00 to 07:00.
        s.appearance = .automatic
        XCTAssertEqual(s.nightStartHour,19)
        XCTAssertEqual(s.nightEndHour,7)
        for hour in [19,22,23,0,3,6] {
            XCTAssertEqual(s.prefersNight(at:at(hour),calendar:calendar),true,"\(hour):00 should be night")
        }
        for hour in [7,8,12,17,18] {
            XCTAssertEqual(s.prefersNight(at:at(hour),calendar:calendar),false,"\(hour):00 should be day")
        }
        // A window inside one day works too.
        s.nightStartHour = 21; s.nightEndHour = 23
        XCTAssertEqual(s.prefersNight(at:at(22),calendar:calendar),true)
        XCTAssertEqual(s.prefersNight(at:at(23),calendar:calendar),false)
        XCTAssertEqual(s.prefersNight(at:at(2),calendar:calendar),false)
        // Equal hours mean no night window rather than an always-on one.
        s.nightStartHour = 8; s.nightEndHour = 8
        XCTAssertEqual(s.prefersNight(at:at(8),calendar:calendar),false)
        XCTAssertNil(s.nextAppearanceChange(after:at(8),calendar:calendar))
        // The app knows when it next needs to change, to the hour.
        s.nightStartHour = 19; s.nightEndHour = 7
        let eveningSwitch = s.nextAppearanceChange(after:at(15),calendar:calendar)!
        XCTAssertEqual(calendar.component(.hour,from:eveningSwitch),19)
        XCTAssertEqual(calendar.component(.day,from:eveningSwitch),15)
        let morningSwitch = s.nextAppearanceChange(after:at(23),calendar:calendar)!
        XCTAssertEqual(calendar.component(.hour,from:morningSwitch),7)
        XCTAssertEqual(calendar.component(.day,from:morningSwitch),16,"after midnight the change is tomorrow morning")
    }
    func testNoConsumptionWhenPlanningOrSkippingDeduction() {
        var state = FamilyState(); state.stock = [Stock(ingredient:"rice",quantity:2000,confirmed:true)]
        state.plan(start:Date()); XCTAssertEqual(state.stock[0].quantity,2000)
        state.finish(state.meals[0].id,consume:false); XCTAssertEqual(state.stock[0].quantity,2000)
    }


    // MARK: - Where food lives

    func testApplianceStartsWithARealFridgeLayout() {
        var s = FamilyState()
        let fridge = s.addAppliance(.fridge, named:"Kitchen fridge", place:"Kitchen")!
        XCTAssertEqual(fridge.place,"Kitchen")
        let inside = s.compartments(of:fridge.id)
        XCTAssertEqual(inside.count,7)
        // The freezer on top is frozen; everything else is not.
        XCTAssertEqual(inside.filter{ $0.zone == "Frozen" }.count,1)
        XCTAssertEqual(inside.first?.zone,"Frozen")
        XCTAssertTrue(inside.contains{ $0.name.contains("Fruit") })
        XCTAssertTrue(inside.contains{ $0.name == "Door" })
        // A family that wants less detail still gets fridge and freezer kept apart.
        let garage = s.addAppliance(.fridge, named:"Garage fridge", place:"Garage", detailed:false)!
        XCTAssertEqual(s.compartments(of:garage.id).count,2)
        XCTAssertEqual(Set(s.compartments(of:garage.id).map(\.zone)),["Refrigerated","Frozen"])
        // Two fridges are told apart by name, not by guesswork.
        XCTAssertEqual(s.applianceCount(of:.fridge),2)
        XCTAssertEqual(s.describe(s.compartments(of:garage.id)[0]),"Garage fridge · Fridge")
    }

    func testAppliancesAreCappedAndNamesStayUnique() {
        var s = FamilyState()
        for _ in 0..<FamilyState.maxAppliancesPerKind { XCTAssertNotNil(s.addAppliance(.pantry)) }
        XCTAssertNil(s.addAppliance(.pantry),"one more than the cap must be refused")
        XCTAssertEqual(Set(s.appliances.map(\.name)).count,s.appliances.count)
        // A different kind is unaffected by another kind's cap.
        XCTAssertNotNil(s.addAppliance(.freezer))
    }

    func testRemovingAPlaceKeepsTheFoodItHeld() {
        var s = FamilyState()
        let fridge = s.addAppliance(.fridge)!
        let shelf = s.compartments(of:fridge.id)[1]
        s.confirmStock(Stock(ingredient:"milk",quantity:1000,confirmed:true,location:shelf.id))
        s.removeAppliance(fridge.id)
        XCTAssertTrue(s.appliances.isEmpty)
        XCTAssertTrue(s.locations.isEmpty)
        XCTAssertEqual(s.stock.count,1,"the milk is still in someone's kitchen")
        XCTAssertNil(s.stock[0].location)
        XCTAssertEqual(s.locationLabel(s.stock[0].location),"Location unconfirmed · 位置待确认")
    }

    func testCompartmentsCanBeAddedToAnAppliance() {
        var s = FamilyState()
        let pantry = s.addAppliance(.pantry, detailed:false)!
        XCTAssertEqual(s.compartments(of:pantry.id).count,1)
        XCTAssertNotNil(s.addCompartment(to:pantry.id,named:"Spice rack"))
        XCTAssertNil(s.addCompartment(to:pantry.id,named:"   "),"a blank name is not a place")
        XCTAssertNil(s.addCompartment(to:UUID(),named:"Nowhere"))
        XCTAssertEqual(s.compartments(of:pantry.id).map(\.name),["Shelves","Spice rack"])
        XCTAssertEqual(s.compartments(of:pantry.id)[1].zone,"Pantry")
    }

    func testVersionTwoAppliancesBecomeRecordsOfTheirOwn() throws {
        // Version 2 knew an appliance only as a name repeated on each shelf.
        let legacy = """
        {"version":2,"people":4,"stock":[],"purchases":[],"photoFiles":[],"meals":[],
         "locations":[{"id":"\(UUID().uuidString)","name":"Top shelf","zone":"Refrigerated","appliance":"Fridge"},
                      {"id":"\(UUID().uuidString)","name":"Door","zone":"Refrigerated","appliance":"Fridge"},
                      {"id":"\(UUID().uuidString)","name":"Basket","zone":"Frozen","appliance":"Garage freezer"},
                      {"id":"\(UUID().uuidString)","name":"Fruit bowl","zone":"Pantry"}]}
        """
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        try Data(legacy.utf8).write(to:file)
        let restored = try StateFile.load(from:file)
        XCTAssertEqual(restored.version,FamilyState.currentVersion)
        XCTAssertEqual(restored.appliances.count,2)
        // The kind is read back from the temperatures the shelves were kept at.
        XCTAssertEqual(restored.appliances.first{ $0.name == "Fridge" }?.kind,.fridge)
        XCTAssertEqual(restored.appliances.first{ $0.name == "Garage freezer" }?.kind,.freezer)
        let fridgeID = restored.appliances.first{ $0.name == "Fridge" }!.id
        XCTAssertEqual(restored.compartments(of:fridgeID).count,2)
        // A shelf that belonged to nothing still belongs to nothing.
        XCTAssertEqual(restored.looseLocations.map(\.name),["Fruit bowl"])
        // And nothing carries the old name around any more.
        XCTAssertTrue(restored.locations.allSatisfy{ $0.legacyApplianceName == nil })
    }

    func testPantryRawValueSurvivesTheRename() throws {
        // The cupboard was renamed to pantry in the app's words only; a saved file
        // must still read and write the same value.
        XCTAssertEqual(ApplianceKind.pantry.rawValue,"cupboard")
        let encoded = try JSONEncoder().encode(Appliance(kind:.pantry,name:"Larder",place:"Basement"))
        XCTAssertTrue(String(decoding:encoded,as:UTF8.self).contains("cupboard"))
        let decoded = try JSONDecoder().decode(Appliance.self,from:encoded)
        XCTAssertEqual(decoded.kind,.pantry)
        XCTAssertEqual(decoded.fullName,"Larder · Basement")
    }

    // MARK: - Checking the shelf before shopping

    func testPhotoLabelsMapToIngredientsOrToNothing() {
        XCTAssertEqual(PantryMatcher.ingredient(forLabel:"Broccoli"),"broccoli")
        XCTAssertEqual(PantryMatcher.ingredient(forLabel:"bell_pepper"),"pepper")
        XCTAssertEqual(PantryMatcher.ingredient(forLabel:"green onions"),"scallion")
        XCTAssertEqual(PantryMatcher.ingredient(forLabel:"鸡蛋"),"egg")
        // The longest phrase wins, so these never collapse into each other.
        XCTAssertEqual(PantryMatcher.ingredient(forLabel:"peanut butter"),"peanutbutter")
        XCTAssertEqual(PantryMatcher.ingredient(forLabel:"peanuts"),"peanut")
        XCTAssertEqual(PantryMatcher.ingredient(forLabel:"chili pepper"),"freshchili")
        XCTAssertEqual(PantryMatcher.ingredient(forLabel:"cottage cheese"),"cottage")
        XCTAssertEqual(PantryMatcher.ingredient(forLabel:"crushed tomatoes"),"tomato")
        XCTAssertEqual(PantryMatcher.ingredient(forLabel:"tomatoes"),"freshtomato")
        // Words too general to mean anything in a kitchen match nothing at all.
        for vague in ["food","vegetable","refrigerator","bottle","black pepper",""] {
            XCTAssertNil(PantryMatcher.ingredient(forLabel:vague),"\(vague) must not match")
        }
        // "wheat" must not reach the noodles by way of "whole wheat bread".
        XCTAssertNil(PantryMatcher.ingredient(forLabel:"wheat"))
    }

    func testFindingsPutTheShoppingListFirstAndKeepTheBestSighting() {
        let labels = [(label:"carrot",confidence:0.2),(label:"carrot",confidence:0.8),
                      (label:"banana",confidence:0.9),(label:"sofa",confidence:0.95),
                      (label:"broccoli",confidence:0.01)]
        let findings = PantryMatcher.findings(from:labels,shoppingList:["carrot"])
        XCTAssertEqual(findings.map(\.ingredient),["carrot","banana"],"nothing recognised is invented, and the list comes first")
        XCTAssertEqual(findings[0].confidence,0.8,accuracy:0.001,"the clearest sighting of a thing is the one kept")
        XCTAssertTrue(findings[0].onList)
        XCTAssertFalse(findings[1].onList)
    }

    func testAPhotoCheckTicksOffOnlyWhatIsConfirmed() {
        var s = FamilyState(); s.people = 5
        s.meals = [Meal(date:Date(),recipe:"sesame",breakfast:false)]
        let fridge = s.addAppliance(.fridge)!
        let shelf = s.compartments(of:fridge.id)[1]
        let before = s.shopping().first{ $0.ingredient == "broccoli" }!
        XCTAssertGreaterThan(before.shortage,0)
        // The amount offered is exactly what the week is short of — no more.
        let suggested = s.suggestedScanQuantity("broccoli",at:shelf.id)
        XCTAssertEqual(suggested,before.shortage,accuracy:0.001)
        // Findings on their own change nothing at all.
        XCTAssertEqual(s.shopping().first{ $0.ingredient == "broccoli" }!.shortage,before.shortage)
        s.applyScan([ScanConfirmation(ingredient:"broccoli",quantity:suggested,location:shelf.id),
                     ScanConfirmation(ingredient:"chicken",quantity:0,location:shelf.id)])
        XCTAssertEqual(s.shopping().first{ $0.ingredient == "broccoli" }!.shortage,0,"confirmed food leaves the list")
        XCTAssertGreaterThan(s.shopping().first{ $0.ingredient == "chicken" }!.shortage,0,"an amount of nothing is not a confirmation")
        XCTAssertEqual(s.stock.first{ $0.ingredient == "broccoli" }?.location,shelf.id)
        XCTAssertTrue(s.stock.first{ $0.ingredient == "broccoli" }!.confirmed)
        XCTAssertFalse(s.shoppingListIngredients.contains("broccoli"))
    }

    func testASecondCheckOfTheSameShelfDoesNotStack() {
        var s = FamilyState()
        s.meals = [Meal(date:Date(),recipe:"sesame",breakfast:false)]
        let fridge = s.addAppliance(.fridge)!
        let shelf = s.compartments(of:fridge.id)[1]
        s.applyScan([ScanConfirmation(ingredient:"rice",quantity:200,location:shelf.id)])
        // The suggestion accounts for what is already recorded here, so confirming
        // twice records a total rather than adding a second helping.
        let again = s.suggestedScanQuantity("rice",at:shelf.id)
        s.applyScan([ScanConfirmation(ingredient:"rice",quantity:again,location:shelf.id)])
        XCTAssertEqual(s.stock.filter{ $0.ingredient == "rice" }.count,1)
        XCTAssertEqual(s.shopping().first{ $0.ingredient == "rice" }!.shortage,0)
        XCTAssertEqual(s.stock.first{ $0.ingredient == "rice" }!.quantity,
                       s.shopping().first{ $0.ingredient == "rice" }!.required,accuracy:0.001)
    }
}
