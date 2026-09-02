import XCTest

final class CalendarFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testWeekNavigationAndMonthView() {
        openCalendar()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["calendar-previous"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["calendar-today"].exists)
        XCTAssertTrue(app.buttons["calendar-next"].exists)

        app.buttons["calendar-next"].tap()
        XCTAssertTrue(app.buttons["calendar-today"].isEnabled)
        app.buttons["calendar-today"].tap()

        app.buttons["calendar-previous"].tap()
        app.buttons["calendar-today"].tap()

        let month = app.segmentedControls.buttons["Month"]
        XCTAssertTrue(month.waitForExistence(timeout: 2))
        month.tap()
        XCTAssertTrue(app.buttons["calendar-next"].waitForExistence(timeout: 2))
        app.buttons["calendar-next"].tap()
        XCTAssertTrue(app.buttons["calendar-today"].isEnabled)
        app.buttons["calendar-today"].tap()
    }

    func testFreeDayOpensAddProjectWithUseThisDay() {
        openCalendar()
        let freeDay = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Free.'")).firstMatch
        XCTAssertTrue(freeDay.waitForExistence(timeout: 4))
        freeDay.tap()

        let useThisDay = app.buttons["Use this day"]
        XCTAssertTrue(useThisDay.waitForExistence(timeout: 3))
        useThisDay.tap()
        XCTAssertTrue(app.navigationBars["Add Project"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["This job is scheduled."].waitForExistence(timeout: 4))
    }

    func testBookedQuotedCompletedAndMultiDay() {
        openAddProjectFromHome()
        fillProject(name: "Quote paint", customer: "Johnson House", status: "Quoted", days: 5)
        enableQuotedStartDate()
        app.buttons["Save Project"].tap()

        openAddProjectFromHome()
        fillProject(name: "Interior painting", customer: "Smith House", status: "Booked", days: 3)
        app.buttons["Save Project"].tap()

        openCalendar()
        var booked = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Booked' AND label CONTAINS 'Smith House'")).firstMatch
        if !booked.waitForExistence(timeout: 2) {
            app.buttons["calendar-next"].tap()
            booked = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Booked' AND label CONTAINS 'Smith House'")).firstMatch
        }
        XCTAssertTrue(booked.waitForExistence(timeout: 4), "Multi-day booked work should appear")
        var quoted = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Quoted' AND label CONTAINS 'Johnson House'")).firstMatch
        if !quoted.waitForExistence(timeout: 2) {
            app.buttons["calendar-next"].tap()
            quoted = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Quoted' AND label CONTAINS 'Johnson House'")).firstMatch
        }
        XCTAssertTrue(
            quoted.waitForExistence(timeout: 4),
            "Quoted work should be visible without being labelled booked"
        )
        if app.buttons["calendar-today"].isEnabled {
            app.buttons["calendar-today"].tap()
        }

        app.segmentedControls.buttons["Month"].tap()
        app.segmentedControls.buttons["Week"].tap()

        booked = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Booked' AND label CONTAINS 'Smith House'")).firstMatch
        XCTAssertTrue(booked.waitForExistence(timeout: 2))
        booked.tap()
        XCTAssertTrue(app.staticTexts["Smith House"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 2))

        app.buttons["Mark Completed"].tap()
        XCTAssertTrue(app.staticTexts["🥳 Job done!"].waitForExistence(timeout: 3) || app.staticTexts["Job done!"].waitForExistence(timeout: 1))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertFalse(
            app.buttons.matching(NSPredicate(format: "label CONTAINS 'Booked' AND label CONTAINS 'Smith House'")).firstMatch.waitForExistence(timeout: 1)
        )
    }

    private func openCalendar() {
        dismissSheets()
        tapTab("Calendar")
    }

    private func openAddProjectFromHome() {
        dismissSheets()
        tapTab("Home")
        let add = app.buttons["Add Project"]
        XCTAssertTrue(add.waitForExistence(timeout: 4))
        add.tap()
        XCTAssertTrue(app.navigationBars["Add Project"].waitForExistence(timeout: 4))
    }

    private func dismissSheets() {
        if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
        }
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        }
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

    private func fillProject(name: String, customer: String, status: String, days: Int = 1) {
        let increases = max(days - 1, 0)
        if increases > 0 {
            XCTAssertTrue(app.buttons["Increase days"].waitForExistence(timeout: 4))
            for _ in 0..<increases {
                app.buttons["Increase days"].tap()
            }
        }

        let nameField = app.textFields["Interior painting"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 4))
        nameField.tap()
        nameField.typeText(name)

        let customerField = app.textFields["Smith House"]
        customerField.tap()
        customerField.typeText(customer)
        app.navigationBars["Add Project"].tap()

        if app.segmentedControls.buttons[status].exists {
            app.segmentedControls.buttons[status].tap()
        }
    }

    private func enableQuotedStartDate() {
        let toggle = app.switches["Start date"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 2))
        if (toggle.value as? String) == "0" {
            toggle.tap()
        }
    }
}
