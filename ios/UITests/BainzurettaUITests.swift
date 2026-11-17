import XCTest

@MainActor final class BainzurettaUITests: XCTestCase {
    func app(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing","-AppleLanguages","(it)","-AppleLocale","it_IT"] + extra; app.launch(); return app
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
    func testEveryRecordCategoryAndTop5() {
        let app = app()
        app.buttons["add-manual"].tap()
        app.textFields["manual-distance"].tap(); app.textFields["manual-distance"].typeText("160")
        app.textFields["manual-duration"].tap(); app.textFields["manual-duration"].typeText("5:00:00")
        app.buttons["manual-save"].tap(); app.buttons["tab-RECORD"].tap()
        for (category,title) in [("DISTANZA","Giro più lungo"),("VELOCITÀ","Media più alta in assoluto"),("TEMPO","Uscita più lunga"),("DISLIVELLO","Più dislivello in un’uscita"),("CADENZA","Cadenza media più alta"),("COSTANZA","Striscia più lunga di settimane consecutive"),("CURIOSITÀ","Giorno della settimana più pedalato")] {
            app.buttons["record-category"].tap(); app.buttons[category].firstMatch.tap()
            capture(category,app:app)
            if category != "DISLIVELLO" && category != "CADENZA" {
                let row = app.buttons["record-"+title]
                XCTAssertTrue(row.waitForExistence(timeout:5)); row.tap()
                XCTAssertTrue(app.navigationBars["TOP 5"].waitForExistence(timeout:5))
                app.navigationBars.buttons.element(boundBy:0).tap()
            }
        }
    }
    func testLargeTextNavigation() {
        let app = app(extra:["--large-text"])
        capture("large-text-home",app:app)
        let nav = app.buttons["tab-HOME"].firstMatch
        XCTAssertTrue(nav.exists)
        app.scrollViews["main-navigation"].swipeLeft()
        if !app.buttons["tab-RECORD"].isHittable { app.scrollViews["main-navigation"].swipeLeft() }
        app.buttons["tab-RECORD"].firstMatch.tap()
        capture("large-text-records",app:app)
    }
    func testCancelManualEditAndDarkMode() {
        let app = app(extra:["--dark-mode"])
        app.buttons["add-manual"].tap(); app.buttons["Annulla"].tap()
        app.buttons["tab-DIARIO"].tap(); XCTAssertTrue(app.staticTexts["Nessuna attività"].waitForExistence(timeout:5))
        app.buttons["tab-RECORD"].tap(); XCTAssertTrue(app.buttons["record-category"].exists || app.otherElements["record-category"].exists)
        capture("dark-records",app:app)
    }
}
