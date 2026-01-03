import XCTest
import SwiftUI
import UniformTypeIdentifiers
@testable import Z_Font_Analyzer

final class ExportDocumentTests: XCTestCase {
    
    func testInitialization() {
        let testData = "test".data(using: .utf8)!
        let doc = ExportDocument(data: testData, contentType: .json)
        
        XCTAssertEqual(doc.data, testData)
        XCTAssertEqual(doc.contentType, .json)
    }
    
    func testDocumentProperties() throws {
        let testData = "test".data(using: .utf8)!
        let doc = ExportDocument(data: testData, contentType: .json)
        
        // In unit tests, we verify that the document correctly holds the data
        // meant for the file wrapper.
        XCTAssertEqual(doc.data, testData)
        XCTAssertEqual(doc.contentType, .json)
    }
    
    func testReadableContentTypes() {
        XCTAssertTrue(ExportDocument.readableContentTypes.contains(.json))
        XCTAssertTrue(ExportDocument.readableContentTypes.contains(.commaSeparatedText))
        XCTAssertTrue(ExportDocument.writableContentTypes.contains(.json))
        XCTAssertTrue(ExportDocument.writableContentTypes.contains(.commaSeparatedText))
    }
}
