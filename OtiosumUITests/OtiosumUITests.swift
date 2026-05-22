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

        let clearedPredicate = NSPredicate { _, _ in
            let value = quickField.value as? String
            return value == nil || value == "" || value == "One short phrase"
        }
        let expectation = expectation(for: clearedPredicate, evaluatedWith: quickField)
        wait(for: [expectation], timeout: 2)
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
        let startButton = app.buttons["timeline-task-start-\(taskIdentifier)"]
        if startButton.waitForExistence(timeout: 4) == false {
            let timeline = app.scrollViews.firstMatch
            if timeline.waitForExistence(timeout: 2) {
                timeline.swipeUp()
                timeline.swipeDown()
            }
        }
        XCTAssertTrue(startButton.waitForExistence(timeout: 2))

        let markDoneButton = app.buttons["timeline-task-done-\(taskIdentifier)"]
        if markDoneButton.waitForExistence(timeout: 1) == false {
            startButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        if markDoneButton.waitForExistence(timeout: 1) == false && startButton.exists {
            startButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(markDoneButton.waitForExistence(timeout: 5))
        markDoneButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["UITEST", "-ApplePersistenceIgnoreState", "YES"]
            app.launch()
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
