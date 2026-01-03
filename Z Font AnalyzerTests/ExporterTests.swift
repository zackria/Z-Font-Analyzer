import XCTest
import UniformTypeIdentifiers
@testable import Z_Font_Analyzer

final class ExporterTests: XCTestCase {
    
    func testExportAsJSON() {
        let fonts = [
            FontMatch(fontName: "Arial", filePath: "/path/to/file1.motn"),
            FontMatch(fontName: "Helvetica", filePath: "/path/to/file2.moti")
        ]
        
        let data = Exporter.exportFonts(fonts, fontNameToFileType: [:], as: .resultsJSON)
        XCTAssertNotNil(data)
        
        let decoded = try? JSONDecoder().decode([FontMatch].self, from: data!)
        XCTAssertEqual(decoded?.count, 2)
        XCTAssertEqual(decoded?.first?.fontName, "Arial")
    }
    
    func testExportAsCSV() {
        let fonts = [
            FontMatch(fontName: "Arial", filePath: "/path/to/file1.motn")
        ]
        let fontNameToFileType = ["Arial": ".motn"]
        
        let data = Exporter.exportFonts(fonts, fontNameToFileType: fontNameToFileType, as: .resultsCSV)
        XCTAssertNotNil(data)
        
        let csvString = String(data: data!, encoding: .utf8)
        XCTAssertTrue(csvString!.contains("Arial"))
        XCTAssertTrue(csvString!.contains(".motn"))
    }
    
    func testCSVTypeEscaping() {
        let fonts = [
            FontMatch(fontName: "Arial, Black", filePath: "/path/to/\"file\".motn"),
            FontMatch(fontName: "New\nLine", filePath: "path")
        ]
        let fontNameToFileType = ["Arial, Black": ".motn"]
        
        let data = Exporter.exportFonts(fonts, fontNameToFileType: fontNameToFileType, as: .resultsCSV)
        let csvString = String(data: data!, encoding: .utf8)!
        
        XCTAssertTrue(csvString.contains("\"Arial, Black\""))
        XCTAssertTrue(csvString.contains("\"/path/to/\"\"file\"\".motn\""))
        XCTAssertTrue(csvString.contains("\"New\nLine\""))
    }

    func testExportSummary() {
        let summary = [
            FontSummaryRow(fontName: "Arial", fileType: ".moti", count: 5, existsInSystem: true, systemFontName: "Arial-MT")
        ]
        
        let data = Exporter.exportSummary(summary, as: .fontsCSV)
        XCTAssertNotNil(data)
        
        let csvString = String(data: data!, encoding: .utf8)!
        XCTAssertTrue(csvString.contains("Arial"))
        XCTAssertTrue(csvString.contains("Arial-MT"))
        XCTAssertTrue(csvString.contains("5"))
    }

    func testDefaultFilename() {
        let filename = Exporter.defaultFilename(for: .resultsJSON)
        XCTAssertTrue(filename.startsWith("FontResults_"))
        XCTAssertTrue(filename.endsWith(".json"))

        let csvFilename = Exporter.defaultFilename(for: .fontsCSV)
        XCTAssertTrue(csvFilename.startsWith("FontSummary_"))
        XCTAssertTrue(csvFilename.endsWith(".csv"))
    }

    func testExportSummaryJSON() {
        let summary = [
            FontSummaryRow(fontName: "Arial", fileType: ".moti", count: 5, existsInSystem: true, systemFontName: "Arial-MT")
        ]
        
        let data = Exporter.exportSummary(summary, as: .fontsJSON)
        XCTAssertNotNil(data)
        
        // Basic check for content
        let jsonString = String(data: data!, encoding: .utf8)!
        XCTAssertTrue(jsonString.contains("Arial"))
        XCTAssertTrue(jsonString.contains("Arial-MT"))
    }

    func testInvalidExportFormats() {
        let fonts = [FontMatch(fontName: "A", filePath: "B")]
        let summary = [FontSummaryRow(fontName: "A", fileType: "B", count: 1)]
        
        // Cross formats should return nil
        XCTAssertNil(Exporter.exportFonts(fonts, fontNameToFileType: [:], as: .fontsCSV))
        XCTAssertNil(Exporter.exportSummary(summary, as: .resultsJSON))
    }

    func testExportFormatProperties() {
        XCTAssertEqual(ExportFormat.resultsCSV.fileExtension, "csv")
        XCTAssertEqual(ExportFormat.fontsJSON.fileExtension, "json")
        XCTAssertEqual(ExportFormat.resultsCSV.utType, UTType.commaSeparatedText)
        XCTAssertEqual(ExportFormat.fontsJSON.utType, UTType.json)
        
        XCTAssertFalse(ExportFormat.resultsCSV.localizedName.isEmpty)
        XCTAssertFalse(ExportFormat.resultsJSON.localizedName.isEmpty)
        XCTAssertFalse(ExportFormat.fontsCSV.localizedName.isEmpty)
        XCTAssertFalse(ExportFormat.fontsJSON.localizedName.isEmpty)
    }
}

extension String {
    func startsWith(_ prefix: String) -> Bool {
        return self.hasPrefix(prefix)
    }
    func endsWith(_ suffix: String) -> Bool {
        return self.hasSuffix(suffix)
    }
}
