import SwiftUI

struct SettingsView: View {
    @Binding var maxConcurrentOperations: Int
    @Binding var skipHiddenFolders: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationService
    
    @AppStorage("ui.colorScheme") private var colorSchemeSetting: String = "system"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("performance".localized) {
                    Stepper("\("max_concurrent_operations".localized): \(maxConcurrentOperations)", value: $maxConcurrentOperations, in: 1...16)
                }
                
                Section("search_options".localized) {
                    Toggle("skip_hidden_folders".localized, isOn: $skipHiddenFolders)
                }
                
                Section("language_picker".localized) {
                    Picker("language_picker".localized, selection: $localization.currentLanguage) {
                        ForEach(localization.supportedLanguages, id: \.self) { languageCode in
                            Text(localization.languageNames[languageCode] ?? languageCode)
                                .tag(languageCode)
                        }
                    }
                }
                
                Section("appearance_picker".localized) {
                    Picker("appearance_picker".localized, selection: $colorSchemeSetting) {
                        Label("theme_system".localized, systemImage: "circle.lefthalf.filled").tag("system")
                        Label("theme_light".localized, systemImage: "sun.max.fill").tag("light")
                        Label("theme_dark".localized, systemImage: "moon.fill").tag("dark")
                    }
                }
            }
            .padding()
            .frame(minWidth: 400, minHeight: 450)
            .navigationTitle("settings".localized)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done".localized) {
                        dismiss()
                    }
                    .accessibilityIdentifier("done_button")
                }
            }
        }
    }
}
