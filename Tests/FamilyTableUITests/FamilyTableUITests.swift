import XCTest

final class FamilyTableUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-tests"]
        app.launch()
    }
    func testCatalogFiltersAndBilingualSearch() {
        app.tabBars.buttons["Recipes"].tap()
        XCTAssertTrue(app.segmentedControls["recipeCategory"].waitForExistence(timeout:5))
        app.segmentedControls.buttons["Dinner"].tap()
        XCTAssertTrue(app.staticTexts["56 of 76 dishes · 56 dinners + 20 breakfasts"].waitForExistence(timeout:3))
        app.segmentedControls.buttons["Breakfast"].tap()
        XCTAssertTrue(app.staticTexts["20 of 76 dishes · 56 dinners + 20 breakfasts"].exists)
        let search = app.searchFields.firstMatch
        search.tap(); search.typeText("香蕉")
        XCTAssertTrue(app.staticTexts["Banana & berry oats"].waitForExistence(timeout:3))
        app.staticTexts["Banana & berry oats"].tap()
        XCTAssertTrue(app.staticTexts["Ingredients & locations · 食材与位置"].waitForExistence(timeout:3))
    }
    func testPlanShoppingAndPersistence() {
        app.tabBars.buttons["Week"].tap()
        XCTAssertTrue(app.buttons["planWeek"].waitForExistence(timeout:5))
        app.buttons["planWeek"].tap()
        XCTAssertTrue(app.buttons["confirmAllMeals"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["goShopping"].exists)
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.staticTexts["Some meals still need parent approval. List is provisional."].waitForExistence(timeout:5))
        let buy = app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@", "Mark ")).firstMatch
        XCTAssertTrue(buy.waitForExistence(timeout:5)); buy.tap()
        XCTAssertTrue(app.buttons["Put away · 1 waiting"].exists)
        app.terminate(); app.launchArguments = ["--ui-testing"]; app.launch()
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.buttons["Put away · 1 waiting"].waitForExistence(timeout:5))
        app.buttons["Put away · 1 waiting"].tap()
        XCTAssertTrue(app.buttons["Placed here — confirm"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["Placed here — confirm"].isEnabled)
    }
    func testPlanningLeadsToShoppingWithoutHunting() {
        // Today offers the planning step, and the list hands the family to the groceries.
        XCTAssertTrue(app.buttons["todayPlanWeek"].waitForExistence(timeout:5))
        app.buttons["todayPlanWeek"].tap()
        XCTAssertTrue(app.buttons["planWeek"].waitForExistence(timeout:5))
        app.buttons["planWeek"].tap()
        app.buttons["confirmAllMeals"].tap()
        app.buttons["goShopping"].tap()
        XCTAssertTrue(app.navigationBars["Shopping"].waitForExistence(timeout:5))
        XCTAssertFalse(app.staticTexts["Some meals still need parent approval. List is provisional."].exists)
    }
    func testAddingAFamilyDish() {
        app.tabBars.buttons["Recipes"].tap()
        app.buttons["addDish"].tap()
        XCTAssertTrue(app.textFields["English name"].waitForExistence(timeout:5))
        app.textFields["English name"].tap(); app.textFields["English name"].typeText("Grandma noodles")
        let step = app.textFields["中文步骤 1"]
        step.tap(); step.typeText("把面煮熟")
        app.buttons["Save this dish"].tap()
        XCTAssertTrue(app.staticTexts["Grandma noodles"].waitForExistence(timeout:5))
    }
    func testRecipeScrollingPerformance() {
        app.tabBars.buttons["Recipes"].tap()
        measure(metrics:[XCTClockMetric(), XCTMemoryMetric(), XCTCPUMetric()]) {
            for _ in 0..<5 { app.swipeUp() }
            for _ in 0..<5 { app.swipeDown() }
        }
    }
}
