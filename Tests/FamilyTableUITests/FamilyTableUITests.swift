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
        app.segmentedControls.buttons["Dinner (56)"].tap()
        XCTAssertTrue(app.staticTexts["56 meals · 56 dinners + 20 breakfasts"].exists)
        app.segmentedControls.buttons["Breakfast (20)"].tap()
        XCTAssertTrue(app.staticTexts["20 meals · 56 dinners + 20 breakfasts"].exists)
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
    func testRecipeScrollingPerformance() {
        app.tabBars.buttons["Recipes"].tap()
        measure(metrics:[XCTClockMetric(), XCTMemoryMetric(), XCTCPUMetric()]) {
            for _ in 0..<5 { app.swipeUp() }
            for _ in 0..<5 { app.swipeDown() }
        }
    }
}
