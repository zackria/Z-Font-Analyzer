import Foundation
import UniformTypeIdentifiers

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"

    var localizedName: String {
        switch self {
        case .csv: return "csv_format".localized
        case .json: return "json_format".localized
        }
    }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        }
    }

    var utType: UTType {
        switch self {
        case .csv: return .commaSeparatedText
        case .json: return .json
        }
    }
}

// MARK: - Exporter Service

final class Exporter {
    static func exportFonts(_ fonts: [FontMatch], fontNameToFileType: [String: String], as format: ExportFormat) -> Data? {
        switch format {
        case .csv:
            return exportAsCSV(fonts, fontNameToFileType: fontNameToFileType)
        case .json:
            return exportAsJSON(fonts)
        }
    }

    private static func exportAsCSV(_ fonts: [FontMatch], fontNameToFileType: [String: String]) -> Data? {
        let headers = [
            "font_name".localized,
            "file_path".localized,
            "file_type".localized
        ].joined(separator: ",")

        let rows = fonts.map { font in
            [
                csvEscape(font.fontName),
                csvEscape(font.filePath),
                csvEscape(fontNameToFileType[font.fontName] ?? "-")
            ].joined(separator: ",")
        }

        let csvContent = ([headers] + rows).joined(separator: "\n")
        return csvContent.data(using: .utf8)
    }

    private static func exportAsJSON(_ fonts: [FontMatch]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(fonts)
    }

    private static func csvEscape(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    static func defaultFilename(for format: ExportFormat) -> String {
        let timestamp = DateFormatter.filenameDateFormatter.string(from: Date())
        return "FontAnalyzerResults_\(timestamp).\(format.fileExtension)"
    }
}

extension DateFormatter {
    static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}
