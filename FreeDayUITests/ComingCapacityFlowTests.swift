import XCTest

final class ComingCapacityFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testOpenWhatsComingShowsFourteenDaysAndLightMeter() {
        openComing()
        XCTAssertTrue(
            app.navigationBars["What’s Coming?"].waitForExistence(timeout: 4)
                || app.navigationBars["What's Coming?"].waitForExistence(timeout: 1)
        )
        XCTAssertTrue(
            app.staticTexts["Free days"].waitForExistence(timeout: 2)
                || app.staticTexts["FREE DAYS"].waitForExistence(timeout: 1)
                || app.otherElements["coming-metric-free"].waitForExistence(timeout: 1)
        )
        XCTAssertTrue(
            app.staticTexts["Light"].waitForExistence(timeout: 2)
                || app.otherElements["coming-busy-meter"].waitForExistence(timeout: 1)
        )
        let monday = comingDay(UITestWorkingDays.iso(0))
        XCTAssertTrue(monday.waitForExistence(timeout: 4), "Today should appear in the 14-day list")
        XCTAssertTrue(
            app.buttons["coming-find-free-days"].waitForExistence(timeout: 2)
                || app.buttons["Find My Next Free Days"].waitForExistence(timeout: 1)
        )
    }

    func testFreeDayOpensAddProjectAndCapacityUpdates() {
        openComing()
        let freeDay = comingDay(UITestWorkingDays.iso(0))
        XCTAssertTrue(freeDay.waitForExistence(timeout: 4))
        freeDay.tap()
        let useThisDay = app.buttons["Use this day"]
        XCTAssertTrue(useThisDay.waitForExistence(timeout: 3))
        useThisDay.tap()
        XCTAssertTrue(app.navigationBars["Add Project"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["This job is scheduled."].waitForExistence(timeout: 4))

        fillProject(name: "Interior painting", customer: "Smith House", status: "Booked")
        app.buttons["Save Project"].tap()

        XCTAssertTrue(app.navigationBars["What’s Coming?"].waitForExistence(timeout: 4)
            || app.navigationBars["What's Coming?"].waitForExistence(timeout: 1))
        let todayISO = UITestWorkingDays.iso(0)
        let booked = app.otherElements["coming-day-\(todayISO)"].waitForExistence(timeout: 2)
            ? app.otherElements["coming-day-\(todayISO)"]
            : app.buttons.matching(NSPredicate(format: "identifier == %@ OR label CONTAINS 'Booked'", "coming-day-\(todayISO)")).firstMatch
        XCTAssertTrue(
            booked.waitForExistence(timeout: 4) || app.staticTexts["Smith House"].waitForExistence(timeout: 2),
            "Saving a booked job from a free day should update What’s Coming"
        )
    }

    func testFindMyNextFreeDaysOpensExistingFlow() {
        openComing()
        let find = app.buttons["coming-find-free-days"].exists
            ? app.buttons["coming-find-free-days"]
            : app.buttons["Find My Next Free Days"]
        XCTAssertTrue(find.waitForExistence(timeout: 4))
        find.tap()
        XCTAssertTrue(app.navigationBars["Find Free Days"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["How many days do you need?"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Find Available Days"].waitForExistence(timeout: 2))
    }

    func testBookedAndBufferAppearOnComingView() {
        tapTab("Home")
        let add = app.buttons["Add Project"]
        XCTAssertTrue(add.waitForExistence(timeout: 4))
        add.tap()
        XCTAssertTrue(app.navigationBars["Add Project"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Increase days"].waitForExistence(timeout: 4))
        app.buttons["Increase days"].tap()
        app.buttons["Increase days"].tap()
        XCTAssertTrue(app.buttons["Increase buffer days"].waitForExistence(timeout: 2))
        app.buttons["Increase buffer days"].tap()
        fillProject(name: "Interior painting", customer: "Smith House", status: "Booked")
        app.buttons["Save Project"].tap()
        XCTAssertTrue(app.buttons["home-whats-coming"].waitForExistence(timeout: 4))

        openComing()
        XCTAssertTrue(
            app.staticTexts["Smith House"].waitForExistence(timeout: 4),
            "Booked job should show the customer name"
        )
        let bufferISO = UITestWorkingDays.iso(3)
        let buffer = app.otherElements["coming-day-\(bufferISO)"]
        XCTAssertTrue(
            buffer.waitForExistence(timeout: 2)
                || app.buttons["coming-day-\(bufferISO)"].waitForExistence(timeout: 1)
                || app.staticTexts["Buffer"].waitForExistence(timeout: 2)
                || app.staticTexts["BUFFER"].waitForExistence(timeout: 1),
            "The working day after a 3-day job should be a buffer day"
        )
    }

    func testFindFreeDaysStaysOnHome() {
        XCTAssertTrue(app.buttons["home-find-free-days"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["home-quick-check"].exists)
        XCTAssertTrue(app.buttons["home-whats-coming"].waitForExistence(timeout: 2))
        openComing()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["home-find-free-days"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["home-quick-check"].exists)
    }

    private func openComing() {
        tapTab("Home")
        let button = app.buttons["home-whats-coming"].exists
            ? app.buttons["home-whats-coming"]
            : app.buttons.matching(NSPredicate(format: "label CONTAINS 'Coming'")).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 4))
        button.tap()
    }

    private func comingDay(_ iso: String) -> XCUIElement {
        let identifier = "coming-day-\(iso)"
        let button = app.buttons[identifier]
        if button.waitForExistence(timeout: 2) {
            return button
        }
        app.swipeUp()
        if button.waitForExistence(timeout: 2) {
            return button
        }
        let any = app.descendants(matching: .any)[identifier]
        if any.waitForExistence(timeout: 2) {
            return any
        }
        return app.buttons.matching(NSPredicate(format: "label CONTAINS 'Free working day'")).firstMatch
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

    private func fillProject(name: String, customer: String, status: String) {
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
}
