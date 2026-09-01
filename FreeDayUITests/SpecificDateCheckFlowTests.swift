import XCTest

final class SpecificDateCheckFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testSpecificDateAvailableOnEmptySchedule() {
        openQuickCheck()
        XCTAssertTrue(app.staticTexts["You can start"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["Find Available Days"].exists)

        openSpecificDate()
        XCTAssertTrue(app.buttons["quick-check-specific-start"].waitForExistence(timeout: 4))
        XCTAssertTrue(
            app.staticTexts["🎯 Yes — you’re free."].waitForExistence(timeout: 2)
                || app.otherElements["quick-check-specific-available"].waitForExistence(timeout: 2)
        )
        XCTAssertTrue(app.buttons["quick-check-use-dates"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["quick-check-from-today"].waitForExistence(timeout: 2))

        app.buttons["quick-check-specific-start"].tap()
        XCTAssertTrue(
            app.datePickers["quick-check-specific-picker"].waitForExistence(timeout: 4)
                || app.datePickers.firstMatch.waitForExistence(timeout: 2)
        )

        app.buttons["quick-check-from-today"].tap()
        XCTAssertTrue(app.buttons["quick-check-from"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["quick-check-specific-date"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["You can start"].waitForExistence(timeout: 2))
    }

    func testSpecificDateUnavailableShowsNextAndPrefillsWithoutSaving() {
        addBookedToday()
        openQuickCheck()
        openSpecificDate()
        XCTAssertTrue(
            app.staticTexts["😅 Not available."].waitForExistence(timeout: 4)
                || app.otherElements["quick-check-specific-unavailable"].waitForExistence(timeout: 2)
        )
        XCTAssertTrue(
            app.staticTexts["Next available"].waitForExistence(timeout: 2)
                || app.staticTexts["NEXT AVAILABLE"].waitForExistence(timeout: 1)
        )
        let useNext = app.buttons["quick-check-use-next"]
        XCTAssertTrue(useNext.waitForExistence(timeout: 4))
        useNext.tap()
        XCTAssertTrue(app.navigationBars["Add Project"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["This job is scheduled."].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["3 working days"].waitForExistence(timeout: 2))
        app.buttons["Cancel"].tap()

        tapTab("Jobs")
        XCTAssertTrue(app.staticTexts["Smith House"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["No projects yet."].exists)
    }

    func testUseTheseDatesFromSpecificDateDoesNotSave() {
        openQuickCheck()
        openSpecificDate()
        XCTAssertTrue(app.buttons["quick-check-use-dates"].waitForExistence(timeout: 4))
        app.buttons["quick-check-use-dates"].tap()
        XCTAssertTrue(app.navigationBars["Add Project"].waitForExistence(timeout: 4))
        app.buttons["Cancel"].tap()
        tapTab("Jobs")
        XCTAssertTrue(
            app.staticTexts["No projects yet."].waitForExistence(timeout: 4),
            "Specific Date Check must not create a project until Save"
        )
    }

    func testExistingQuickCheckStillWorksFromHome() {
        openQuickCheck()
        XCTAssertTrue(app.navigationBars["Quick Check"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["quick-check-specific-date"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["quick-check-use-dates"].waitForExistence(timeout: 2))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["home-find-free-days"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["home-quick-check"].exists)
        XCTAssertTrue(app.buttons["home-whats-coming"].exists)
    }

    private func openSpecificDate() {
        let button = app.buttons["quick-check-specific-date"]
        XCTAssertTrue(button.waitForExistence(timeout: 4))
        button.tap()
    }

    private func openQuickCheck() {
        tapTab("Home")
        let button = app.buttons["home-quick-check"].exists
            ? app.buttons["home-quick-check"]
            : app.buttons["Quick Check"]
        XCTAssertTrue(button.waitForExistence(timeout: 4))
        button.tap()
        XCTAssertTrue(app.navigationBars["Quick Check"].waitForExistence(timeout: 4))
    }

    private func addBookedToday() {
        tapTab("Home")
        let add = app.buttons["Add Project"]
        XCTAssertTrue(add.waitForExistence(timeout: 4))
        add.tap()
        XCTAssertTrue(app.navigationBars["Add Project"].waitForExistence(timeout: 4))
        let nameField = app.textFields["Interior painting"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 4))
        nameField.tap()
        nameField.typeText("Interior painting")
        app.textFields["Smith House"].tap()
        app.textFields["Smith House"].typeText("Smith House")
        app.navigationBars["Add Project"].tap()
        if app.segmentedControls.buttons["Booked"].exists {
            app.segmentedControls.buttons["Booked"].tap()
        }
        app.buttons["Save Project"].tap()
        XCTAssertTrue(app.buttons["home-quick-check"].waitForExistence(timeout: 4))
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
}
