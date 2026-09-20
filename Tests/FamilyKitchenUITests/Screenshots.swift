import XCTest

/// Not an acceptance test. This walks the app and saves the pictures used in the
/// README and on the App Store, so they are regenerated from the running app rather
/// than curated by hand — a screenshot that no longer matches the app is worse than
/// no screenshot.
///
/// Run it against a device seeded with a real-looking kitchen:
/// `scripts/screenshots.py`, which does the seeding, the run and the extraction.
final class FamilyKitchenScreenshots: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Lets the view settle before the shutter, so nothing is caught mid-animation.
    private func settle() {
        _ = app.wait(for: .runningForeground, timeout: 5)
        Thread.sleep(forTimeInterval: 1.2)
    }

    func testCaptureTheFiveScreens() {
        app.launchArguments = []
        app.launch()
        settle()
        capture("01-today")

        app.tabBars.buttons["Week"].tap(); settle()
        capture("02-week")

        app.tabBars.buttons["Recipes"].tap(); settle()
        capture("03-recipes")

        app.tabBars.buttons["Shopping"].tap(); settle()
        capture("04-shopping")
    }

    /// The spoken change, with a reading already in hand — see `VoiceListener
    /// .scriptedReadings` for why this is not a microphone.
    func testCaptureSayingSomething() {
        app.launchArguments = ["--ui-testing", "--voice-heard=en-US:0.93:jah lee yee jing yo who law bo luh",
                               "--voice-heard=zh-CN:0.55:家里已经有胡萝卜了"]
        app.launch()
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.buttons["openKitchenChat"].waitForExistence(timeout: 15))
        app.buttons["openKitchenChat"].tap()
        let mic = app.buttons["kitchenChatMic"]
        XCTAssertTrue(mic.waitForExistence(timeout: 15))
        mic.tap()
        XCTAssertTrue(app.staticTexts["Listening · 正在听"].waitForExistence(timeout: 10))
        settle()
        capture("05-listening")
        mic.tap()
        XCTAssertTrue(app.buttons["kitchenChatApply"].waitForExistence(timeout: 15))
        // Scroll the reading into view: the opening card is long.
        app.swipeUp()
        settle()
        capture("06-understood")
        if app.buttons["kitchenChatApply"].exists { app.buttons["kitchenChatApply"].tap() }
        settle()
        capture("07-done")
    }
}
