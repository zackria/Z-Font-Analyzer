import XCTest
@testable import Z_Font_Analyzer

final class PersistenceTests: XCTestCase {
    
    var persistence: PersistenceService!
    
    override func setUp() {
        super.setUp()
        persistence = PersistenceService.shared
        persistence.clearDatabase()
    }
    
    func testInsertAndSearch() {
        let match = FontMatch(fontName: "TestFont", filePath: "/path/to/file.motn")
        persistence.insertFontsBatch([(match, ".motn")])
        
        let results = persistence.searchFonts(query: "TestFont")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.fontName, "TestFont")
    }
    
    func testSearchEmptyQuery() {
        let match = FontMatch(fontName: "TestFont", filePath: "/path/to/file.motn")
        persistence.insertFontsBatch([(match, ".motn")])
        
        let results = persistence.searchFonts(query: "")
        XCTAssertEqual(results.count, 1)
    }
    
    func testSearchWithLimit() {
        var fonts = [(FontMatch, String)]()
        for i in 1...10 {
            fonts.append((FontMatch(fontName: "Font\(i)", filePath: "path\(i)"), ".motn"))
        }
        persistence.insertFontsBatch(fonts)
        
        let results = persistence.searchFonts(query: "", limit: 5)
        XCTAssertEqual(results.count, 5)
    }

    func testSearchWithQuotes() {
        let match = FontMatch(fontName: "Test \"Quote\" Font", filePath: "/path/to/file.motn")
        persistence.insertFontsBatch([(match, ".motn")])
        
        // This should not crash and should handle the escaped quotes
        let results = persistence.searchFonts(query: "Test \"Quote\"")
        XCTAssertEqual(results.count, 1)
    }
    
    func testFilteredSummary() {
        let fonts = [
            (FontMatch(fontName: "Arial", filePath: "1"), ".moti"),
            (FontMatch(fontName: "Arial", filePath: "2"), ".moti"),
            (FontMatch(fontName: "Helvetica", filePath: "3"), ".motn")
        ]
        persistence.insertFontsBatch(fonts)
        
        // All
        let summary = persistence.getFilteredFontsSummary(query: "")
        XCTAssertEqual(summary.count, 2) // Arial and Helvetica
        XCTAssertEqual(summary.first(where: { $0.fontName == "Arial" })?.count, 2)
        
        // Filtered
        let filteredSummary = persistence.getFilteredFontsSummary(query: "Arial")
        XCTAssertEqual(filteredSummary.count, 1)
        XCTAssertEqual(filteredSummary.first?.fontName, "Arial")
    }
    
    func testTotalCount() {
        let fonts = [
            (FontMatch(fontName: "A", filePath: "1"), ".moti"),
            (FontMatch(fontName: "B", filePath: "2"), ".motn")
        ]
        persistence.insertFontsBatch(fonts)
        XCTAssertEqual(persistence.getTotalFontsCount(), 2)
    }

    func testGetAllFonts() {
        let fonts = [
            (FontMatch(fontName: "A", filePath: "1"), ".moti"),
            (FontMatch(fontName: "B", filePath: "2"), ".motn")
        ]
        persistence.insertFontsBatch(fonts)
        let all = persistence.getAllFonts(limit: 1)
        XCTAssertEqual(all.count, 1)
    }

    func testClearDatabase() {
        persistence.insertFontsBatch([(FontMatch(fontName: "A", filePath: "1"), ".moti")])
        XCTAssertEqual(persistence.getTotalFontsCount(), 1)
        persistence.clearDatabase()
        XCTAssertEqual(persistence.getTotalFontsCount(), 0)
    }
}
