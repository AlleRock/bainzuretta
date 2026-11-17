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
    func testJSONImportConfirmationAndRepeatedImport() throws {
        let app = app(), year = Calendar(identifier:.gregorian).component(.year,from:Date())
        let bytes = try JSONSerialization.data(withJSONObject:[["id":"test-import","data":"\(year)-01-02","distanza":80.5,"tempo":3,"media":26.8333,"nome":"TEST importazione","cadenza":87,"dislivello":700]])
        let text = try XCTUnwrap(String(data:bytes,encoding:.utf8))
        for _ in 0..<2 {
            app.buttons["tab-HOME"].tap()
            let options = app.buttons["Altre opzioni di backup"].firstMatch
            for _ in 0..<6 { if options.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(options.isHittable); options.tap()
            let paste = app.buttons["paste-backup"]
            for _ in 0..<3 { if paste.isHittable { break }; app.swipeUp() }
            paste.tap()
            let field = app.textViews["backup-text"]
            XCTAssertTrue(field.waitForExistence(timeout:5)); field.tap(); field.typeText(text)
            app.buttons["Verifica"].tap()
            let confirmation = app.alerts["Sostituire l’archivio?"]
            XCTAssertTrue(confirmation.waitForExistence(timeout:5)); confirmation.buttons["Sostituisci"].tap()
            app.buttons["tab-DIARIO"].tap()
            XCTAssertTrue(app.buttons["activity-test-import"].waitForExistence(timeout:5))
            XCTAssertEqual(app.buttons.matching(identifier:"activity-test-import").count,1)
        }
        capture("imported-json",app:app)
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
                let back = app.descendants(matching:.any)["BackButton"].firstMatch
                if back.waitForExistence(timeout:2) { back.tap() }
                else { app.navigationBars.buttons.element(boundBy:0).tap() }
                XCTAssertTrue(app.buttons["record-category"].waitForExistence(timeout:5))
            }
        }
    }
    func testLargeTextNavigation() {
        let app = app(extra:["--large-text"])
        capture("large-text-home",app:app)
        let nav = app.buttons["tab-HOME"].firstMatch
        XCTAssertTrue(nav.exists)
        for _ in 0..<5 {
            if app.buttons["tab-RECORD"].isHittable { break }
            app.scrollViews["main-navigation"].swipeLeft()
        }
        XCTAssertTrue(app.buttons["tab-RECORD"].isHittable)
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
