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

        let quickField = app.textFields["Quick add"]
        XCTAssertTrue(quickField.waitForExistence(timeout: 2))

        quickField.tap()
        quickField.typeText("nap")
        app.buttons["now-quick-add-button"].tap()

        XCTAssertTrue(app.tabBars.buttons["Now"].exists)
    }

    @MainActor
    func testQuickAddStartTimePickerFlow() throws {
        let app = launchApp()

        let startButton = app.buttons["now-quick-start-time-button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 2))
        startButton.tap()

        XCTAssertTrue(app.buttons["now-quick-add-button"].exists)
    }

    @MainActor
    func testTimelineQuickActionMarkDone() throws {
        let app = launchApp(extraArguments: ["UITEST_TIMELINE_TASK"])

        let taskIdentifier = "ui-timeline-task"
        let taskElement = app.otherElements["timeline-task-\(taskIdentifier)"]
        XCTAssertTrue(taskElement.waitForExistence(timeout: 10))

        let markDoneButton = app.descendants(matching: .any)["timeline-task-done-\(taskIdentifier)"]
        XCTAssertTrue(markDoneButton.waitForExistence(timeout: 10))
        markDoneButton.tap()

        XCTAssertTrue(taskElement.exists)
    }

    @MainActor
    func testSomedayDrawerAddsItemToNowTimeline() throws {
        let app = launchApp()

        let somedayButton = app.buttons["now-someday-sheet-button"]
        XCTAssertTrue(somedayButton.waitForExistence(timeout: 2))
        somedayButton.tap()

        XCTAssertTrue(app.navigationBars["Someday"].waitForExistence(timeout: 2))
        app.buttons["Done"].tap()

        XCTAssertTrue(app.tabBars.buttons["Now"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            _ = launchApp()
        }
    }

    private func launchApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST")
        app.launchArguments.append(contentsOf: extraArguments)
        app.launch()
        return app
    }
}
