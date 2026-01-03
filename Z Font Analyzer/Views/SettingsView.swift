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
                // Header with App Icon/Info
                VStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                    Text("settings".localized)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .accessibilityIdentifier("settings_title")
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .padding(.vertical, 8)

                // General Settings Section
                Section {
                    LabeledContent {
                        Stepper(value: $maxConcurrentOperations, in: 1...16) {
                            Text("\(maxConcurrentOperations)")
                                .fontWeight(.medium)
                                .monospacedDigit()
                        }
                        .accessibilityIdentifier("concurrence_stepper")
                    } label: {
                        Label {
                            Text("max_concurrent_operations".localized)
                        } icon: {
                            Image(systemName: "cpu").foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("settings_general".localized)
                } footer: {
                    Text("settings_performance_desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Search Behavior Section
                Section {
                    Toggle(isOn: $skipHiddenFolders) {
                        Label {
                            Text("skip_hidden_folders".localized)
                        } icon: {
                            Image(systemName: "eye.slash").foregroundColor(.orange)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("skip_hidden_toggle")
                } header: {
                    Text("search_options".localized)
                } footer: {
                    Text("settings_search_desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Localization Section
                Section {
                    Picker(selection: $localization.currentLanguage) {
                        ForEach(localization.supportedLanguages, id: \.self) { languageCode in
                            Text(localization.languageNames[languageCode] ?? languageCode).tag(languageCode)
                        }
                    } label: {
                        Label {
                            Text("language_picker".localized)
                        } icon: {
                            Image(systemName: "character.bubble").foregroundColor(.green)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("language_picker")
                } footer: {
                    Text("settings_language_desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Appearance Section
                Section {
                    Picker(selection: $colorSchemeSetting) {
                        Label("theme_system".localized, systemImage: "circle.lefthalf.filled").tag("system")
                        Label("theme_light".localized, systemImage: "sun.max.fill").tag("light")
                        Label("theme_dark".localized, systemImage: "moon.fill").tag("dark")
                    } label: {
                        Label {
                            Text("appearance_picker".localized)
                        } icon: {
                            Image(systemName: "paintbrush").foregroundColor(.purple)
                        }
                    }
                    .pickerStyle(.inline)
                    .accessibilityIdentifier("appearance_picker")
                } footer: {
                    Text("settings_appearance_desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            .frame(minWidth: 450, maxWidth: 600, minHeight: 450, maxHeight: 800)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done".localized) {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("done_button")
                }
            }
        }
    }
}
