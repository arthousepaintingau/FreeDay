import XCTest

/// Step 11 product QA walkthrough. Captures screenshots for visual review.
final class Step11ProductQATests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testThirtySecondFirstLaunchClarity() {
        XCTAssertTrue(app.staticTexts["Know when you can say YES."].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["home-find-free-days"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["home-quick-check"].exists)
        XCTAssertTrue(app.buttons["home-whats-coming"].exists)
        XCTAssertTrue(app.buttons["Add Project"].exists)
        XCTAssertFalse(app.buttons["Find Available Days"].exists)
        shot("01-home")

        app.buttons["home-find-free-days"].tap()
        XCTAssertTrue(app.navigationBars["Find Free Days"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["How many days do you need?"].exists)
        XCTAssertTrue(app.buttons["find-free-days-search"].exists)
        shot("02-find-free-days")
        app.buttons["Close"].tap()

        let quick = app.buttons["home-quick-check"]
        XCTAssertTrue(quick.waitForExistence(timeout: 4))
        quick.tap()
        XCTAssertTrue(app.navigationBars["Quick Check"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["How long is the job?"].exists)
        XCTAssertTrue(app.buttons["quick-check-specific-date"].waitForExistence(timeout: 2))
        shot("03-quick-check")

        app.buttons["quick-check-specific-date"].tap()
        XCTAssertTrue(app.buttons["quick-check-specific-start"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["quick-check-from-today"].waitForExistence(timeout: 2))
        shot("04-specific-date")
        app.buttons["Close"].tap()

        let coming = app.buttons["home-whats-coming"]
        XCTAssertTrue(coming.waitForExistence(timeout: 4))
        coming.tap()
        XCTAssertTrue(
            app.navigationBars["What’s Coming?"].waitForExistence(timeout: 4)
                || app.navigationBars["What's Coming?"].waitForExistence(timeout: 1)
        )
        XCTAssertTrue(
            app.staticTexts["Light"].waitForExistence(timeout: 2)
                || app.otherElements["coming-busy-meter"].waitForExistence(timeout: 2)
        )
        shot("05-whats-coming")
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["Add Project"].tap()
        XCTAssertTrue(app.navigationBars["Add Project"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Project name"].waitForExistence(timeout: 2) || app.textFields["Interior painting"].exists)
        shot("06-add-project")
        app.buttons["Cancel"].tap()
    }

    func testNavigationCalendarJobsAndScenarioFlows() {
        tapTab("Calendar")
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.segmentedControls.buttons["Week"].exists)
        shot("07-calendar-week")
        app.segmentedControls.buttons["Month"].tap()
        shot("08-calendar-month")

        tapTab("Jobs")
        XCTAssertTrue(app.staticTexts["No projects yet."].waitForExistence(timeout: 4))
        shot("09-jobs-empty")

        tapTab("Home")
        app.buttons["home-find-free-days"].tap()
        app.buttons["Increase days"].tap()
        app.buttons["Increase days"].tap()
        app.buttons["find-free-days-search"].tap()
        XCTAssertTrue(app.buttons["find-free-days-next-slot"].waitForExistence(timeout: 4))
        shot("10-find-five-days-result")
        app.buttons["Close"].tap()

        app.buttons["home-quick-check"].tap()
        XCTAssertTrue(app.navigationBars["Quick Check"].waitForExistence(timeout: 4))
        app.buttons["quick-check-specific-date"].tap()
        shot("11-specific-date-yes")
        app.buttons["Close"].tap()

        addBookedToday(name: "Interior painting", customer: "Smith House")
        shot("12-home-after-booked")

        app.buttons["home-quick-check"].tap()
        app.buttons["quick-check-specific-date"].tap()
        XCTAssertTrue(
            app.otherElements["quick-check-specific-unavailable"].waitForExistence(timeout: 4)
                || app.staticTexts["😅 Not available."].waitForExistence(timeout: 2)
        )
        shot("13-specific-date-unavailable")
        app.buttons["Close"].tap()

        app.buttons["home-whats-coming"].tap()
        shot("14-coming-after-booked")
        app.navigationBars.buttons.firstMatch.tap()

        tapTab("Calendar")
        shot("15-calendar-booked")
        app.segmentedControls.buttons["Month"].tap()
        shot("16-calendar-month-booked")

        tapTab("Jobs")
        let job = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Smith House'")).firstMatch
        XCTAssertTrue(job.waitForExistence(timeout: 4) || app.staticTexts["Smith House"].waitForExistence(timeout: 2))
        shot("17-jobs-booked")
        if job.exists {
            job.tap()
        } else {
            app.staticTexts["Smith House"].tap()
        }
        XCTAssertTrue(app.buttons["project-reschedule"].waitForExistence(timeout: 4))
        XCTAssertTrue(
            app.staticTexts["1 day"].waitForExistence(timeout: 2),
            "One-day jobs must not display as '1 days'"
        )
        shot("18-project-detail")
        app.buttons["project-reschedule"].tap()
        XCTAssertTrue(app.navigationBars["Reschedule"].waitForExistence(timeout: 4))
        shot("19-reschedule")
        app.buttons["reschedule-cancel"].tap()
    }

    func testDynamicTypeDoesNotClipHomeActions() {
        app.terminate()
        app.launchArguments = [
            "-ui-testing",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityL"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["home-find-free-days"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["home-quick-check"].exists)
        XCTAssertTrue(app.buttons["Add Project"].exists)
        shot("20-home-dynamic-type")
        app.buttons["home-quick-check"].tap()
        XCTAssertTrue(app.navigationBars["Quick Check"].waitForExistence(timeout: 4))
        shot("21-quick-check-dynamic-type")
        app.buttons["Close"].tap()
        tapTab("Calendar")
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 4))
        shot("22-calendar-dynamic-type")
    }

    private func addBookedToday(name: String, customer: String) {
        tapTab("Home")
        app.buttons["Add Project"].tap()
        XCTAssertTrue(app.navigationBars["Add Project"].waitForExistence(timeout: 4))
        let nameField = app.textFields["Interior painting"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 4))
        nameField.tap()
        nameField.typeText(name)
        app.textFields["Smith House"].tap()
        app.textFields["Smith House"].typeText(customer)
        app.navigationBars["Add Project"].tap()
        if app.segmentedControls.buttons["Booked"].exists {
            app.segmentedControls.buttons["Booked"].tap()
        }
        app.buttons["Save Project"].tap()
        XCTAssertTrue(app.buttons["home-find-free-days"].waitForExistence(timeout: 4))
    }

    private func tapTab(_ name: String) {
        let tabBarButton = app.tabBars.buttons[name]
        if tabBarButton.waitForExistence(timeout: 1) {
            tabBarButton.tap()
            return
        }
        let button = app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 4), "Missing \(name) tab")
        button.tap()
    }

    private func shot(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        let dir = URL(fileURLWithPath: "/tmp/freeday-step11")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: dir.appendingPathComponent("\(name).png"))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
