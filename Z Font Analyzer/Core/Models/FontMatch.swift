import Foundation

/**
 Represents a single found font, including its name and the file path where it was found.
 */
struct FontMatch: Identifiable, Hashable, Codable {
    let id: String
    let fontName: String // The name of the font found
    let filePath: String // The full path to the file containing the font

    init(id: String? = nil, fontName: String, filePath: String) {
        self.fontName = fontName
        self.filePath = filePath
        self.id = id ?? "\(fontName)|\(filePath)"
    }

    // CodingKeys for Codable conformance, ensuring consistent encoding/decoding.
    enum CodingKeys: String, CodingKey {
        case id
        case fontName
        case filePath
    }

    // Equatable conformance
    static func == (lhs: FontMatch, rhs: FontMatch) -> Bool {
        return lhs.fontName == rhs.fontName && lhs.filePath == rhs.filePath
    }

    // Hashable conformance for efficient storage in sets and dictionaries.
    func hash(into hasher: inout Hasher) {
        hasher.combine(fontName)
        hasher.combine(filePath)
    }
}
