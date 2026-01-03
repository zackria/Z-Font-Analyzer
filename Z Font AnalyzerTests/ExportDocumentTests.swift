import XCTest
import UniformTypeIdentifiers
import SwiftUI
@testable import Z_Font_Analyzer

final class ExportDocumentTests: XCTestCase {
    
    func testExportDocumentInitialization() {
        let testData = "test data".data(using: .utf8)!
        let contentType = UTType.json
        let document = ExportDocument(data: testData, contentType: contentType)
        
        XCTAssertEqual(document.data, testData)
        XCTAssertEqual(document.contentType, contentType)
    }
    
    func testExportDocumentReadableContentTypes() {
        XCTAssertTrue(ExportDocument.readableContentTypes.contains(.json))
        XCTAssertTrue(ExportDocument.readableContentTypes.contains(.commaSeparatedText))
    }

    func testExportDocumentWritableContentTypes() {
        XCTAssertTrue(ExportDocument.writableContentTypes.contains(.json))
        XCTAssertTrue(ExportDocument.writableContentTypes.contains(.commaSeparatedText))
    }

}
