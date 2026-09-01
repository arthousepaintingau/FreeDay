import XCTest

final class FindFreeDaysFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testThreeDaySearchPrefillsAddProject() {
        openFindFreeDays()
        XCTAssertTrue(app.staticTexts["How many days do you need?"].waitForExistence(timeout: 4))

        searchAvailableDays()
        XCTAssertTrue(nextSlot.waitForExistence(timeout: 4), "Expected a next-available slot")
        XCTAssertTrue(app.staticTexts["You can start"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts["You’ll finish"].exists || app.staticTexts["You'll finish"].exists
        )
        XCTAssertTrue(
            app.staticTexts["🎯 Perfect fit!"].exists || app.staticTexts["Perfect fit!"].exists
        )
        XCTAssertTrue(app.staticTexts["3 working days"].waitForExistence(timeout: 2))

        nextSlot.tap()
        XCTAssertTrue(app.navigationBars["Add Project"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["This job is scheduled."].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["3 working days"].waitForExistence(timeout: 2))
    }

    func testOneAndFiveDaySearchesReturnSlots() {
        openFindFreeDays()
        app.buttons["Decrease days"].tap()
        app.buttons["Decrease days"].tap()
        searchAvailableDays()
        XCTAssertTrue(nextSlot.waitForExistence(timeout: 4), "1-day search should return a slot")

        app.buttons["Close"].tap()
        openFindFreeDays()
        app.buttons["Increase days"].tap()
        app.buttons["Increase days"].tap()
        searchAvailableDays()
        XCTAssertTrue(nextSlot.waitForExistence(timeout: 4), "5-day search should return a slot")
        XCTAssertTrue(app.staticTexts["5 working days"].waitForExistence(timeout: 2))
    }

    func testBookedJobIsSkippedAndQuotedDoesNotBlock() {
        openAddProjectFromHome()
        fillProject(name: "Booked paint", customer: "Booked Client", status: "Booked")
        app.buttons["Save Project"].tap()

        openFindFreeDays()
        searchAvailableDays()
        XCTAssertTrue(nextSlot.waitForExistence(timeout: 4))
        nextSlot.tap()
        XCTAssertTrue(app.navigationBars["Add Project"].waitForExistence(timeout: 4))
        app.buttons["Cancel"].tap()

        openAddProjectFromHome()
        fillProject(name: "Quoted paint", customer: "Quoted Client", status: "Quoted")
        app.buttons["Save Project"].tap()

        openFindFreeDays()
        searchAvailableDays()
        XCTAssertTrue(nextSlot.waitForExistence(timeout: 4), "Quoted work must not hide availability")
    }

    private var nextSlot: XCUIElement {
        app.buttons["find-free-days-next-slot"]
    }

    private func openFindFreeDays() {
        let button = app.buttons["home-find-free-days"].exists
            ? app.buttons["home-find-free-days"]
            : app.buttons["Find Free Days"]
        XCTAssertTrue(button.waitForExistence(timeout: 4))
        button.tap()
    }

    private func searchAvailableDays() {
        let button = app.buttons["find-free-days-search"].exists
            ? app.buttons["find-free-days-search"]
            : app.buttons["Find Available Days"]
        XCTAssertTrue(button.waitForExistence(timeout: 4))
        button.tap()
    }

    private func openAddProjectFromHome() {
        if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
        }
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        }
        let add = app.buttons["Add Project"]
        XCTAssertTrue(add.waitForExistence(timeout: 4))
        add.tap()
        XCTAssertTrue(app.navigationBars["Add Project"].waitForExistence(timeout: 4))
    }

    private func fillProject(name: String, customer: String, status: String) {
        let nameField = app.textFields["Interior painting"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 4))
        nameField.tap()
        nameField.typeText(name)

        let customerField = app.textFields["Smith House"]
        customerField.tap()
        customerField.typeText(customer)

        if app.segmentedControls.buttons[status].exists {
            app.segmentedControls.buttons[status].tap()
        }
    }
}
