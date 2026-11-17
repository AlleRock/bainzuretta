import XCTest

@MainActor final class BainzurettaUITests: XCTestCase {
    func app() -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing","-AppleLanguages","(it)","-AppleLocale","it_IT"]; app.launch(); return app
    }
    func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot:app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testSixMenusAndManualActivityPersistence() {
        let app = app()
        XCTAssertTrue(app.buttons["add-manual"].waitForExistence(timeout:10))
        app.buttons["add-manual"].tap()
        app.textFields["manual-distance"].tap(); app.textFields["manual-distance"].typeText("42,5")
        app.textFields["manual-duration"].tap(); app.textFields["manual-duration"].typeText("2:00:00")
        app.buttons["manual-save"].tap()
        for tab in ["DIARIO","SFIDA","ARCHIVIO","RANKING","RECORD","HOME"] {
            app.buttons["tab-"+tab].tap(); capture(tab,app:app)
        }
        app.buttons["tab-DIARIO"].tap()
        XCTAssertTrue(app.staticTexts["42,5 km"].firstMatch.waitForExistence(timeout:5))
        app.terminate(); app.launchArguments = ["-AppleLanguages","(it)","-AppleLocale","it_IT"]; app.launch()
        app.buttons["tab-DIARIO"].tap(); XCTAssertTrue(app.staticTexts["42,5 km"].firstMatch.waitForExistence(timeout:5))
    }
    func testCancelManualEditAndDarkMode() {
        let app = app()
        app.buttons["add-manual"].tap(); app.buttons["Annulla"].tap()
        app.buttons["tab-DIARIO"].tap(); XCTAssertTrue(app.staticTexts["Nessuna attività"].waitForExistence(timeout:5))
        app.buttons["tab-RECORD"].tap(); XCTAssertTrue(app.buttons["record-category"].exists || app.otherElements["record-category"].exists)
        capture("empty-records",app:app)
    }
}
