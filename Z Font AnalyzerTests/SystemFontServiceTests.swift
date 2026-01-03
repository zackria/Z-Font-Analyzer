import XCTest
@testable import Z_Font_Analyzer

final class SystemFontServiceTests: XCTestCase {
    
    var service: SystemFontService!
    
    override func setUp() {
        super.setUp()
        service = SystemFontService.shared
        
        // Ensure fonts are loaded before testing
        let expectation = XCTestExpectation(description: "Refresh fonts")
        service.refreshSystemFonts {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFindBestMatchWithExistingFont() {
        // Adapt to whatever fonts are available in the test environment
        let fonts = NSFontManager.shared.availableFonts
        guard let sampleFont = fonts.first(where: { !$0.contains(" ") }) ?? fonts.first else {
            XCTFail("No system fonts available to test")
            return
        }
        
        let match = service.findBestMatch(for: sampleFont)
        XCTAssertTrue(match.exists)
        XCTAssertNotNil(match.realName)
    }
    
    func testFindBestMatchWithVariations() {
        // Verification of normalization and suffix stripping using a known variation
        let match = service.findBestMatch(for: "NonExistent-Regular")
        XCTAssertFalse(match.exists)
        
        // Test that normalization works
        let fonts = NSFontManager.shared.availableFonts
        if let sample = fonts.first {
            let upperSample = sample.uppercased()
            let matchUpper = service.findBestMatch(for: upperSample)
            XCTAssertTrue(matchUpper.exists)
        }
    }
    
    func testFindBestMatchNotFound() {
        let match = service.findBestMatch(for: "NonExistentFont12345")
        XCTAssertFalse(match.exists)
        XCTAssertNil(match.realName)
    }
    
    func testDownloadFontCallback() {
        let expectation = XCTestExpectation(description: "Download finishes or fails")
        
        // Helvetica is likely already there, so it might return true quickly
        service.downloadFont("Helvetica") { success in
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDownloadMultipleFonts() {
        let expectation = XCTestExpectation(description: "Batch download finishes")
        
        service.downloadFonts(["Arial", "Courier"]) { success in
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
