import XCTest
@testable import Z_Font_Analyzer

final class ModelTests: XCTestCase {
    
    func testFontMatchInitialization() {
        let fontName = "TestFont"
        let filePath = "/test/path/file.motn"
        let match = FontMatch(fontName: fontName, filePath: filePath)
        
        XCTAssertEqual(match.fontName, fontName)
        XCTAssertEqual(match.filePath, filePath)
        XCTAssertEqual(match.id, "\(fontName)|\(filePath)")
    }
    
    func testFontMatchHashable() {
        let match1 = FontMatch(fontName: "Font", filePath: "Path")
        let match2 = FontMatch(fontName: "Font", filePath: "Path")
        let match3 = FontMatch(fontName: "Other", filePath: "Path")
        
        XCTAssertEqual(match1, match2)
        XCTAssertNotEqual(match1, match3)
        
        var set = Set<FontMatch>()
        set.insert(match1)
        XCTAssertTrue(set.contains(match2))
        XCTAssertFalse(set.contains(match3))
    }
    
    func testFontMatchCodable() throws {
        let match = FontMatch(fontName: "TestFont", filePath: "/path/to/file")
        let encoder = JSONEncoder()
        let data = try encoder.encode(match)
        
        let decoder = JSONDecoder()
        let decodedMatch = try decoder.decode(FontMatch.self, from: data)
        
        XCTAssertEqual(match, decodedMatch)
    }
    
    func testFontSummaryRowDescription() {
        let rows = [
            FontSummaryRow(fontName: "A", fileType: ".moti", count: 1),
            FontSummaryRow(fontName: "B", fileType: ".motr", count: 1),
            FontSummaryRow(fontName: "C", fileType: ".motn", count: 1),
            FontSummaryRow(fontName: "D", fileType: ".moef", count: 1),
            FontSummaryRow(fontName: "E", fileType: ".unknown", count: 1)
        ]
        
        XCTAssertEqual(rows[0].description, "motion_title".localized)
        XCTAssertEqual(rows[1].description, "motion_transition".localized)
        XCTAssertEqual(rows[2].description, "motion_generator".localized)
        XCTAssertEqual(rows[3].description, "motion_effect".localized)
        XCTAssertEqual(rows[4].description, "unknown".localized)
    }

    func testFontSummaryRowIdentifiable() {
        let row1 = FontSummaryRow(fontName: "A", fileType: ".moti", count: 1)
        let row2 = FontSummaryRow(fontName: "A", fileType: ".moti", count: 2)
        XCTAssertEqual(row1.id, row2.id)
        XCTAssertEqual(row1.id, "A|.moti")
    }

    func testFontSummaryRowSortValues() {
        let r1 = FontSummaryRow(fontName: "A", fileType: ".moti", count: 1, existsInSystem: true, systemFontName: "Real")
        XCTAssertEqual(r1.existsSortValue, 1)
        XCTAssertEqual(r1.realNameSortValue, "Real")
        
        let r2 = FontSummaryRow(fontName: "B", fileType: ".moti", count: 1, existsInSystem: false)
        XCTAssertEqual(r2.existsSortValue, -1)
        XCTAssertEqual(r2.realNameSortValue, "—")
        
        let r3 = FontSummaryRow(fontName: "C", fileType: ".moti", count: 1, existsInSystem: nil)
        XCTAssertEqual(r3.existsSortValue, 0)
    }
}
