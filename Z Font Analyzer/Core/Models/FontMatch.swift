import Foundation

/**
 Represents a single found font, including its name and the file path where it was found.
 */
struct FontMatch: Identifiable, Hashable, Codable {
    var id: String { "\(fontName)|\(filePath)" } // Stable unique id for SwiftUI
    let fontName: String // The name of the font found
    let filePath: String // The full path to the file containing the font

    // CodingKeys for Codable conformance, ensuring consistent encoding/decoding.
    enum CodingKeys: String, CodingKey {
        case fontName
        case filePath
    }

    // Hashable conformance for efficient storage in sets and dictionaries.
    func hash(into hasher: inout Hasher) {
        hasher.combine(fontName)
        hasher.combine(filePath)
    }
}
