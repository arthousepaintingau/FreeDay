import XCTest

final class RescheduleFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testSuggestedSlotConfirmUpdatesProject() {
        addBookedProject(days: 3)
        openReschedule()

        let earliest = app.buttons["reschedule-earliest-slot"]
        XCTAssertTrue(earliest.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Earliest available"].waitForExistence(timeout: 2))
        earliest.tap()

        XCTAssertTrue(app.staticTexts["Move job?"].waitForExistence(timeout: 4))
        let confirm = app.buttons["reschedule-confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 2))
        confirm.tap()

        XCTAssertTrue(
            app.staticTexts["👍 New dates locked in."].waitForExistence(timeout: 4)
                || app.staticTexts["New dates locked in."].waitForExistence(timeout: 1)
        )
        XCTAssertTrue(app.buttons["project-reschedule"].waitForExistence(timeout: 4))
        let movedTo = UITestWorkingDays.weekdayName(3)
        XCTAssertTrue(
            app.staticTexts[movedTo].waitForExistence(timeout: 4)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", movedTo)).firstMatch.waitForExistence(timeout: 2),
            "Confirmed reschedule should show the earliest alternative start (\(movedTo))"
        )
    }

    func testCancelLeavesOriginalDatesUnchanged() {
        addBookedProject(days: 3)
        openReschedule()
        XCTAssertTrue(app.buttons["reschedule-earliest-slot"].waitForExistence(timeout: 4))
        app.buttons["reschedule-cancel"].tap()

        XCTAssertTrue(app.navigationBars["Reschedule"].waitForExistence(timeout: 1) == false || !app.navigationBars["Reschedule"].exists)
        XCTAssertTrue(app.buttons["project-reschedule"].waitForExistence(timeout: 4))
        let original = UITestWorkingDays.weekdayName(0)
        XCTAssertTrue(
            app.staticTexts[original].waitForExistence(timeout: 3)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", original)).firstMatch.waitForExistence(timeout: 2),
            "Cancel must leave the original start day (\(original)) unchanged"
        )
    }

    func testOtherOptionsAndChooseADateAreVisible() {
        addBookedProject(days: 1)
        openReschedule()
        XCTAssertTrue(app.buttons["reschedule-earliest-slot"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Other options"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["reschedule-choose-date"].waitForExistence(timeout: 2))
        app.buttons["reschedule-choose-date"].tap()
        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 4))
        let manualCancel = app.buttons["reschedule-manual-cancel"]
        XCTAssertTrue(manualCancel.waitForExistence(timeout: 2))
        manualCancel.tap()
        XCTAssertTrue(app.buttons["reschedule-earliest-slot"].waitForExistence(timeout: 2))
    }

    private func addBookedProject(days: Int) {
        tapTab("Home")
        let add = app.buttons["Add Project"]
        XCTAssertTrue(add.waitForExistence(timeout: 4))
        add.tap()
        XCTAssertTrue(app.navigationBars["Add Project"].waitForExistence(timeout: 4))

        if days > 1 {
            XCTAssertTrue(app.buttons["Increase days"].waitForExistence(timeout: 4))
            for _ in 0..<(days - 1) {
                app.buttons["Increase days"].tap()
            }
        }

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
    }

    private func openReschedule() {
        tapTab("Jobs")
        let job = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Smith House'")).firstMatch
        XCTAssertTrue(job.waitForExistence(timeout: 4))
        job.tap()
        let reschedule = app.buttons["project-reschedule"]
        XCTAssertTrue(reschedule.waitForExistence(timeout: 4))
        reschedule.tap()
        XCTAssertTrue(app.navigationBars["Reschedule"].waitForExistence(timeout: 4))
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
