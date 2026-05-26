import XCTest

final class OtiosumUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testQuickAddKeepsKeyboardActiveForMultipleLetters() throws {
        let app = launchApp()

        let quickField = app.textFields["quick-add-field"]
        XCTAssertTrue(quickField.waitForExistence(timeout: 5))

        focusTextField(quickField, in: app)
        quickField.typeText("abc")

        XCTAssertTrue(app.keyboards.firstMatch.exists)
        let value = quickField.value as? String
        XCTAssertEqual(value, "abc")
    }

    @MainActor
    func testAddToTimelineWithEnterClearsInput() throws {
        let app = launchApp()

        let quickField = app.textFields["quick-add-field"]
        XCTAssertTrue(quickField.waitForExistence(timeout: 5))
        focusTextField(quickField, in: app)
        quickField.typeText("focus sprint\n")

        XCTAssertTrue(waitForQuickAddFieldToClear(quickField, timeout: 5))
    }

    @MainActor
    func testQuickAddToLaterClearsInput() throws {
        let app = launchApp()

        let quickField = app.textFields["quick-add-field"]
        XCTAssertTrue(quickField.waitForExistence(timeout: 5))
        focusTextField(quickField, in: app)
        quickField.typeText("later writing")
        app.buttons["quick-add-later"].tap()
        XCTAssertTrue(waitForQuickAddFieldToClear(quickField, timeout: 5))
    }

    @MainActor
    func testSettingsAccessFromToolbar() throws {
        let app = launchApp()

        let settingsButton = app.buttons["today-open-settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let doneButton = app.buttons["settings-done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()
    }

    @MainActor
    func testLaunchScreenshot() throws {
        let app = launchApp()
        sleep(3)
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "launch-screenshot"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testTimelineQuickActionMarkDone() throws {
        let app = launchApp(extraArguments: ["UITEST_TIMELINE_TASK"])

        let taskIdentifier = "ui-timeline-task"
        let task = app.otherElements["timeline-task-\(taskIdentifier)"]
        XCTAssertTrue(task.waitForExistence(timeout: 6))
        XCTAssertTrue(waitForElement(task, keyPath: \.isHittable, toBe: true, timeout: 3))

        let startButton = task.buttons["timeline-task-start-\(taskIdentifier)"]
        if startButton.exists {
            startButton.tap()
        }

        let markDoneButton = task.buttons["timeline-task-done-\(taskIdentifier)"]
        XCTAssertTrue(markDoneButton.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForElement(markDoneButton, keyPath: \.isHittable, toBe: true, timeout: 3))
        markDoneButton.tap()

        XCTAssertTrue(app.buttons["timeline-task-undo-\(taskIdentifier)"].waitForExistence(timeout: 3))
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
        app.launchArguments.append("-ApplePersistenceIgnoreState")
        app.launchArguments.append("YES")
        app.launchArguments.append(contentsOf: extraArguments)
        app.launch()
        return app
    }

    private func waitForElement(
        _ element: XCUIElement,
        keyPath: KeyPath<XCUIElement, Bool>,
        toBe expectedValue: Bool,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate { element, _ in
            guard let element = element as? XCUIElement else { return false }
            return element[keyPath: keyPath] == expectedValue
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func focusTextField(_ field: XCUIElement, in app: XCUIApplication) {
        field.tap()
        let keyboard = app.keyboards.firstMatch
        if keyboard.waitForExistence(timeout: 3) { return }
        // Hardware keyboard race: the first tap can land before SwiftUI installs
        // FocusState as first responder. A coordinate-targeted second tap forces it.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        _ = keyboard.waitForExistence(timeout: 3)
    }

    private func waitForQuickAddFieldToClear(_ field: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { element, _ in
            guard let field = element as? XCUIElement else { return false }
            let value = field.value as? String
            return value == nil || value == "" || value == "One short phrase"
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: field)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

}
