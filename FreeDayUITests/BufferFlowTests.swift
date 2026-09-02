import XCTest

final class BufferFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testAddProjectWithBufferShowsCalendarBufferAndSkipsFindFreeDays() {
        addBookedProject(days: 3, buffer: 1)

        tapTab("Calendar")
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 4))
        let bufferISO = UITestWorkingDays.iso(3)
        let freeISO = UITestWorkingDays.iso(4)
        var bufferDay = app.buttons["calendar-day-\(bufferISO)"]
        if !bufferDay.waitForExistence(timeout: 2) {
            app.buttons["calendar-next"].tap()
            bufferDay = app.buttons["calendar-day-\(bufferISO)"]
        }
        XCTAssertTrue(bufferDay.waitForExistence(timeout: 4))
        XCTAssertTrue(
            bufferDay.label.contains("Reserved buffer day") || bufferDay.label.contains("Buffer"),
            "The working day after a 3-day job should be a buffer day"
        )
        XCTAssertFalse(bufferDay.label.contains("Booked"))

        var nextFree = app.buttons["calendar-day-\(freeISO)"]
        if !nextFree.waitForExistence(timeout: 2) {
            app.buttons["calendar-next"].tap()
            nextFree = app.buttons["calendar-day-\(freeISO)"]
        }
        XCTAssertTrue(nextFree.waitForExistence(timeout: 4), "The working day after the buffer should be visible as free")
        XCTAssertTrue(nextFree.label.contains("Free"))

        tapTab("Home")
        let find = app.buttons["home-find-free-days"].exists
            ? app.buttons["home-find-free-days"]
            : app.buttons["Find Free Days"]
        XCTAssertTrue(find.waitForExistence(timeout: 4))
        find.tap()
        XCTAssertTrue(app.navigationBars["Find Free Days"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Decrease days"].waitForExistence(timeout: 2))
        app.buttons["Decrease days"].tap()
        app.buttons["Decrease days"].tap()
        let search = app.buttons["find-free-days-search"].exists
            ? app.buttons["find-free-days-search"]
            : app.buttons["Find Available Days"]
        search.tap()
        let next = app.buttons["find-free-days-next-slot"]
        XCTAssertTrue(next.waitForExistence(timeout: 4))
        let nextWeekday = UITestWorkingDays.weekdayName(4)
        let bufferWeekday = UITestWorkingDays.weekdayName(3)
        XCTAssertTrue(next.label.contains(nextWeekday), "Buffer day must not be suggested as the next free slot")
        XCTAssertFalse(next.label.contains(bufferWeekday))
    }

    func testEditAndRemoveBufferFreesTheDay() {
        addBookedProject(days: 3, buffer: 1)
        openSmithHouse()
        XCTAssertTrue(app.staticTexts["1 day after job"].waitForExistence(timeout: 4))

        app.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Project"].waitForExistence(timeout: 4))
        let decreaseBuffer = app.buttons["Decrease buffer days"]
        XCTAssertTrue(decreaseBuffer.waitForExistence(timeout: 4))
        decreaseBuffer.tap()
        app.buttons["Save Project"].tap()

        XCTAssertTrue(app.buttons["project-reschedule"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["1 day after job"].exists)

        tapTab("Calendar")
        let bufferISO = UITestWorkingDays.iso(3)
        var bufferDay = app.buttons["calendar-day-\(bufferISO)"]
        if !bufferDay.waitForExistence(timeout: 2) {
            app.buttons["calendar-next"].tap()
            bufferDay = app.buttons["calendar-day-\(bufferISO)"]
        }
        XCTAssertTrue(bufferDay.waitForExistence(timeout: 4))
        XCTAssertTrue(bufferDay.label.contains("Free."), "Removing buffer should free that working day")
    }

    func testReschedulePreservesBuffer() {
        addBookedProject(days: 3, buffer: 1)
        openSmithHouse()
        app.buttons["project-reschedule"].tap()
        XCTAssertTrue(app.navigationBars["Reschedule"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["1 day after job"].waitForExistence(timeout: 2))

        let earliest = app.buttons["reschedule-earliest-slot"]
        XCTAssertTrue(earliest.waitForExistence(timeout: 4))
        earliest.tap()
        XCTAssertTrue(app.staticTexts["Move job?"].waitForExistence(timeout: 4))
        app.buttons["reschedule-confirm"].tap()

        XCTAssertTrue(app.buttons["project-reschedule"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["1 day after job"].waitForExistence(timeout: 4))
    }

    private func addBookedProject(days: Int, buffer: Int) {
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
        if buffer > 0 {
            XCTAssertTrue(app.buttons["Increase buffer days"].waitForExistence(timeout: 4))
            for _ in 0..<buffer {
                app.buttons["Increase buffer days"].tap()
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
        XCTAssertTrue(app.buttons["home-find-free-days"].waitForExistence(timeout: 4))
    }

    private func openSmithHouse() {
        tapTab("Jobs")
        let job = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Smith House'")).firstMatch
        XCTAssertTrue(job.waitForExistence(timeout: 4))
        job.tap()
        XCTAssertTrue(app.buttons["project-reschedule"].waitForExistence(timeout: 4))
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
