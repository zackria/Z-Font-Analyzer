import SwiftUI
import UniformTypeIdentifiers
import Charts // Required for charts in the Dashboard

// MARK: - ContentView

// The main view of the application, responsible for UI layout, user interaction,
// and orchestrating search operations via FileSearcher.
struct ContentView: View {
    // ───────── State & Settings ─────────
    @StateObject private var fileSearcher = FileSearcher()

    @State private var selectedDirectoryURL: URL? {
        didSet { if let old = oldValue, old != selectedDirectoryURL {
            fileSearcher.stopAccessingCurrentDirectory()
        }}
    }
    @State private var showingFileImporter  = false
    @State private var showingExportDialog = false
    @State private var exportType: ExportType = .json // Explicit type from prompt
    @State private var searchText = ""
    @State private var showingSettings = false

    @AppStorage("maxConcurrentOperations") private var maxConcurrentOperations = 8
    @AppStorage("skipHiddenFolders")       private var skipHiddenFolders       = true

    private let bookmarkKey = "selectedDirectoryBookmark"

    enum ExportType { case json, csv }

    // ───────── Computed helpers ─────────
    private var fontSummaryRowsForTable: [FontSummaryRow] {
        fileSearcher.fontNameCounts
            .sorted(by: { $0.key < $1.key })
            .map { (fontName, count) in
                FontSummaryRow(
                    fontName: fontName,
                    fileType: fileSearcher.fontNameToFileType[fontName] ?? "-",
                    count: count
                )
            }
    }

    private var filteredFonts: [FontMatch] { performFiltering() }

    // ───────── Document helper ─────────
    /// Returns a **concrete** FileDocument regardless of the chosen format.
    private func exportDocument() -> FontResultsDataDocument {
        let data: Data
        let type: UTType

        if exportType == .json {
            data = fileSearcher.exportJSONData() ?? Data()
            type = .json
        } else {
            data = fileSearcher.exportCSVData() ?? Data()
            type = .commaSeparatedText
        }
        return FontResultsDataDocument(data: data, contentType: type)
    }

    // ───────── Body ─────────
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Search Controls and Status Section
                HStack {
                    // Button to open the directory selection dialog
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Select Directory", systemImage: "folder.fill")
                    }
                    .padding(.leading)
                    .disabled(fileSearcher.isSearching) // Disable if a search is in progress
                    .keyboardShortcut("o", modifiers: [.command]) // Keyboard shortcut for selecting directory
                    .help("Select a directory to analyze") // Tooltip

                    // Display the selected directory URL or a placeholder message
                    if let url = selectedDirectoryURL {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(url.path)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .help(url.path) // Tooltip shows full path
                    } else {
                        Text("No directory selected")
                            .foregroundColor(.secondary)
                    }

                    Spacer() // Pushes content to the sides
                    
                    // Settings button
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                    .disabled(fileSearcher.isSearching) // Disable if searching
                    .help("Configure search settings")
                    
                    // Export button
                    Button {
                        showingExportDialog = true // Show export dialog
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .padding(.trailing, 4)
                    .disabled(fileSearcher.foundFonts.isEmpty || fileSearcher.isSearching) // Disable if no fonts or searching
                    .keyboardShortcut("e", modifiers: [.command]) // Keyboard shortcut for export
                    .help("Export search results")

                    // Conditional button for Start Search or Cancel Search
                    if fileSearcher.isSearching {
                        Button {
                            fileSearcher.cancelSearch() // Call cancel method on FileSearcher
                        } label: {
                            Label("Cancel Search", systemImage: "xmark.circle.fill")
                        }
                        .padding(.trailing)
                        .help("Cancel the current search operation")
                    } else {
                        Button {
                            if let url = selectedDirectoryURL {
                                // Start search with current settings
                                fileSearcher.startSearch(in: url, maxConcurrentOperations: maxConcurrentOperations, skipHiddenFolders: skipHiddenFolders)
                            } else {
                                fileSearcher.errorMessage = "Please select a directory first."
                            }
                        } label: {
                            Label("Start Search", systemImage: "magnifyingglass")
                        }
                        .padding(.trailing)
                        .disabled(selectedDirectoryURL == nil) // Only disable if no directory is selected
                        .keyboardShortcut(.return, modifiers: [.command]) // Keyboard shortcut for start search
                        .help("Start searching for fonts")
                    }
                }
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1)) // Subtle background
                .cornerRadius(8)
                .padding([.leading, .trailing, .top])

                // MARK: - Search Progress and Error Messages Section
                VStack(alignment: .leading) {
                    HStack {
                        if fileSearcher.isSearching {
                            ProgressView() // Show progress indicator when searching
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                        }
                        Text(fileSearcher.searchProgress) // Display search progress message
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let error = fileSearcher.errorMessage {
                        Text("Error: \\(error)") // Display error message in red
                            .foregroundColor(.red)
                            .font(.callout)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading) // Align content to leading edge

                // MARK: - Search Field Section
                HStack {
                    TextField("Search fonts...", text: $searchText) // Text field for filtering results
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .padding(6)
                        .frame(minHeight: 32)
                        .overlay(
                            HStack {
                                Spacer()
                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = "" // Clear search text
                                    }) {
                                        Image(systemName: "xmark.circle.fill") // "Clear" button icon
                                            .foregroundColor(.secondary)
                                            .padding(.trailing, 8)
                                    }
                                    .buttonStyle(.plain) // Make the button clickable without default styling
                                }
                            }
                        )
                        .accessibilityLabel("Font Search Field")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor)) // Background color for the search field area
                .cornerRadius(8)
                .padding(.horizontal)

                // MARK: - Tabs Section
                TabView {
                    // 1. Dashboard Tab
                    DashboardTab(fileSearcher: fileSearcher)
                        .tabItem {
                            Label("Dashboard", systemImage: "rectangle.grid.2x2.fill")
                        }

                    // 2. Fonts Tab (Table of fonts used)
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("Fonts Used")
                                .font(.title2)
                                .bold()
                                .padding([.top, .leading, .trailing]) // Apply padding to title if needed

                            Table(fontSummaryRowsForTable) {
                                TableColumn("Font Name", value: \.fontName)
                                    .width(min: 150, ideal: 200) // Example: Allow Font Name to expand
                                TableColumn("File Type", value: \.fileType)
                                    .width(min: 70, ideal: 90, max: 100) // Example: File type is usually short
                                TableColumn("Description") { row in Text(row.description) }
                                    .width(min: 150, ideal: 250) // Example: Description can be wider
                                TableColumn("Count") { row in Text("\(row.count)") }
                                    .width(min: 40, ideal: 60, max: 70)   // Example: Count is short
                            }
                            .frame(minHeight: 200)
                        }
                        .padding()
                    }
                    .tabItem {
                        Label("Fonts", systemImage: "textformat")
                    }

                    // 3. Files Tab (Table of scanned files)
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("Scanned Files")
                                .font(.title2)
                                .bold()
                                .padding(.bottom)

                            Table(fileSearcher.foundFonts) { // Display all found fonts (already [FontMatch])
                                TableColumn("File Name") { font in // font is FontMatch
                                    Text(URL(fileURLWithPath: font.filePath).lastPathComponent) // Show just the file name
                                }
                                TableColumn("File Path") { font in // font is FontMatch
                                    Text(font.filePath)
                                        .lineLimit(1) // Limit path to one line
                                        .help(font.filePath) // Show full path on hover
                                }
                                TableColumn("Font") { font in // font is FontMatch
                                    Text(font.fontName)
                                }
                            }
                            .frame(minHeight: 200) // Ensure table has a minimum height
                        }
                        .padding()
                    }
                    .tabItem {
                        Label("Files", systemImage: "doc.plaintext")
                    }

                    // 4. Results Tab
                    Table(filteredFonts) {
                        TableColumn("Font Name")  { font in Text(font.fontName) }
                            .width(min: 150)
                        TableColumn("File Path")  { font in
                            Text(font.filePath)
                                .lineLimit(1)
                                .help(font.filePath)
                        }
                            .width(min: 250)
                    }
                    .overlay {
                        if fileSearcher.foundFonts.isEmpty && !fileSearcher.isSearching {
                            ContentUnavailableView("No Fonts Found", systemImage: "textformat.alt")
                        } else if filteredFonts.isEmpty && !searchText.isEmpty {
                            ContentUnavailableView("No Matching Fonts", systemImage: "textformat.alt")
                        }
                    }
                    .padding(.bottom)
                    .tabItem { Label("Results", systemImage: "doc.text.magnifyingglass") }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Font Analyzer")

            // ───────── Importer & Exporter ─────────
            .fileImporter(isPresented: $showingFileImporter,
                          allowedContentTypes: [.folder],
                          allowsMultipleSelection: false,
                          onCompletion: handleImport(_:))

            .fileExporter(isPresented: $showingExportDialog,
                          document: exportDocument(),
                          contentType: exportType == .json ? .json : .commaSeparatedText,
                          defaultFilename: "FontAnalyzerResults",
                          onCompletion: handleExport(_:))

            // Modifier for settings sheet
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    maxConcurrentOperations: $maxConcurrentOperations,
                    skipHiddenFolders: $skipHiddenFolders
                )
            }
            // Action performed when the view appears
            .onAppear {
                loadBookmark() // Load saved directory bookmark
            }
            // Action performed when the view disappears
            .onDisappear {
                // Ensure security-scoped resource access is stopped when the view disappears.
                fileSearcher.stopAccessingCurrentDirectory()
            }
        }
    }

    // MARK: - Helper functions
    
    private func performFiltering() -> [FontMatch] {
        let fonts = fileSearcher.foundFonts
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !search.isEmpty else {
            return fonts // Already [FontMatch]
        }

        var results: [FontMatch] = [] // Explicitly [FontMatch]
        for fontMatch in fonts { // fontMatch is FontMatch
            let name = fontMatch.fontName.lowercased()
            let path = fontMatch.filePath.lowercased()
            if name.contains(search) || path.contains(search) {
                results.append(fontMatch) // Appending FontMatch
            }
        }
        return results
    }

    private func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
            print("Bookmark saved for: \\(url.path)")
        } catch {
            print("Failed to save bookmark data for URL: \\(error)")
            fileSearcher.errorMessage = "Failed to save directory preference: \\(error.localizedDescription)"
        }
    }

    private func loadBookmark() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            fileSearcher.searchProgress = "No saved directory. Please 'Select Directory' to begin."
            return
        }

        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

            if isStale {
                print("Bookmark is stale, attempting to re-save.")
                saveBookmark(for: url)
            }

            _ = url.startAccessingSecurityScopedResource()
            self.selectedDirectoryURL = url
            print("Bookmark loaded and access started for: \\(url.path)")

        } catch {
            print("Failed to load bookmark data: \\(error)")
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            fileSearcher.errorMessage = "Failed to load saved directory: \\(error.localizedDescription). Please re-select."
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                fileSearcher.stopAccessingCurrentDirectory()
                _ = url.startAccessingSecurityScopedResource()
                self.selectedDirectoryURL = url
                saveBookmark(for: url)
            }
        case .failure(let error):
            fileSearcher.errorMessage = "Failed to select directory: \\(error.localizedDescription)"
        }
    }

    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            fileSearcher.searchProgress = "Exported successfully!"
        case .failure(let error):
            fileSearcher.errorMessage = "Export failed: \\(error.localizedDescription)"
        }
    }

    // MARK: - Helper Structs for Tables and Dashboard
    // This struct is not currently used in the UI but is kept for potential future use or clarity.
    struct SummaryRow: Identifiable {
        let id = UUID()
        let type: String
        let count: Int

        var description: String {
            switch type.lowercased() {
            case ".moti": return "Motion Title"
            case ".motr": return "Motion Transition"
            case ".motn": return "Motion Generator"
            case ".moef": return "Motion Effect"
            default: return "Unknown"
            }
        }
    }

    // Represents a row in the "Fonts Used" table.
    struct FontSummaryRow: Identifiable {
        var id: String { "\\(fontName)|\\(fileType)" } // Stable id for SwiftUI
        let fontName: String
        let fileType: String
        let count: Int

        var description: String {
            switch fileType.lowercased() {
            case ".moti": return "Motion Title"
            case ".motr": return "Motion Transition"
            case ".motn": return "Motion Generator"
            case ".moef": return "Motion Effect"
            default: return "Unknown"
            }
        }
    }

    // MARK: - Previews
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
    
    // MARK: - DashboardCard
    // A reusable view for displaying key metrics on the dashboard.
    struct DashboardCard: View {
        let title: String
        let value: String
        let systemImage: String

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: systemImage)
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Spacer()
                }
                Text(value)
                    .font(.title)
                    .bold()
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
            .shadow(radius: 1)
        }
    }
    
    // MARK: - DashboardTab
    // The Dashboard view, displaying summary statistics and charts.
    struct DashboardTab: View {
        @ObservedObject var fileSearcher: FileSearcher // Observe changes in FileSearcher

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Dashboard")
                        .font(.largeTitle)
                        .bold()
                        .padding(.bottom, 10)

                    // Display key metrics using DashboardCard
                    HStack(spacing: 16) {
                        DashboardCard(title: "Files Processed", value: "\(fileSearcher.foundFonts.count)", systemImage: "doc.on.doc")
                        DashboardCard(title: "Unique Fonts", value: "\(fileSearcher.fontNameCounts.keys.count)", systemImage: "textformat")
                        DashboardCard(title: "File Types", value: "\(fileSearcher.fileTypeCounts.count)", systemImage: "folder.fill")
                    }

                    // Chart for File Types Distribution
                    if !fileSearcher.fileTypeCounts.isEmpty {
                        Text("File Types Distribution")
                            .font(.headline)

                        Chart {
                            ForEach(fileSearcher.fileTypeCounts.sorted(by: { $0.key < $1.key }), id: \.key) { fileType, count in // Corrected id path
                                SectorMark( // Pie chart segments
                                    angle: .value("Count", count),
                                    innerRadius: .ratio(0.5), // Donut chart style
                                    angularInset: 2
                                )
                                .foregroundStyle(by: .value("File Type", fileType)) // Color by file type
                            }
                        }
                        .frame(height: 250)
                    }

                    // Chart for Top Fonts Used
                    if !fileSearcher.fontNameCounts.isEmpty {
                        Text("Top Fonts Used")
                            .font(.headline)

                        Chart {
                            // Display top 5 fonts by count
                            ForEach(Array(fileSearcher.fontNameCounts.sorted { $0.value > $1.value }.prefix(5)), id: \ .key) { font, count in // Corrected id path
                                BarMark( // Bar chart
                                    x: .value("Font", font),
                                    y: .value("Count", count)
                                )
                                .annotation(position: .top) { // Display count on top of bars
                                    Text("\(count)").font(.caption)
                                }
                            }
                        }
                        .frame(height: 200)
                    }
                }
                .padding()
            }
        }
    }
} // End of ContentView struct

// MARK: - Universal FileDocument (JSON + CSV)

struct FontResultsDataDocument: FileDocument {
    static var readableContentTypes:  [UTType] { [.json, .commaSeparatedText] }
    static var writableContentTypes: [UTType] { [.json, .commaSeparatedText] }

    var data: Data
    var contentType: UTType

    init(data: Data, contentType: UTType) {
        self.data        = data
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        self.data        = configuration.file.regularFileContents ?? Data()
        self.contentType = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Settings View
// A separate view for configuring application settings.
struct SettingsView: View {
    @Binding var maxConcurrentOperations: Int // Binding to the max concurrent operations setting
    @Binding var skipHiddenFolders: Bool // Binding to the skip hidden folders setting
    @Environment(\.dismiss) private var dismiss // Environment value to dismiss the sheet
    
    var body: some View {
        NavigationStack { // Provides a navigation bar for the settings view
            Form { // Form-based layout for settings
                Section("Performance") {
                    Stepper("Max Concurrent Operations: (maxConcurrentOperations)", value: $maxConcurrentOperations, in: 1...16)
                        .help("Higher values may improve performance on systems with more CPU cores")
                }
                
                Section("Search Options") {
                    Toggle("Skip Hidden Folders", isOn: $skipHiddenFolders)
                        .help("When enabled, hidden folders (starting with '.') will be skipped")
                }
            }
            .padding()
            .frame(minWidth: 350, minHeight: 200) // Minimum size for the settings window
            .navigationTitle("Settings") // Title for the settings window
            .toolbar { // Toolbar for the "Done" button
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss() // Dismiss the settings sheet
                    }
                }
            }
        }
    }
}
