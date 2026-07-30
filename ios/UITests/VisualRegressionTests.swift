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
        capture("01-Today-Light")
        let week = app.staticTexts["How the week develops"]
        scrollTo(week, in: app)
        XCTAssertTrue(week.exists)
        capture("02-Today-Week-Light")

        let chartsTab = app.tabBars.buttons["Charts"]
        chartsTab.tap()
        XCTAssertTrue(chartsTab.isSelected)
        capture("03-Charts-Light")

        let askTab = app.tabBars.buttons["Ask"]
        askTab.tap()
        XCTAssertTrue(askTab.isSelected)
        XCTAssertTrue(app.staticTexts["Will It Happen?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Which One?"].exists)
        XCTAssertTrue(app.staticTexts["Find the Best Time"].exists)
        capture("04-Ask-Light")

        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()
        XCTAssertTrue(profileTab.isSelected)
        capture("05-Profile-Light")
        let people = app.staticTexts["People you know"]
        scrollTo(people, in: app)
        XCTAssertTrue(people.exists)
        capture("06-Profile-People-Light")

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Text size"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Report or suggest a feature"].exists)
        capture("07-Settings-Light")
        app.staticTexts["Report or suggest a feature"].tap()
        XCTAssertTrue(app.staticTexts["Feedback type"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Bug"].exists)
        XCTAssertTrue(app.buttons["Feature"].exists)
        XCTAssertTrue(app.buttons["Other"].exists)
        capture("08-Report-Light")
    }

    @MainActor
    func testDarkModeCoreScreens() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["INTERSTELLAR_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["INTERSTELLAR_UI_TEST_APPEARANCE"] = "dark"
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20))
        capture("09-Today-Dark")
        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()
        XCTAssertTrue(profileTab.isSelected)
        capture("10-Profile-Dark")
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0 ..< 8 where !element.exists {
            app.swipeUp()
        }
    }
}
