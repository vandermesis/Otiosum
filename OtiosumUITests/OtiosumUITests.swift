import XCTest

final class OtiosumUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testQuickAddKeepsKeyboardActiveForMultipleLetters() throws {
        let app = launchApp()

        let quickField = app.textFields["Quick add"]
        XCTAssertTrue(quickField.waitForExistence(timeout: 2))

        quickField.tap()
        quickField.typeText("abc")

        XCTAssertTrue(app.keyboards.firstMatch.exists)
        let value = quickField.value as? String
        XCTAssertEqual(value, "abc")
    }

    @MainActor
    func testAddToTimelineShowsPlacementMode() throws {
        let app = launchApp()

        let quickField = app.textFields["Quick add"]
        XCTAssertTrue(quickField.waitForExistence(timeout: 2))
        quickField.tap()
        quickField.typeText("focus sprint\n")

        XCTAssertTrue(app.buttons["timeline-draft-confirm"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testQuickAddToSomedayClearsInputAndDoesNotEnterPlacementMode() throws {
        let app = launchApp()

        let quickField = app.textFields["Quick add"]
        XCTAssertTrue(quickField.waitForExistence(timeout: 2))
        quickField.tap()
        quickField.typeText("someday writing")

        if app.keyboards.firstMatch.exists {
            app.navigationBars.firstMatch.tap()
        }
        app.buttons["now-someday-sheet-button"].tap()

        XCTAssertFalse(app.buttons["timeline-draft-confirm"].exists)
        let value = quickField.value as? String
        XCTAssertEqual(value, "Quick add")
    }

    @MainActor
    func testSettingsAccessFromToolbar() throws {
        let app = launchApp()

        let settingsButton = app.buttons["now-open-settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))
        settingsButton.tap()

        XCTAssertTrue(app.staticTexts["Healthy rhythm"].waitForExistence(timeout: 2))
        app.buttons["Done"].tap()
    }

    @MainActor
    func testTimelineQuickActionMarkDone() throws {
        let app = launchApp(extraArguments: ["UITEST_TIMELINE_TASK"])

        let taskIdentifier = "ui-timeline-task"
        let taskElement = app.otherElements["timeline-task-\(taskIdentifier)"]
        XCTAssertTrue(taskElement.waitForExistence(timeout: 10))

        let markDoneButton = app.descendants(matching: .any)["timeline-task-done-\(taskIdentifier)"]
        XCTAssertTrue(markDoneButton.waitForExistence(timeout: 10))
        markDoneButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(taskElement.exists)
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
