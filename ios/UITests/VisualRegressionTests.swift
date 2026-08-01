import XCTest

final class VisualRegressionTests: XCTestCase {
    @MainActor
    func testLightModeScreensAndChartsSmokeTest() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["INTERSTELLAR_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["INTERSTELLAR_UI_TEST_APPEARANCE"] = "light"
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Your Transits"].waitForExistence(timeout: 30))
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
        app.launch()

        let chartsTab = app.tabBars.buttons["Charts"]
        XCTAssertTrue(chartsTab.waitForExistence(timeout: 20))
        chartsTab.tap()

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
        app.launch()

        // Language sanity: the app must be showing Chinese UI.
        let zhToday = app.staticTexts["今日"]
        XCTAssertTrue(zhToday.waitForExistence(timeout: 10), "Chinese UI not applied; app still shows English")
        let chartsTab = app.tabBars.buttons["星盘"]
        XCTAssertTrue(chartsTab.waitForExistence(timeout: 10))
        chartsTab.tap()

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
}
