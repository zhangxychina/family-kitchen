import XCTest

final class FamilyKitchenUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-tests"]
        app.launch()
    }

    // MARK: - Getting around

    /// SwiftUI only builds the rows of a long list as they come into view, so an
    /// element further down does not exist until something scrolls to it. Every
    /// helper here scrolls first and asks afterwards.
    @discardableResult
    private func reveal(_ element: XCUIElement, swipes: Int = 8) -> Bool {
        if element.exists && element.isHittable { return true }
        dismissKeyboard()
        for _ in 0..<swipes {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    /// The keyboard covers the bottom third of the screen, which is where the button
    /// you were about to press usually is. Tapping the navigation bar puts it away
    /// without scrolling anything.
    /// A text box found by the words printed in it. A multi-line `TextField` is read
    /// out as a text view rather than a text field, so asking for one kind only is
    /// asking about SwiftUI's internals instead of about the screen.
    private func writingBox(placeholder: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "placeholderValue == %@ OR identifier == %@ OR label == %@",
                        placeholder, placeholder, placeholder)).firstMatch
    }

    private func dismissKeyboard() {
        let keyboard = app.keyboards.element
        guard keyboard.exists else { return }
        for key in ["Return", "return", "Done", "done", "go"] {
            let button = keyboard.buttons[key]
            if button.exists && button.isHittable { button.tap(); break }
        }
        _ = keyboard.waitForNonExistence(timeout: 3)
    }

    /// A row whose words the family would recognise. Rows built from several `Text`
    /// views — every settings row, every dish — are read out as one run-on label, so
    /// matching on the whole label is matching on an implementation detail.
    private func row(containing text: String) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func tapRow(containing text: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = row(containing: text)
        XCTAssertTrue(reveal(target), "could not reach a row containing “\(text)”", file: file, line: line)
        target.tap()
    }

    private func planTheWeek(file: StaticString = #filePath, line: UInt = #line) {
        app.tabBars.buttons["Week"].tap()
        let plan = app.buttons["planWeek"]
        XCTAssertTrue(plan.waitForExistence(timeout: 15), "the planning button never appeared", file: file, line: line)
        plan.tap()
        // The header at the top of the list is the first thing a planned week shows.
        XCTAssertTrue(app.buttons["confirmAllMeals"].waitForExistence(timeout: 15),
                      "planning produced no week", file: file, line: line)
    }

    private func openSettings(_ section: String) {
        app.tabBars.buttons["Kitchen"].tap()
        app.buttons["openSettings"].tap()
        tapRow(containing: section)
    }

    // MARK: - The week, the list, and what persists

    func testCatalogFiltersAndBilingualSearch() {
        app.tabBars.buttons["Recipes"].tap()
        XCTAssertTrue(app.segmentedControls["recipeCategory"].waitForExistence(timeout: 15))
        app.segmentedControls.buttons["Dinner"].tap()
        XCTAssertTrue(app.staticTexts["56 of 76 dishes · 56 dinners + 20 breakfasts"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Breakfast"].tap()
        XCTAssertTrue(app.staticTexts["20 of 76 dishes · 56 dinners + 20 breakfasts"].exists)
        app.segmentedControls.buttons["All"].tap()
        // The search field hides under the navigation bar until the list is pulled down.
        let search = app.searchFields.firstMatch
        if !search.exists { app.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 5), "the recipe search field should be reachable")
        search.tap(); search.typeText("香蕉")
        let banana = app.staticTexts["Banana & berry oats"]
        XCTAssertTrue(banana.waitForExistence(timeout: 5), "Chinese search must find an English-named dish")
    }

    func testPlanShoppingAndPersistence() {
        planTheWeek()
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.staticTexts["Some meals still need parent approval. List is provisional."].waitForExistence(timeout: 15))
        let buy = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Mark ")).firstMatch
        XCTAssertTrue(buy.waitForExistence(timeout: 10)); buy.tap()
        let putAway = app.buttons["Put away · 1 waiting"]
        XCTAssertTrue(reveal(putAway), "one purchase is now waiting for a shelf")
        // A purchase survives the app being killed.
        app.terminate(); app.launchArguments = ["--ui-testing"]; app.launch()
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.buttons["Put away · 1 waiting"].waitForExistence(timeout: 15))
        app.buttons["Put away · 1 waiting"].tap()
        let confirm = app.buttons["Placed here — confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertFalse(confirm.isEnabled, "nothing can be stored until a shelf is chosen")
    }

    func testPlanningLeadsToShoppingWithoutHunting() {
        XCTAssertTrue(app.buttons["todayPlanWeek"].waitForExistence(timeout: 15))
        app.buttons["todayPlanWeek"].tap()
        let plan = app.buttons["planWeek"]
        XCTAssertTrue(plan.waitForExistence(timeout: 15))
        plan.tap()
        XCTAssertTrue(app.buttons["confirmAllMeals"].waitForExistence(timeout: 15))
        app.buttons["confirmAllMeals"].tap()
        // The hand-off to the groceries sits below the seven days of the week.
        let goShopping = app.buttons["goShopping"]
        XCTAssertTrue(reveal(goShopping, swipes: 14), "the week should hand the family to the list")
        goShopping.tap()
        XCTAssertTrue(app.navigationBars["Shopping"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Some meals still need parent approval. List is provisional."].exists)
    }

    func testShopCheckIsReachableFromTheList() {
        planTheWeek()
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.buttons["openShopCheck"].waitForExistence(timeout: 15))
        app.buttons["openShopCheck"].tap()
        XCTAssertTrue(app.navigationBars["Check before you shop"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["shopCheckConfirm"].exists, "nothing photographed, nothing to confirm")
    }

    func testAddingAFamilyDish() {
        app.tabBars.buttons["Recipes"].tap()
        app.buttons["addDish"].tap()
        let name = app.textFields["English name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap(); name.typeText("Grandma noodles")
        dismissKeyboard()
        // The sheet is long: two names, a link, the ingredient rows, then the steps.
        let step = writingBox(placeholder: "中文步骤 1")
        XCTAssertTrue(reveal(step, swipes: 20), "could not reach the first recipe step.\n\(app.debugDescription)")
        step.tap(); step.typeText("把面煮熟")
        dismissKeyboard()
        let save = app.buttons["Save this dish"]
        XCTAssertTrue(reveal(save)); save.tap()
        XCTAssertTrue(app.staticTexts["Grandma noodles"].waitForExistence(timeout: 10))
    }

    func testAddingAFamilyMemberActuallyAdds() {
        openSettings("Family & portions")
        let name = app.textFields["Their name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap(); name.typeText("Mia")
        let add = app.buttons["addFamilyMember"]
        XCTAssertTrue(reveal(add)); XCTAssertTrue(add.isEnabled)
        add.tap()
        XCTAssertTrue(app.staticTexts["Mia"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["addFamilyMember"].isEnabled, "the field should clear after adding")
    }

    func testAddingAFridgeAndSayingWhichRoomItIsIn() {
        // Two fridges in one house is ordinary, and which room each stands in is the
        // part the family actually uses to tell them apart.
        openSettings("Where food lives")
        let addFridge = app.buttons["addAppliance-fridge"]
        XCTAssertTrue(reveal(addFridge)); addFridge.tap()
        let name = app.textFields["newApplianceName"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap(); name.typeText("Garage fridge")
        dismissKeyboard()
        let garage = app.buttons["Garage"]
        XCTAssertTrue(reveal(garage), "the suggested rooms should be reachable")
        garage.tap()
        let confirm = app.buttons["confirmAddAppliance"]
        XCTAssertTrue(reveal(confirm)); confirm.tap()
        // The sheet closes, and the appliance list behind it now names the new fridge.
        XCTAssertTrue(app.buttons["addAppliance-fridge"].waitForExistence(timeout: 10))
        let named = app.staticTexts["Garage fridge"]
        XCTAssertTrue(reveal(named), "the new fridge should be listed")
        XCTAssertTrue(app.staticTexts["Garage"].exists, "the room is shown beside the appliance")
    }

    // MARK: - Saying and typing a change

    /// Nonsense of the kind an English recogniser really does return, confidently,
    /// when the person in front of it is speaking Mandarin.
    private let mishearing = "jah lee yee jing yo who law bo luh"

    /// Plans a week, then relaunches with a reading already in hand.
    ///
    /// There is no microphone in a simulator and no offline recogniser, so Apple's
    /// part is replaced — and only Apple's part. Everything from "here is what each
    /// ear heard" to "the shopping list changed" is the app's own code running for
    /// real. What this cannot show is whether the words were heard correctly; that
    /// still needs a real iPhone.
    private func relaunchHearing(_ readings: [String], planFirst: Bool = true) {
        if planFirst { planTheWeek() }
        app.terminate()
        app.launchArguments = ["--ui-testing"] + readings.map { "--voice-heard=" + $0 }
        app.launch()
    }

    /// Taps the microphone, then taps it again to finish — the real two-tap gesture.
    private func speak() {
        let mic = app.buttons["kitchenChatMic"]
        XCTAssertTrue(mic.waitForExistence(timeout: 15))
        XCTAssertTrue(mic.isEnabled, "the microphone button must be live when the phone can listen")
        mic.tap()
        XCTAssertTrue(app.staticTexts["Listening · 正在听"].waitForExistence(timeout: 10))
        mic.tap()
    }

    func testTypingAChangeTicksTheShoppingLineOff() {
        planTheWeek()
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.buttons["openKitchenChat"].waitForExistence(timeout: 15))
        app.buttons["openKitchenChat"].tap()
        let field = app.textFields["kitchenChatField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap(); field.typeText("we already have carrots at home")
        app.buttons["kitchenChatSend"].tap()
        let apply = app.buttons["kitchenChatApply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 10), "nothing happens until someone confirms")
        apply.tap()
        XCTAssertTrue(app.staticTexts["Done · 已完成"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        let covered = app.staticTexts["Already in your kitchen ✓"]
        XCTAssertTrue(reveal(covered, swipes: 14),
                      "the line reads as covered and sits under Nothing to buy")
    }

    func testMandarinWinsOverAConfidentEnglishMishearing() {
        relaunchHearing(["en-US:0.93:" + mishearing, "zh-CN:0.55:家里已经有胡萝卜了"])
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.buttons["openKitchenChat"].waitForExistence(timeout: 15))
        app.buttons["openKitchenChat"].tap()
        speak()
        // The ear that understood the kitchen is believed, not the surer one.
        XCTAssertTrue(app.staticTexts["Heard in Mandarin · 中文"].waitForExistence(timeout: 15),
                      "the English reading was more confident and still must not win")
        XCTAssertTrue(app.staticTexts["“家里已经有胡萝卜了”"].exists)
        let apply = app.buttons["kitchenChatApply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 10), "speaking changes nothing until it is confirmed")
        apply.tap()
        XCTAssertTrue(app.staticTexts["Done · 已完成"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        let covered = app.staticTexts["Already in your kitchen ✓"]
        XCTAssertTrue(reveal(covered, swipes: 14), "the carrots are ticked off and moved down")
    }

    func testTheOtherEarIsOneTapAway() {
        // The mirror image: an English sentence, and a Mandarin recogniser producing
        // syllables. The losing reading stays on screen to be chosen instead.
        relaunchHearing(["en-US:0.44:we already have carrots at home", "zh-CN:0.90:为奥瑞迪哈夫凯罗兹"])
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.buttons["openKitchenChat"].waitForExistence(timeout: 15))
        app.buttons["openKitchenChat"].tap()
        speak()
        XCTAssertTrue(app.staticTexts["Heard in English · 英文"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Also heard · 另一种听法"].exists)
        let other = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "为奥瑞迪")).firstMatch
        XCTAssertTrue(other.exists, "the reading that lost is offered, not discarded")
        other.tap()
        // Taking the other reading gives an honest shrug rather than a change.
        XCTAssertTrue(app.staticTexts["Heard in Mandarin · 中文"].waitForExistence(timeout: 10))
    }

    func testSpokenSwapThatFitsTwoDishesAsksBeforeChanging() {
        relaunchHearing(["zh-CN:0.80:周三晚餐换成咖喱"])
        app.tabBars.buttons["Week"].tap()
        XCTAssertTrue(app.buttons["openKitchenChat"].waitForExistence(timeout: 15))
        app.buttons["openKitchenChat"].tap()
        speak()
        // Two curries fit the word, so the family picks rather than the app guessing.
        let curry = row(containing: "Mild chicken curry")
        XCTAssertTrue(curry.waitForExistence(timeout: 15), "an ambiguous dish must become a question")
        XCTAssertTrue(row(containing: "chickpea").exists, "both curries are offered")
        XCTAssertFalse(app.buttons["kitchenChatApply"].exists, "nothing to confirm until a dish is chosen")
        curry.tap()
        let apply = app.buttons["kitchenChatApply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 10))
        apply.tap()
        XCTAssertTrue(app.staticTexts["Done · 已完成"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        let onTheWeek = app.staticTexts["Mild chicken curry"]
        XCTAssertTrue(reveal(onTheWeek, swipes: 14), "the chosen dish is on the week")
    }

    func testTakingBackTheLastSpokenChange() {
        relaunchHearing(["zh-CN:0.80:家里已经有胡萝卜了"])
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.buttons["openKitchenChat"].waitForExistence(timeout: 15))
        app.buttons["openKitchenChat"].tap()
        speak()
        let apply = app.buttons["kitchenChatApply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 15))
        apply.tap()
        let undo = app.buttons["Undo · 撤销"]
        XCTAssertTrue(undo.waitForExistence(timeout: 10))
        undo.tap()
        XCTAssertTrue(app.buttons["kitchenChatApply"].waitForExistence(timeout: 10),
                      "undone, and offered again")
        app.buttons["Done"].tap()
        XCTAssertFalse(app.staticTexts["Already in your kitchen ✓"].exists,
                       "the carrots are back on the list")
    }

    func testAPhoneThatCannotListenOfflineSaysSoAndStillTakesTyping() {
        // No scripted reading here, so this is whatever the machine can really do.
        // Either way the contract is the same: never a dead button with no reason.
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.buttons["openKitchenChat"].waitForExistence(timeout: 15))
        app.buttons["openKitchenChat"].tap()
        let mic = app.buttons["kitchenChatMic"]
        XCTAssertTrue(mic.waitForExistence(timeout: 15))
        if !mic.isEnabled {
            let explained = app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS %@", "cannot recognise speech offline")).firstMatch
            XCTAssertTrue(explained.exists, "a microphone that cannot work must say why")
        }
        // Typing is always available, whatever the microphone can do.
        let field = app.textFields["kitchenChatField"]
        field.tap(); field.typeText("hello")
        app.buttons["kitchenChatSend"].tap()
        XCTAssertTrue(app.staticTexts["“hello”"].waitForExistence(timeout: 10))
    }

    func testRecipeScrollingPerformance() {
        app.tabBars.buttons["Recipes"].tap()
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(), XCTCPUMetric()]) {
            for _ in 0..<5 { app.swipeUp() }
            for _ in 0..<5 { app.swipeDown() }
        }
    }
}
