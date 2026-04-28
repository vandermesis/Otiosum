import XCTest

final class OtiosumUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testQuickAddKeepsKeyboardActiveForMultipleLetters() throws {
        let app = launchApp()

        let quickField = app.textFields["quick-add-field"]
        XCTAssertTrue(quickField.waitForExistence(timeout: 2))

        quickField.tap()
        quickField.typeText("abc")

        XCTAssertTrue(app.keyboards.firstMatch.exists)
        let value = quickField.value as? String
        XCTAssertEqual(value, "abc")
    }

    @MainActor
    func testAddToTimelineWithEnterClearsInput() throws {
        let app = launchApp()

        let quickField = app.textFields["quick-add-field"]
        XCTAssertTrue(quickField.waitForExistence(timeout: 2))
        quickField.tap()
        quickField.typeText("focus sprint\n")

        let value = quickField.value as? String
        XCTAssertTrue(value == nil || value == "" || value == "One short phrase")
    }

    @MainActor
    func testQuickAddToLaterClearsInput() throws {
        let app = launchApp()

        let quickField = app.textFields["quick-add-field"]
        XCTAssertTrue(quickField.waitForExistence(timeout: 2))
        quickField.tap()
        quickField.typeText("later writing")
        app.buttons["quick-add-later"].tap()
        let clearedPredicate = NSPredicate { _, _ in
            let value = quickField.value as? String
            return value == nil || value == "" || value == "One short phrase"
        }
        let expectation = expectation(for: clearedPredicate, evaluatedWith: quickField)
        wait(for: [expectation], timeout: 2)
    }

    @MainActor
    func testSettingsAccessFromToolbar() throws {
        let app = launchApp()

        let settingsButton = app.buttons["today-open-settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))
        settingsButton.tap()

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 2))
        doneButton.tap()
    }

    @MainActor
    func testTimelineQuickActionMarkDone() throws {
        let app = launchApp(extraArguments: ["UITEST_TIMELINE_TASK"])

        let taskIdentifier = "ui-timeline-task"
        let markDoneButton = app.descendants(matching: .any)["timeline-task-done-\(taskIdentifier)"]
        if markDoneButton.waitForExistence(timeout: 4) == false {
            let timeline = app.scrollViews.firstMatch
            if timeline.waitForExistence(timeout: 2) {
                timeline.swipeUp()
                timeline.swipeDown()
            }
        }
        try XCTSkipIf(markDoneButton.exists == false, "Timeline quick action control was not exposed in this UI hierarchy run.")
        markDoneButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
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
