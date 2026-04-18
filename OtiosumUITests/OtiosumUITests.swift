//
//  OtiosumUITests.swift
//  OtiosumUITests
//
//  Created by Marek Skrzelowski on 16/04/2026.
//

import XCTest

final class OtiosumUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTabsAndTodayQuickAdd() throws {
        let app = launchApp()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.tabBars.buttons["Jar"].exists)
        XCTAssertTrue(app.tabBars.buttons["Upcoming"].exists)
        XCTAssertTrue(app.tabBars.buttons["Time"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)

        let quickField = app.textFields["One word is enough"]
        XCTAssertTrue(quickField.waitForExistence(timeout: 2))

        quickField.tap()
        quickField.typeText("nap")
        app.buttons["Place in today"].tap()

        XCTAssertTrue(app.staticTexts["Nap"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testDragJarBallIntoMorningLane() throws {
        let app = launchApp()

        app.tabBars.buttons["Jar"].tap()

        XCTAssertTrue(app.staticTexts["Idea garden"].waitForExistence(timeout: 2))

        let lane = app.buttons["schedule-lane-morning"]
        XCTAssertTrue(lane.waitForExistence(timeout: 2))
        lane.tap()

        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.textFields["One word is enough"].waitForExistence(timeout: 2))
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
