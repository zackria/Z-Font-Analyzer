import AppKit

/**
 A service responsible for checking the existence of fonts in the user's system.
 It uses a normalized search approach to match font names regardless of spaces, hyphens, or case.
 */
final class SystemFontService {
    /// The shared singleton instance of `SystemFontService`.
    static let shared = SystemFontService()
    
    /// A dictionary mapping normalized font names to their actual PostScript names available in the system.
    private var systemFontNames: [String: String] = [:]
    
    private init() {
        refreshSystemFonts()
    }
    
    /**
     Refreshes the internal cache of available system font names.
     */
    func refreshSystemFonts() {
        let fonts = NSFontManager.shared.availableFonts
        var dict: [String: String] = [:]
        for font in fonts {
            let normalized = normalize(font)
            dict[normalized] = font
        }
        self.systemFontNames = dict
    }
    
    /**
     Normalizes a font name by removing common separators and converting to lowercase.
     
     - Parameter name: The font name to normalize.
     - Returns: A normalized string (lowercase, alphanumeric only).
     */
    private func normalize(_ name: String) -> String {
        return name.lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /**
     Attempts to find a matching system font for a given name using "creative" fuzzy matching.
     
     - Parameter fontName: The name of the font to search for (e.g., from a file).
     - Returns: A tuple containing whether it exists and its real name in the system if found.
     */
    func findBestMatch(for fontName: String) -> (exists: Bool, realName: String?) {
        let normalizedSearch = normalize(fontName)
        
        // 1. Try Exact match with PostScript name
        if let realName = systemFontNames[normalizedSearch] {
            return (true, realName)
        }
        
        // 2. Fallback: CoreText check for display name / family name
        let attributes: [NSAttributedString.Key: Any] = [:]
        if let font = NSFont(name: fontName, size: 12) {
            return (true, font.fontName)
        }
        
        return (false, nil)
    }
}
