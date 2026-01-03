import XCTest
@testable import Z_Font_Analyzer

final class LocalizationTests: XCTestCase {
    
    func testLocalizationServiceInitialization() {
        let service = LocalizationService.shared
        XCTAssertTrue(service.supportedLanguages.contains("en"))
        XCTAssertEqual(service.languageNames["en"], "English")
    }
    
    func testStringLocalization() {
        let key = "app_name"
        let localized = key.localized
        XCTAssertFalse(localized.isEmpty)
        XCTAssertEqual("non_existent_key".localized, "non_existent_key")
        
        let service = LocalizationService.shared
        XCTAssertEqual(service.localizedString(for: "dashboard"), "dashboard".localized)
    }
    
    func testLanguageSwitching() {
        let service = LocalizationService.shared
        let originalLanguage = service.currentLanguage
        
        service.setLanguage("es")
        XCTAssertEqual(service.currentLanguage, "es")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "app_language"), "es")
        
        // Test invalid language code
        service.setLanguage("invalid")
        XCTAssertEqual(service.currentLanguage, "es") // Should NOT change
        
        // Switch back
        service.setLanguage(originalLanguage)
    }
    
    func testSupportedLanguages() {
        let service = LocalizationService.shared
        let supported = ["en", "es", "fr", "de", "ar", "zh-Hans"]
        XCTAssertEqual(service.supportedLanguages, supported)
    }

    func testLanguageNames() {
        let service = LocalizationService.shared
        XCTAssertEqual(service.languageNames["fr"], "Français")
        XCTAssertEqual(service.languageNames["de"], "Deutsch")
        XCTAssertEqual(service.languageNames["ar"], "العربية")
        XCTAssertEqual(service.languageNames["zh-Hans"], "简体中文")
    }

    func testLocalizationServiceDirectCalls() {
        let service = LocalizationService.shared
        let name = service.localizedString(for: "app_name")
        XCTAssertFalse(name.isEmpty)
    }
}
