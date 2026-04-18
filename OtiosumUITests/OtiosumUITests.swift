import XCTest

final class OtiosumUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTabsAndNowQuickAdd() throws {
        let app = launchApp()

        XCTAssertTrue(app.tabBars.buttons["Now"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.tabBars.buttons["Future"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)

        let quickField = app.textFields["One word is enough"]
        XCTAssertTrue(quickField.waitForExistence(timeout: 2))

        quickField.tap()
        quickField.typeText("nap")
        app.buttons["now-quick-add-button"].tap()

        XCTAssertTrue(app.tabBars.buttons["Now"].exists)
    }

    @MainActor
    func testSomedayDrawerAddsItemToNowTimeline() throws {
        let app = launchApp()

        let expandButton = app.buttons["Expand"]
        XCTAssertTrue(expandButton.waitForExistence(timeout: 2))
        expandButton.tap()

        XCTAssertTrue(app.buttons["Someday"].waitForExistence(timeout: 2))
        app.buttons["Someday"].tap()

        XCTAssertTrue(app.tabBars.buttons["Now"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            _ = launchApp()
        }
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST")
        app.launch()
        return app
    }
}
