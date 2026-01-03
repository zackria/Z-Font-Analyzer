import Foundation
import UniformTypeIdentifiers

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case resultsCSV = "RESULTS_CSV"
    case resultsJSON = "RESULTS_JSON"
    case fontsCSV = "FONTS_CSV"
    case fontsJSON = "FONTS_JSON"

    var localizedName: String {
        switch self {
        case .resultsCSV: return "export_files_csv".localized
        case .resultsJSON: return "export_files_json".localized
        case .fontsCSV: return "export_fonts_csv".localized
        case .fontsJSON: return "export_fonts_json".localized
        }
    }

    var fileExtension: String {
        switch self {
        case .resultsCSV, .fontsCSV: return "csv"
        case .resultsJSON, .fontsJSON: return "json"
        }
    }

    var utType: UTType {
        switch self {
        case .resultsCSV, .fontsCSV: return .commaSeparatedText
        case .resultsJSON, .fontsJSON: return .json
        }
    }
}

// MARK: - Exporter Service

final class Exporter {
    static func exportFonts(_ fonts: [FontMatch], fontNameToFileType: [String: String], as format: ExportFormat) -> Data? {
        switch format {
        case .resultsCSV:
            return exportResultsAsCSV(fonts, fontNameToFileType: fontNameToFileType)
        case .resultsJSON:
            return exportResultsAsJSON(fonts)
        default:
            return nil
        }
    }

    static func exportSummary(_ summary: [FontSummaryRow], as format: ExportFormat) -> Data? {
        switch format {
        case .fontsCSV:
            return exportSummaryAsCSV(summary)
        case .fontsJSON:
            return exportSummaryAsJSON(summary)
        default:
            return nil
        }
    }

    private static func exportResultsAsCSV(_ fonts: [FontMatch], fontNameToFileType: [String: String]) -> Data? {
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

    private static func exportSummaryAsCSV(_ summary: [FontSummaryRow]) -> Data? {
        let headers = [
            "font_name".localized,
            "file_type".localized,
            "description".localized,
            "count".localized,
            "font_exists".localized,
            "real_font_name".localized
        ].joined(separator: ",")

        let rows = summary.map { row in
            [
                csvEscape(row.fontName),
                csvEscape(row.fileType),
                csvEscape(row.description),
                String(row.count),
                String(row.existsInSystem ?? false),
                csvEscape(row.systemFontName ?? "-")
            ].joined(separator: ",")
        }

        let csvContent = ([headers] + rows).joined(separator: "\n")
        return csvContent.data(using: .utf8)
    }

    private static func exportResultsAsJSON(_ fonts: [FontMatch]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(fonts)
    }

    private static func exportSummaryAsJSON(_ summary: [FontSummaryRow]) -> Data? {
        // Create a codable-friendly version of FontSummaryRow if needed, 
        // but since it's just a struct with simple properties, we can encode it directly.
        // Wait, FontSummaryRow is defined in ContentView.swift and might not be Codable.
        // Let's check. If it's not Codable, we might need a DTO.
        
        struct FontSummaryDTO: Codable {
            let fontName: String
            let fileType: String
            let count: Int
            let description: String
            let existsInSystem: Bool?
            let systemFontName: String?
        }
        
        let dtos = summary.map { row in
            FontSummaryDTO(
                fontName: row.fontName,
                fileType: row.fileType,
                count: row.count,
                description: row.description,
                existsInSystem: row.existsInSystem,
                systemFontName: row.systemFontName
            )
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(dtos)
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
        let prefix = (format == .fontsCSV || format == .fontsJSON) ? "FontSummary" : "FontResults"
        return "\(prefix)_\(timestamp).\(format.fileExtension)"
    }
}

extension DateFormatter {
    static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}
