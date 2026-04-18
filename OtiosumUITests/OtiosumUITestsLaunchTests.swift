//
//  OtiosumUITestsLaunchTests.swift
//  OtiosumUITests
//
//  Created by Marek Skrzelowski on 16/04/2026.
//

import XCTest

final class OtiosumUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST")
        app.launchArguments.append("-ApplePersistenceIgnoreState")
        app.launchArguments.append("YES")

        // Clear any stale app instance so SpringBoard doesn't deny a second launch request.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
