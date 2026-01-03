import AppKit
import CoreText

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
            // Index by PostScript name
            dict[normalize(font)] = font
            
            // Try to index by localized display name without full NSFont instantiation for performance
            let descriptor = CTFontDescriptorCreateWithNameAndSize(font as CFString, 12.0)
            if let displayName = CTFontDescriptorCopyAttribute(descriptor, kCTFontDisplayNameAttribute) as? String {
                dict[normalize(displayName)] = font
            }
            if let familyName = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String {
                dict[normalize(familyName)] = font
            }
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
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /**
     Attempts to find a matching system font for a given name using "creative" fuzzy matching.
     Always avoids triggering a system download prompt.
     
     - Parameter fontName: The name of the font to search for (e.g., from a file).
     - Returns: A tuple containing whether it exists and its real name in the system if found.
     */
    func findBestMatch(for fontName: String) -> (exists: Bool, realName: String?) {
        let normalizedSearch = normalize(fontName)
        
        // 1. Try Exact match with cached available PostScript or Display names
        if let realName = systemFontNames[normalizedSearch] {
            return (true, realName)
        }
        
        // 2. Multi-step matching (removing common suffixes like -Regular, -Bold)
        let suffixes = ["regular", "bold", "italic", "light", "medium", "black", "thin"]
        let strippedName = normalizedSearch
        for suffix in suffixes {
            if strippedName.hasSuffix(suffix) {
                let base = String(strippedName.dropLast(suffix.count))
                if let real = systemFontNames[base] {
                    return (true, real)
                }
            }
        }

        // 3. Fallback: Search all keys for partial matches or reversed containment
        for (normKey, realName) in systemFontNames {
            if normKey.contains(normalizedSearch) || normalizedSearch.contains(normKey) {
                return (false, realName) // Found a close variation, show real name but allow download for exactness
            }
        }
        
        return (false, nil)
    }

    /**
     Triggers the system download for a specific font name.
     
     - Parameter fontName: The name of the font to download.
     - Parameter completion: Callback with success/failure.
     */
    func downloadFont(_ fontName: String, completion: @escaping (Bool) -> Void) {
        downloadFonts([fontName], completion: completion)
    }

    /**
     Triggers the system download for a list of font names.
     
     - Parameter fontNames: The names of the fonts to download.
     - Parameter completion: Callback with success/failure for the batch.
     */
    func downloadFonts(_ fontNames: [String], completion: @escaping (Bool) -> Void) {
        let descriptors = fontNames.map { name in
            CTFontDescriptorCreateWithAttributes([
                kCTFontNameAttribute: name
            ] as CFDictionary)
        }
        
        print("Triging download for fonts: \(fontNames)")
        
        CTFontDescriptorMatchFontDescriptorsWithProgressHandler(descriptors as CFArray, nil) { [weak self] state, progress in
            guard let self = self else { return false }
            
            switch state {
            case .didFinish:
                print("Download process completed for: \(fontNames)")
                self.refreshSystemFonts()
                
                // Verify if fonts are actually now in the system
                let installedAll = fontNames.allSatisfy { name in
                    self.findBestMatch(for: name).exists
                }
                
                if installedAll {
                    print("Verification successful: all fonts installed.")
                } else {
                    print("Verification failed: some fonts are still missing. They might not be available from Apple servers.")
                }
                
                DispatchQueue.main.async { completion(installedAll) }
                return false
                
            case .didFailWithError:
                print("Download failed with error for fonts: \(fontNames)")
                DispatchQueue.main.async { completion(false) }
                return false
                
            case .downloading:
                let percent = (progress as NSDictionary)[kCTFontDescriptorMatchingPercentage] as? Double ?? 0.0
                print("Downloading progress: \(Int(percent))%")
                return true
                
            case .stalled, .willBeginDownloading:
                return true
                
            default:
                return true
            }
        }
    }
}
