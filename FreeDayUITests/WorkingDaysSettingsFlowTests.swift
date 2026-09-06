import XCTest

final class WorkingDaysSettingsFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testSettingsShowsDefaultWorkingDays() {
        openSettings()
        XCTAssertTrue(app.staticTexts["Choose the days you normally work."].waitForExistence(timeout: 2))

        XCTAssertEqual(switchValue("settings-work-monday"), "1")
        XCTAssertEqual(switchValue("settings-work-friday"), "1")
        XCTAssertEqual(switchValue("settings-work-saturday"), "0")
        XCTAssertEqual(switchValue("settings-work-sunday"), "0")
        XCTAssertFalse(app.switches["settings-work-monday"].isEnabled)
        XCTAssertTrue(app.switches["settings-work-saturday"].isEnabled)
        XCTAssertTrue(app.switches["settings-work-sunday"].isEnabled)
    }

    func testSaturdayAndSundayToggleIndependently() {
        openSettings()

        let saturday = app.switches["settings-work-saturday"]
        let sunday = app.switches["settings-work-sunday"]
        XCTAssertTrue(saturday.waitForExistence(timeout: 2))

        saturday.tap()
        XCTAssertEqual(switchValue("settings-work-saturday"), "1")
        XCTAssertEqual(switchValue("settings-work-sunday"), "0")

        sunday.tap()
        XCTAssertEqual(switchValue("settings-work-saturday"), "1")
        XCTAssertEqual(switchValue("settings-work-sunday"), "1")

        saturday.tap()
        XCTAssertEqual(switchValue("settings-work-saturday"), "0")
        XCTAssertEqual(switchValue("settings-work-sunday"), "1")
    }

    func testWorkingDayChangePersistsInSession() {
        openSettings()
        app.switches["settings-work-saturday"].tap()
        XCTAssertEqual(switchValue("settings-work-saturday"), "1")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["home-settings"].waitForExistence(timeout: 3))

        openSettings()
        XCTAssertEqual(switchValue("settings-work-saturday"), "1")
        XCTAssertEqual(switchValue("settings-work-sunday"), "0")
    }

    func testVoluntaryProFromSettingsDoesNotClaimTrialEnded() {
        openSettings()
        let pro = app.buttons["settings-freeday-pro"]
        XCTAssertTrue(pro.waitForExistence(timeout: 2))
        XCTAssertTrue(pro.label.contains("Upgrade to FreeWorkDates Pro"))
        pro.tap()

        let headline = app.staticTexts["paywall-headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 4))
        XCTAssertEqual(headline.label, "Upgrade to FreeWorkDates Pro")
        XCTAssertFalse(app.staticTexts["Your 30-day free access has ended"].exists)
        XCTAssertTrue(app.staticTexts["Subscribe now for uninterrupted full access after your 30-day initial access period."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["paywall-restore"].exists)
        XCTAssertTrue(app.buttons["paywall-subscribe-monthly"].exists || app.staticTexts["Plans aren't available right now."].exists)
    }

    private func openSettings() {
        tapTab("Home")
        let settings = app.buttons["home-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 4))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 4))
    }

    private func switchValue(_ identifier: String) -> String {
        app.switches[identifier].value as? String ?? ""
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
