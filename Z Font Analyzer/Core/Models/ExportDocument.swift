import Foundation
import SwiftUI
import UniformTypeIdentifiers

/**
 A document structure for exporting font analyzer results.
 Supports JSON and CSV formats using UTType.
 */
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    static var writableContentTypes: [UTType] { [.json, .commaSeparatedText] }

    var data: Data
    var contentType: UTType

    init(data: Data, contentType: UTType) {
        self.data = data
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
        self.contentType = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
