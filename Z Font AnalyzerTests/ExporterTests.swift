import XCTest
import UniformTypeIdentifiers
@testable import Z_Font_Analyzer

final class ExporterTests: XCTestCase {
    
    func testExportAsJSON() {
        let fonts = [
            FontMatch(fontName: "Arial", filePath: "/path/to/file1.motn"),
            FontMatch(fontName: "Helvetica", filePath: "/path/to/file2.moti")
        ]
        
        let data = Exporter.exportFonts(fonts, fontNameToFileType: [:], as: .json)
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
        
        let data = Exporter.exportFonts(fonts, fontNameToFileType: fontNameToFileType, as: .csv)
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
        
        let data = Exporter.exportFonts(fonts, fontNameToFileType: fontNameToFileType, as: .csv)
        let csvString = String(data: data!, encoding: .utf8)!
        
        XCTAssertTrue(csvString.contains("\"Arial, Black\""))
        XCTAssertTrue(csvString.contains("\"/path/to/\"\"file\"\".motn\""))
        XCTAssertTrue(csvString.contains("\"New\nLine\""))
    }

    func testDefaultFilename() {
        let filename = Exporter.defaultFilename(for: .json)
        XCTAssertTrue(filename.startsWith("FontAnalyzerResults_"))
        XCTAssertTrue(filename.endsWith(".json"))

        let csvFilename = Exporter.defaultFilename(for: .csv)
        XCTAssertTrue(csvFilename.endsWith(".csv"))
    }

    func testExportFormatProperties() {
        XCTAssertEqual(ExportFormat.csv.fileExtension, "csv")
        XCTAssertEqual(ExportFormat.json.fileExtension, "json")
        XCTAssertEqual(ExportFormat.csv.utType, UTType.commaSeparatedText)
        XCTAssertEqual(ExportFormat.json.utType, UTType.json)
        XCTAssertFalse(ExportFormat.csv.localizedName.isEmpty)
        XCTAssertFalse(ExportFormat.json.localizedName.isEmpty)
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
