import XCTest

final class Z_Font_AnalyzerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDumpHierarchy() throws {
        let app = XCUIApplication()
        app.launch()
        print(app.debugDescription)
    }

    @MainActor
    func testNavigationAndTabs() throws {
        let app = XCUIApplication()
        app.launch()

        // Give it some time to load
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20))

        // On macOS TabView, items are often radio buttons in a list or bar
        // Let's try to find them by type first
        let buttons = app.buttons
        
        // Try clicking by identifier first
        let dashboardTab = buttons["dashboard_tab"]
        if dashboardTab.waitForExistence(timeout: 5) {
            dashboardTab.click()
        }
        
        let fontsTab = buttons["fonts_tab"]
        if fontsTab.waitForExistence(timeout: 2) {
            fontsTab.click()
        }

        let filesTab = buttons["files_tab"]
        if filesTab.waitForExistence(timeout: 2) {
            filesTab.click()
        }

        let resultsTab = buttons["results_tab"]
        if resultsTab.waitForExistence(timeout: 2) {
            resultsTab.click()
        }
        
        // Go back to dashboard
        if dashboardTab.exists {
            dashboardTab.click()
        }
        
        // Settings
        let settingsBtn = buttons["settings_button"]
        if settingsBtn.exists {
            settingsBtn.click()
            let doneBtn = buttons["done_button"]
            if doneBtn.waitForExistence(timeout: 5) {
                doneBtn.click()
            }
        }
    }
}
