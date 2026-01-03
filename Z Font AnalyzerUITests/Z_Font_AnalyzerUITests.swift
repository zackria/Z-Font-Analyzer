import XCTest

@testable import Z_Font_Analyzer

extension String {
    var localized: String {
        // Find the app bundle by identifier to avoid linking issues with PersistenceService.self in UITests
        if let bundle = Bundle(identifier: "Ulitmate-Learning-Machine.Z-Font-Analyzer") {
            return NSLocalizedString(self, bundle: bundle, comment: "")
        }
        // Fallback to capitalizing if not found (matching most titles)
        return self.capitalized
    }
}

final class Z_Font_AnalyzerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func clickTab(_ identifier: String, app: XCUIApplication) {
        let mapping: [String: String] = [
            "dashboard_tab": "dashboard",
            "fonts_tab": "fonts",
            "files_tab": "files",
            "results_tab": "results"
        ]
        
        guard let key = mapping[identifier] else {
            XCTFail("Unknown tab identifier: \(identifier)")
            return
        }
        
        let label = key.localized
        
        // Try searching by identifier first (most reliable)
        // On macOS, the identifier might be on the radio button or a descendant
        let elementById = app.descendants(matching: .any)[identifier]
        if elementById.waitForExistence(timeout: 5) {
            elementById.click()
            // Add a small delay for the UI to respond
            Thread.sleep(forTimeInterval: 0.5)
            return
        }

        // On macOS, TabView items are typically RadioButtons
        let radioButton = app.radioButtons[label]
        if radioButton.waitForExistence(timeout: 5) {
            radioButton.click()
            Thread.sleep(forTimeInterval: 0.5)
            return
        }
        
        // Fallback to buttons
        let button = app.buttons[label]
        if button.exists {
            button.click()
            Thread.sleep(forTimeInterval: 0.5)
            return
        }

        // Try radio button by identifier specifically
        let radioById = app.radioButtons[identifier]
        if radioById.exists {
            radioById.click()
            Thread.sleep(forTimeInterval: 0.5)
            return
        }

        XCTFail("Could not find tab: \(label) (ID: \(identifier))")
    }

    @MainActor
    func testSettingsInteractions() throws {
        let app = XCUIApplication()
        app.launch()
        app.activate()
        
        XCTAssertTrue(app.staticTexts["dashboard_title"].waitForExistence(timeout: 30))
        
        let settingsBtn = app.buttons["settings_button"]
        XCTAssertTrue(settingsBtn.waitForExistence(timeout: 10))
        settingsBtn.click()
        
        // Settings sheet should be visible
        XCTAssertTrue(app.staticTexts["settings_title"].waitForExistence(timeout: 10), "Settings title should appear")
        
        // Find Stepper for concurrence
        let stepper = app.steppers["concurrence_stepper"]
        if stepper.waitForExistence(timeout: 5) {
            // On macOS, Steppers sometimes expose buttons, sometimes you can just click the stepper itself 
            // to focus or interact. Let's try to find increment button.
            let incrementButton = stepper.buttons.element(boundBy: 1)
            if incrementButton.exists {
                incrementButton.click()
            } else {
                // Fallback for different macOS versions/configurations
                stepper.click() 
            }
        }
        
        // Find Toggle - use identifier
        let toggle = app.checkBoxes["skip_hidden_toggle"]
        if toggle.waitForExistence(timeout: 5) {
            toggle.click()
        }
        
        // Find Picker - use identifier
        let languagePicker = app.pickers["language_picker"]
        if languagePicker.exists {
            languagePicker.click()
        }
        
        let doneBtn = app.buttons["done_button"]
        XCTAssertTrue(doneBtn.waitForExistence(timeout: 5))
        doneBtn.click()
    }

    @MainActor
    func testSearchAndFilter() throws {
        let app = XCUIApplication()
        app.launch()
        app.activate()
        
        XCTAssertTrue(app.staticTexts["dashboard_title"].waitForExistence(timeout: 30))
        
        // Go to Fonts tab
        clickTab("fonts_tab", app: app)
        
        // Type in search field - try both searchFields and textFields for macOS compatibility
        let searchField = app.searchFields["search_field"]
        let textField = app.textFields["search_field"]
        
        let targetField = searchField.exists ? searchField : textField
        
        if targetField.waitForExistence(timeout: 10) {
            targetField.click()
            targetField.typeText("Arial")
        }
        
        // Check if table exists - use a more general way to find it
        let table = app.descendants(matching: .any)["fonts_table"]
        XCTAssertTrue(table.waitForExistence(timeout: 20), "Fonts table should be found by identifier")
    }
    
    @MainActor
    func testSorting() throws {
        let app = XCUIApplication()
        app.launch()
        app.activate()
        
        XCTAssertTrue(app.staticTexts["dashboard_title"].waitForExistence(timeout: 30))
        clickTab("fonts_tab", app: app)
        
        let table = app.tables["fonts_table"]
        if table.waitForExistence(timeout: 20) {
            // Click header to sort - use more robust lookup
            let fontNameHeader = table.staticTexts["font_name".localized]
            if fontNameHeader.exists {
                fontNameHeader.click()
            }
        }
    }
    
    @MainActor
    func testExportFlow() throws {
        let app = XCUIApplication()
        app.launch()
        app.activate()
        
        let exportMenu = app.buttons["export_menu"]
        if exportMenu.waitForExistence(timeout: 15) {
            exportMenu.click()
        }
    }
    
    @MainActor
    func testFilesTabNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        app.activate()
        
        XCTAssertTrue(app.staticTexts["dashboard_title"].waitForExistence(timeout: 30))
        clickTab("files_tab", app: app)
        
        // Add a small wait for the tab content to load
        let table = app.descendants(matching: .any)["files_table"]
        XCTAssertTrue(table.waitForExistence(timeout: 20), "Files table should be visible after navigation")
    }
}
