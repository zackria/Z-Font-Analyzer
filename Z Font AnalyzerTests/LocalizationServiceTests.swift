import XCTest
@testable import Z_Font_Analyzer

final class LocalizationServiceTests: XCTestCase {
    
    var service: LocalizationService!
    
    override func setUp() {
        super.setUp()
        service = LocalizationService.shared
    }
    
    func testSupportedLanguages() {
        XCTAssertTrue(service.supportedLanguages.contains("en"))
        XCTAssertTrue(service.supportedLanguages.contains("es"))
        XCTAssertEqual(service.languageNames["en"], "English")
    }
    
    func testSetLanguage() {
        let original = service.currentLanguage
        
        service.setLanguage("es")
        XCTAssertEqual(service.currentLanguage, "es")
        
        service.setLanguage("invalid")
        XCTAssertEqual(service.currentLanguage, "es")
        
        // Revert
        service.setLanguage(original)
    }
    
    func testLocalizedString() {
        let localized = service.localizedString(for: "dashboard")
        XCTAssertFalse(localized.isEmpty)
        XCTAssertNotEqual(localized, "dashboard") // Should be localized
    }
    
    func testStringExtension() {
        XCTAssertFalse("dashboard".localized.isEmpty)
    }
}
