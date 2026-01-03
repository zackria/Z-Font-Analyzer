import Foundation
import SwiftUI
import ObjectiveC.runtime

// MARK: - Localization Service

/**
 A service responsible for managing localization and language preferences within the application.
 
 - Conforms to: `ObservableObject`
 - Singleton: Use `LocalizationService.shared` to access the shared instance.
 */
final class LocalizationService: ObservableObject {
    /// The shared singleton instance of `LocalizationService`.
    static let shared = LocalizationService()

    /// The currently selected language code (e.g., "en", "es").
    @Published var currentLanguage: String = "en" {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "app_language")
            Bundle.setLanguage(currentLanguage)
        }
    }

    /**
     Initializes the `LocalizationService`.
     
     - Loads the saved language preference from `UserDefaults` or defaults to the system language.
     */
    private init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language") {
            currentLanguage = savedLanguage
            Bundle.setLanguage(savedLanguage)
        } else {
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            currentLanguage = supportedLanguages.contains(systemLanguage) ? systemLanguage : "en"
            Bundle.setLanguage(currentLanguage)
        }
    }

    // MARK: - Supported Languages

    /// A list of supported language codes.
    let supportedLanguages = ["en", "es", "fr", "de", "ar", "zh-Hans"]

    /// A dictionary mapping language codes to their display names.
    let languageNames = [
        "en": "English",
        "es": "Español",
        "fr": "Français", 
        "de": "Deutsch",
        "ar": "العربية",
        "zh-Hans": "简体中文"
    ]

    // MARK: - Localization Methods

    /**
     Retrieves the localized string for a given key.
     
     - Parameter `key`: The key for the localized string.
     - Returns: The localized string corresponding to the key.
     */
    func localizedString(for key: String) -> String {
        return NSLocalizedString(key, comment: "")
    }

    /**
     Sets the application's language to the specified language code.
     
     - Parameter `languageCode`: The language code to set (e.g., "en", "es").
     */
    func setLanguage(_ languageCode: String) {
        guard supportedLanguages.contains(languageCode) else { return }
        currentLanguage = languageCode
    }
}

extension String {
    var localized: String {
        return LocalizationService.shared.localizedString(for: self)
    }
}

// MARK: - Bundle Extension for Language Switching

private var bundleKey: UInt8 = 0

/**
 An extension of `Bundle` to enable dynamic language switching.
 */
extension Bundle {
    /**
     A custom subclass of `Bundle` to override localization behavior.
     */
    final class BundleEx: Bundle, @unchecked Sendable {
        /**
         Overrides the `localizedString(forKey:value:table:)` method to fetch localized strings from the associated bundle.
         
         - Parameters:
            - `key`: The key for the localized string.
            - `value`: The default value to return if the key is not found.
            - `tableName`: The table name containing the localized strings.
         - Returns: The localized string corresponding to the key.
         */
        override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
            let associatedBundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle ?? Bundle.main
            return associatedBundle.localizedString(forKey: key, value: value, table: tableName)
        }
    }

    /**
     Sets the application's language by associating the appropriate language bundle.
     
     - Parameter `language`: The language code to set (e.g., "en", "es").
     */
    static func setLanguage(_ language: String) {
        // Prevent swizzling during unit tests to avoid crashes
        if NSClassFromString("XCTest") != nil {
            return
        }

        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            objc_setAssociatedObject(Bundle.main, &bundleKey, Bundle.main, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return
        }

        object_setClass(Bundle.main, BundleEx.self)
        objc_setAssociatedObject(Bundle.main, &bundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
