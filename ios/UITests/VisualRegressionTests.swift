import XCTest

final class VisualRegressionTests: XCTestCase {
    @MainActor
    func testLightModeScreensAndChartsSmokeTest() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["INTERSTELLAR_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["INTERSTELLAR_UI_TEST_APPEARANCE"] = "light"
        app.launchEnvironment["INTERSTELLAR_UI_TEST_SYNASTRY_SAMPLE"] = "1"
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Current Chapter"].waitForExistence(timeout: 30))
        XCTAssertTrue(
            app.staticTexts["Calculating locally…"].waitForNonExistence(timeout: 5),
            "The blocking launch calculation state should disappear once the essential snapshots are ready"
        )
        XCTAssertTrue(app.buttons["Reports"].exists)
        let sky = app.staticTexts["View Current Sky Chart"]
        scrollTo(sky, in: app)
        XCTAssertTrue(sky.exists)

        let chartsTab = app.tabBars.buttons["Charts"]
        chartsTab.tap()
        XCTAssertTrue(chartsTab.isSelected)

        let askTab = app.tabBars.buttons["Ask"]
        askTab.tap()
        XCTAssertTrue(askTab.isSelected)
        XCTAssertTrue(app.staticTexts["Will It Happen?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Which One?"].exists)
        XCTAssertTrue(app.staticTexts["Find the Best Time"].exists)

        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()
        XCTAssertTrue(profileTab.isSelected)
        let people = app.staticTexts["People you know"]
        scrollTo(people, in: app)
        XCTAssertTrue(people.exists)

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Text size"].waitForExistence(timeout: 5))
        let feedback = app.staticTexts["Report or suggest a feature"]
        scrollTo(feedback, in: app)
        XCTAssertTrue(feedback.exists)
        feedback.tap()
        XCTAssertTrue(app.staticTexts["Feedback type"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Bug"].exists)
        XCTAssertTrue(app.buttons["Feature"].exists)
        XCTAssertTrue(app.buttons["Other"].exists)
    }

    @MainActor
    func testDarkModeCoreScreens() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["INTERSTELLAR_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["INTERSTELLAR_UI_TEST_APPEARANCE"] = "dark"
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20))
        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()
        XCTAssertTrue(profileTab.isSelected)
    }

    @MainActor
    func testEventDrivenCardsRender() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["INTERSTELLAR_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["INTERSTELLAR_UI_TEST_APPEARANCE"] = "light"
        app.launchEnvironment["INTERSTELLAR_UI_TEST_SYNASTRY_SAMPLE"] = "1"
        app.launch()

        let chartsTab = app.tabBars.buttons["Charts"]
        XCTAssertTrue(chartsTab.waitForExistence(timeout: 20))
        chartsTab.tap()
        XCTAssertTrue(app.staticTexts["Charts"].waitForExistence(timeout: 8), "Charts screen did not become visible")

        // Dismiss the AI consent alert if the simulator is online.
        let allow = app.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
        }

        func select(_ label: String) {
            scrollToTop(app)
            let button = app.buttons[label]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing chart selector button: \(label)")
            button.tap()
        }

        func find(_ label: String) {
            scrollToTop(app)
            let element = app.staticTexts[label]
            var found = element.waitForExistence(timeout: 6)
            var swipes = 0
            while !found, swipes < 26 {
                app.swipeUp()
                swipes += 1
                usleep(250_000)
                found = element.exists
            }
            XCTAssertTrue(found, "Expected card \(label) to be visible")
        }

        // Natal is the default chart; its cards must render without errors.
        assertNoCardError(app)
        find("Natal interpretation")

        select("Current Sky")
        assertNoCardError(app)
        find("Sign changes")
        find("Upcoming 7 days")

        select("Transits")
        assertNoCardError(app)
        find("Transit timeline")

        select("Progressed")
        assertNoCardError(app)
        find("Progressed moon")
        find("Turning points")

        select("Solar Return")
        assertNoCardError(app)
        find("Year timeline")

        select("Synastry")
        assertNoCardError(app)
        find("Relationship overview")
    }

    @MainActor
    func testChineseCardsRender() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["INTERSTELLAR_UI_TEST_LANGUAGE"] = "zh-Hans"
        app.launchEnvironment["INTERSTELLAR_UI_TEST_APPEARANCE"] = "dark"
        app.launchEnvironment["INTERSTELLAR_UI_TEST_SYNASTRY_SAMPLE"] = "1"
        app.launch()

        // Language sanity: the app must be showing Chinese UI.
        let zhToday = app.staticTexts["今日"]
        XCTAssertTrue(zhToday.waitForExistence(timeout: 10), "Chinese UI not applied; app still shows English")
        let chartsTab = app.tabBars.buttons["星盘"]
        XCTAssertTrue(chartsTab.waitForExistence(timeout: 10))
        chartsTab.tap()
        XCTAssertTrue(app.staticTexts["星盘"].waitForExistence(timeout: 8), "星盘页面未显示")

        let allow = app.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
        }

        func select(_ label: String) {
            scrollToTop(app)
            let button = app.buttons[label]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing chart selector button: \(label)")
            button.tap()
        }

        func find(_ label: String) {
            scrollToTop(app)
            let element = app.staticTexts[label]
            var found = element.waitForExistence(timeout: 6)
            var swipes = 0
            while !found, swipes < 26 {
                app.swipeUp()
                swipes += 1
                usleep(250_000)
                found = element.exists
            }
            XCTAssertTrue(found, "Expected card \(label) to be visible")
        }

        assertNoCardError(app)
        find("本命解读")

        select("天象")
        assertNoCardError(app)
        find("当前天空总览")

        select("行运")
        assertNoCardError(app)
        find("当前主线")

        select("次限")
        assertNoCardError(app)
        find("发展阶段")

        select("日返盘")
        assertNoCardError(app)
        find("你的生日年")

        select("合盘")
        assertNoCardError(app)
        find("关系总览")
    }

    @MainActor
    func testAskHistoryAndKeyboardDone() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["INTERSTELLAR_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["INTERSTELLAR_UI_TEST_APPEARANCE"] = "dark"
        app.launch()

        let askTab = app.tabBars.buttons["Ask"]
        XCTAssertTrue(askTab.waitForExistence(timeout: 20))
        askTab.tap()
        let history = app.buttons["History"]
        scrollTo(history, in: app)
        XCTAssertTrue(history.waitForExistence(timeout: 8))

        app.staticTexts["Will It Happen?"].tap()
        XCTAssertFalse(app.staticTexts["Assign each element to a life area"].exists)
        let question = app.textFields["For example: Will this application move forward?"]
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        question.tap()
        question.typeText("Will the application move forward?")
        let keyboardDone = app.keyboards.buttons["Done"]
        XCTAssertTrue(keyboardDone.waitForExistence(timeout: 5), "The keyboard return key should be Done")
        keyboardDone.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testChartsCompactHeaderAndParametersSheet() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["INTERSTELLAR_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["INTERSTELLAR_UI_TEST_APPEARANCE"] = "dark"
        app.launch()

        let chartsTab = app.tabBars.buttons["Charts"]
        XCTAssertTrue(chartsTab.waitForExistence(timeout: 20))
        chartsTab.tap()
        XCTAssertTrue(app.buttons["Parameters"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Wheel"].exists)
        let wheel = app.otherElements["Astrology wheel"]
        XCTAssertTrue(wheel.waitForExistence(timeout: 8), "The wheel should be present below the compact controls")
        XCTAssertLessThan(wheel.frame.minY, app.frame.maxY - 83, "Expanded parameters must not push the wheel out of the initial viewport")
        XCTAssertFalse(app.staticTexts["Current sky compared with the natal chart"].exists)

        app.buttons["Parameters"].tap()
        XCTAssertTrue(app.staticTexts["Person"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Modern"].exists)
        XCTAssertTrue(app.buttons["Done"].exists)
    }

    @MainActor
    func testSpanishAndFrenchCoreLocalization() throws {
        continueAfterFailure = false

        let spanishApp = XCUIApplication()
        spanishApp.launchEnvironment["INTERSTELLAR_UI_TEST_LANGUAGE"] = "es"
        spanishApp.launchEnvironment["INTERSTELLAR_UI_TEST_APPEARANCE"] = "dark"
        spanishApp.launch()
        XCTAssertTrue(spanishApp.tabBars.buttons["Hoy"].waitForExistence(timeout: 20))
        XCTAssertTrue(spanishApp.tabBars.buttons["Cartas"].exists)
        XCTAssertTrue(spanishApp.tabBars.buttons["Consultar"].exists)
        XCTAssertTrue(spanishApp.tabBars.buttons["Profil"].exists)
        spanishApp.tabBars.buttons["Cartas"].tap()
        XCTAssertTrue(spanishApp.buttons["Parámetros"].waitForExistence(timeout: 8))
        XCTAssertTrue(spanishApp.otherElements["Rueda astrológica"].waitForExistence(timeout: 8))
        spanishApp.terminate()

        let frenchApp = XCUIApplication()
        frenchApp.launchEnvironment["INTERSTELLAR_UI_TEST_LANGUAGE"] = "fr"
        frenchApp.launchEnvironment["INTERSTELLAR_UI_TEST_APPEARANCE"] = "dark"
        frenchApp.launch()
        XCTAssertTrue(frenchApp.tabBars.buttons["Aujourd’hui"].waitForExistence(timeout: 20))
        XCTAssertTrue(frenchApp.tabBars.buttons["Cartes"].exists)
        XCTAssertTrue(frenchApp.tabBars.buttons["Question"].exists)
        XCTAssertTrue(frenchApp.tabBars.buttons["Profil"].exists)
        frenchApp.tabBars.buttons["Cartes"].tap()
        XCTAssertTrue(frenchApp.buttons["Paramètres"].waitForExistence(timeout: 8))
        XCTAssertTrue(frenchApp.otherElements["Roue astrologique"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testProductionRelayGenerationAndLocalReuse() throws {
        #if targetEnvironment(simulator)
            throw XCTSkip("Production App Attest requires a physical Apple device")
        #else
            continueAfterFailure = false
            let app = XCUIApplication()
            app.launchEnvironment["INTERSTELLAR_UI_TEST_LANGUAGE"] = "en"
            app.launchEnvironment["INTERSTELLAR_UI_TEST_APPEARANCE"] = "dark"
            app.launch()

            let profileTab = app.tabBars.buttons["Profile"]
            XCTAssertTrue(profileTab.waitForExistence(timeout: 30))
            profileTab.tap()
            let settings = app.buttons["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()

            let clearCache = app.buttons["Clear generated content cache"]
            scrollTo(clearCache, in: app)
            XCTAssertTrue(clearCache.waitForExistence(timeout: 10))
            clearCache.tap()
            let clear = app.buttons["Clear"]
            XCTAssertTrue(clear.waitForExistence(timeout: 10))
            clear.tap()

            let consent = app.switches["Allow new AI generation"]
            scrollTo(consent, in: app)
            XCTAssertTrue(consent.waitForExistence(timeout: 10))
            if (consent.value as? String) != "1" {
                consent.tap()
            }

            app.terminate()
            app.launch()
            let chartsTab = app.tabBars.buttons["Charts"]
            XCTAssertTrue(chartsTab.waitForExistence(timeout: 30))
            chartsTab.tap()
            let allow = app.buttons["Allow"]
            if allow.waitForExistence(timeout: 5) {
                allow.tap()
            }

            XCTAssertTrue(
                waitForGeneratedDetail(in: app, timeout: 240),
                "A physical-device App Attest request did not produce a saved chart artifact"
            )

            scrollToTop(app)
            let reports = app.buttons["Reports"]
            XCTAssertTrue(reports.waitForExistence(timeout: 10))
            reports.tap()
            let natalReport = app.staticTexts["Natal Report"]
            scrollTo(natalReport, in: app)
            XCTAssertTrue(natalReport.waitForExistence(timeout: 20), "Generated natal report was not saved on device")

            app.terminate()
            app.launch()
            XCTAssertTrue(chartsTab.waitForExistence(timeout: 30))
            chartsTab.tap()
            XCTAssertTrue(
                waitForGeneratedDetail(in: app, timeout: 20),
                "The second launch did not restore the chart artifact from local storage"
            )
        #endif
    }

    @MainActor
    private func assertNoCardError(_ app: XCUIApplication) {
        let error = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Rule ' OR label CONTAINS 'produced' OR label CONTAINS 'incomplete'")
        ).firstMatch
        if error.exists {
            XCTFail("Card loading error visible: \(error.label)")
        }
    }

    @MainActor
    private func scrollToTop(_ app: XCUIApplication) {
        for _ in 0 ..< 6 {
            app.swipeDown()
        }
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0 ..< 8 where !element.exists {
            app.swipeUp()
        }
    }

    @MainActor
    private func waitForGeneratedDetail(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let ready = app.buttons["Read details"].firstMatch
        let failed = app.staticTexts["Professional interpretation unavailable"].firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if ready.exists { return true }
            if failed.exists {
                XCTFail("Professional interpretation failed on the physical device")
                return false
            }
            app.swipeUp()
            usleep(700_000)
        }
        return ready.exists
    }
}
