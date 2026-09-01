import XCTest

final class QuickCheckFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testOpenQuickCheckShowsDefaultThreeDayAnswer() {
        openQuickCheck()
        XCTAssertTrue(app.navigationBars["Quick Check"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["How long is the job?"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["3 working days"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["You can start"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts["You’ll finish"].exists || app.staticTexts["You'll finish"].exists
        )
        XCTAssertTrue(app.buttons["quick-check-use-dates"].waitForExistence(timeout: 2))
    }

    func testChangingDurationUpdatesResultWithoutFindButton() {
        openQuickCheck()
        XCTAssertTrue(app.staticTexts["3 working days"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["Find Available Days"].exists)

        app.buttons["Increase days"].tap()
        app.buttons["Increase days"].tap()
        XCTAssertTrue(app.staticTexts["5 working days"].waitForExistence(timeout: 2))

        app.buttons["Decrease days"].tap()
        app.buttons["Decrease days"].tap()
        app.buttons["Decrease days"].tap()
        app.buttons["Decrease days"].tap()
        XCTAssertTrue(
            app.staticTexts["1 working days"].waitForExistence(timeout: 2)
                || app.staticTexts["1 working day"].waitForExistence(timeout: 1)
        )
    }

    func testFromDatePickerAndUseTheseDatesPrefillsWithoutSaving() {
        openQuickCheck()
        let from = app.buttons["quick-check-from"]
        XCTAssertTrue(from.waitForExistence(timeout: 4))
        XCTAssertTrue(from.label.contains("Today") || app.staticTexts["Today"].exists)
        from.tap()
        XCTAssertTrue(app.datePickers["quick-check-from-picker"].waitForExistence(timeout: 4) || app.datePickers.firstMatch.waitForExistence(timeout: 4))

        app.buttons["quick-check-use-dates"].tap()
        XCTAssertTrue(app.navigationBars["Add Project"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["This job is scheduled."].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["3 working days"].waitForExistence(timeout: 2))
        app.buttons["Cancel"].tap()

        tapTab("Jobs")
        XCTAssertTrue(
            app.staticTexts["No projects yet."].waitForExistence(timeout: 4),
            "Closing Add Project from Quick Check must not create a project"
        )
    }

    func testClosingQuickCheckCreatesNoProject() {
        openQuickCheck()
        XCTAssertTrue(app.staticTexts["You can start"].waitForExistence(timeout: 4))
        app.buttons["Close"].tap()
        tapTab("Jobs")
        XCTAssertTrue(app.staticTexts["No projects yet."].waitForExistence(timeout: 4))
    }

    func testFindFreeDaysStaysProminentOnHome() {
        let find = app.buttons["home-find-free-days"]
        XCTAssertTrue(find.waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["home-quick-check"].exists)
        openQuickCheck()
        XCTAssertTrue(app.navigationBars["Quick Check"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["Find Available Days"].exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(find.waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["home-quick-check"].exists)
    }

    private func openQuickCheck() {
        let button = app.buttons["home-quick-check"].exists
            ? app.buttons["home-quick-check"]
            : app.buttons["Quick Check"]
        XCTAssertTrue(button.waitForExistence(timeout: 4))
        button.tap()
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
