import XCTest
@testable import Z_Font_Analyzer

final class Z_Font_AnalyzerTests: XCTestCase {

    func testAppLaunch() {
        // Basic test to ensure the test target can load the app module
        XCTAssertNotNil(LocalizationService.shared)
        XCTAssertNotNil(PersistenceService.shared)
    }

}
