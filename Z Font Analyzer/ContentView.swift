import SwiftUI
import UniformTypeIdentifiers

// MARK: - ContentView

struct ContentView: View {
    // ───────── State & Settings ─────────
    @StateObject private var fileSearcher = FileSearcher()
    @StateObject private var localization = LocalizationService.shared

    @State private var selectedDirectoryURL: URL? {
        didSet { if let old = oldValue, old != selectedDirectoryURL {
            fileSearcher.stopAccessingCurrentDirectory()
        }}
    }
    @State private var showingFileImporter = false
    @State private var showingExportDialog = false
    @State private var exportFormat: ExportFormat = .json
    @State private var searchText = ""
    @State private var showingSettings = false
    
    // High-performance search state
    @State private var searchTask: Task<Void, Never>?
    @State private var debouncedFontsSummary: [FontSummaryRow] = []
    @State private var debouncedFiles: [FontMatch] = []
    @State private var debouncedResults: [FontMatch] = []
    
    @State private var fontSortOrder = [KeyPathComparator(\FontSummaryRow.fontName)]
    
    @AppStorage("maxConcurrentOperations") private var maxConcurrentOperations = 8
    @AppStorage("skipHiddenFolders")       private var skipHiddenFolders       = true
    @AppStorage("ui.colorScheme") private var colorSchemeSetting: String = "system"

    private let bookmarkKey = "selectedDirectoryBookmark"

    // ───────── Computed helpers ─────────
    
    private var forcedScheme: ColorScheme? {
        switch colorSchemeSetting {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    // Results are now driving the UI from state rather than computed on-the-fly
    // mapping logic is handled in performSearch()

    @State private var selectedTab = 0
    @State private var viewWidth: CGFloat = 1000

    // ───────── Body ─────────
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Header Controls
                headerControls
                
                // MARK: - Search Status
                searchStatusArea

                // MARK: - Search Field (Only show if not on Dashboard)
                if selectedTab != 0 {
                    searchFieldArea
                }

                // MARK: - Tab View
                TabView(selection: $selectedTab) {
                    DashboardView(fileSearcher: fileSearcher)
                        .tabItem { Label("dashboard".localized, systemImage: "rectangle.grid.2x2.fill") }
                        .tag(0)
                        .accessibilityIdentifier("dashboard_tab")

                    fontsTabView
                        .tabItem { Label("fonts".localized, systemImage: "textformat") }
                        .tag(1)
                        .accessibilityIdentifier("fonts_tab")

                    filesTabView
                        .tabItem { Label("files".localized, systemImage: "doc.plaintext") }
                        .tag(2)
                        .accessibilityIdentifier("files_tab")

                    resultsTabView
                        .tabItem { Label("results".localized, systemImage: "doc.text.magnifyingglass") }
                        .tag(3)
                        .accessibilityIdentifier("results_tab")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("app_name".localized)
            .preferredColorScheme(forcedScheme)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { viewWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, newValue in viewWidth = newValue }
                }
            )
            .fileImporter(isPresented: $showingFileImporter,
                          allowedContentTypes: [.folder],
                          allowsMultipleSelection: false,
                          onCompletion: handleImport(_:))
            .fileExporter(isPresented: $showingExportDialog,
                          document: exportDocument,
                          contentType: exportFormat.utType,
                          defaultFilename: Exporter.defaultFilename(for: exportFormat),
                          onCompletion: handleExport(_:))
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    maxConcurrentOperations: $maxConcurrentOperations,
                    skipHiddenFolders: $skipHiddenFolders
                )
                .environmentObject(localization)
            }
            .onAppear {
                loadBookmark()
                PersistenceService.shared.clearDatabase() // Ensure clean state on launch
                performSearch() // Initial load
            }
            .onDisappear(perform: fileSearcher.stopAccessingCurrentDirectory)
            .onChange(of: searchText) { _, _ in
                scheduleSearch()
            }
            .onChange(of: fileSearcher.isSearching) { _, isSearching in
                if !isSearching {
                    performSearch() // Refresh list after search finishes
                    
                    // Trigger background system font existence check
                    if !fileSearcher.fontNameCounts.isEmpty {
                        checkSystemFontsInBackground()
                    }
                }
            }
        }
        .environmentObject(localization)
    }

    // MARK: - View Components

    private var headerControls: some View {
        Group {
            if viewWidth > 750 {
                HStack(spacing: 16) {
                    directorySelector
                    Spacer()
                    actionButtons
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    directorySelector
                    actionButtons
                }
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
    }

    private var directorySelector: some View {
        HStack(spacing: 12) {
            Button(action: { showingFileImporter = true }) {
                Label("select_directory".localized, systemImage: "folder.fill")
            }
            .disabled(fileSearcher.isSearching)
            .keyboardShortcut("o", modifiers: [.command])

            if let url = selectedDirectoryURL {
                Text(url.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(url.path)
                    .frame(maxWidth: viewWidth > 750 ? 300 : .infinity, alignment: .leading)
            } else {
                Text("no_directory_selected".localized)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if viewWidth <= 750 { Spacer() }
            
            Button(action: { showingSettings = true }) {
                Label("settings".localized, systemImage: "gear")
            }
            .accessibilityIdentifier("settings_button")
            .disabled(fileSearcher.isSearching)
            
            Menu {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Button(format.localizedName) {
                        exportFormat = format
                        showingExportDialog = true
                    }
                }
            } label: {
                Label("export".localized, systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("export_menu")
            .disabled(fileSearcher.foundFonts.isEmpty || fileSearcher.isSearching)
            .keyboardShortcut("e", modifiers: [.command])

            searchToggleButton
        }
    }

    private var searchToggleButton: some View {
        Group {
            if fileSearcher.isSearching {
                Button(action: { fileSearcher.cancelSearch() }) {
                    Label("cancel_search".localized, systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            } else {
                Button(action: {
                    if let url = selectedDirectoryURL {
                        fileSearcher.startSearch(in: url, maxConcurrentOperations: maxConcurrentOperations, skipHiddenFolders: skipHiddenFolders)
                    }
                }) {
                    Label("start_search".localized, systemImage: "magnifyingglass")
                }
                .disabled(selectedDirectoryURL == nil)
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var searchStatusArea: some View {
        HStack {
            if fileSearcher.isSearching {
                ProgressView().controlSize(.small).padding(.trailing, 4)
            }
            Text(fileSearcher.searchProgress)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let error = fileSearcher.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.leading, 8)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var searchFieldArea: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("search_fonts_placeholder".localized, text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private var fontsTabView: some View {
        Table(debouncedFontsSummary, sortOrder: $fontSortOrder) {
            TableColumn("font_name".localized, value: \.fontName)
            TableColumn("file_type".localized, value: \.fileType)
            TableColumn("description".localized, value: \.description)
            TableColumn("count".localized, value: \.count) { row in
                Text("\(row.count)")
            }
            TableColumn("font_exists".localized) { row in
                if let exists = row.existsInSystem {
                    Image(systemName: exists ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(exists ? .green : .red)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            TableColumn("real_font_name".localized) { row in
                Text(row.systemFontName ?? "—")
                    .foregroundColor(.secondary)
            }
        }
        .onChange(of: fontSortOrder) { _, newOrder in
            debouncedFontsSummary.sort(using: newOrder)
        }
        .overlay {
            if fileSearcher.foundFonts.isEmpty && !fileSearcher.isSearching {
                ContentUnavailableView("no_fonts_found".localized, systemImage: "textformat.alt")
            } else if debouncedFontsSummary.isEmpty && !searchText.isEmpty {
                ContentUnavailableView("no_matching_fonts".localized, systemImage: "textformat.alt")
            }
        }
    }

    private var filesTabView: some View {
        Table(debouncedFiles) {
            TableColumn("file_name".localized) { font in
                Text(URL(fileURLWithPath: font.filePath).lastPathComponent)
            }
            TableColumn("file_path".localized) { font in
                Text(font.filePath).lineLimit(1).help(font.filePath)
            }
            TableColumn("font".localized, value: \.fontName)
        }
        .overlay {
            if fileSearcher.foundFonts.isEmpty && !fileSearcher.isSearching {
                ContentUnavailableView("no_fonts_found".localized, systemImage: "textformat.alt")
            } else if debouncedFiles.isEmpty && !searchText.isEmpty {
                ContentUnavailableView("no_matching_fonts".localized, systemImage: "textformat.alt")
            }
        }
    }

    private var resultsTabView: some View {
        Table(debouncedResults) {
            TableColumn("font_name".localized, value: \.fontName)
            TableColumn("file_path".localized) { font in
                Text(font.filePath).lineLimit(1).help(font.filePath)
            }
        }
        .overlay {
            if fileSearcher.foundFonts.isEmpty && !fileSearcher.isSearching {
                ContentUnavailableView("no_fonts_found".localized, systemImage: "textformat.alt")
            } else if debouncedResults.isEmpty && !searchText.isEmpty {
                ContentUnavailableView("no_matching_fonts".localized, systemImage: "textformat.alt")
            }
        }
    }

    // MARK: - Search Pipeline

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            if !Task.isCancelled {
                performSearch()
            }
        }
    }

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Run database queries on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let summary = PersistenceService.shared.getFilteredFontsSummary(query: query)
            let matches = PersistenceService.shared.searchFonts(query: query, limit: 1000)
            
            DispatchQueue.main.async {
                var sortedSummary = summary
                sortedSummary.sort(using: self.fontSortOrder)
                self.debouncedFontsSummary = sortedSummary
                self.debouncedFiles = matches
                self.debouncedResults = matches
            }
        }
    }

    private func checkSystemFontsInBackground() {
        let uniqueFonts = Array(fileSearcher.fontNameCounts.keys)
        
        DispatchQueue.global(qos: .background).async {
            SystemFontService.shared.refreshSystemFonts()
            
            for fontName in uniqueFonts {
                let match = SystemFontService.shared.findBestMatch(for: fontName)
                PersistenceService.shared.updateSystemFontInfo(
                    fontName: fontName,
                    exists: match.exists,
                    realName: match.realName
                )
            }
            
            // Final refresh to show results
            DispatchQueue.main.async {
                self.performSearch()
            }
        }
    }

    // MARK: - Handlers

    private var exportDocument: ExportDocument {
        let data = Exporter.exportFonts(fileSearcher.foundFonts, fontNameToFileType: fileSearcher.fontNameToFileType, as: exportFormat)
        return ExportDocument(data: data ?? Data(), contentType: exportFormat.utType)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        if case .success(let urls) = result, let url = urls.first {
            fileSearcher.stopAccessingCurrentDirectory()
            _ = url.startAccessingSecurityScopedResource()
            self.selectedDirectoryURL = url
            saveBookmark(for: url)
        }
    }

    private func handleExport(_ result: Result<URL, Error>) {
        if case .success = result {
            fileSearcher.searchProgress = "export_success".localized
        } else if case .failure(let error) = result {
            fileSearcher.errorMessage = "\("export_failed".localized): \(error.localizedDescription)"
        }
    }

    // MARK: - Persistence

    private func saveBookmark(for url: URL) {
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        }
    }

    private func loadBookmark() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
            if isStale { saveBookmark(for: url) }
            _ = url.startAccessingSecurityScopedResource()
            self.selectedDirectoryURL = url
        }
    }
}

// MARK: - Helper Structs

struct FontSummaryRow: Identifiable {
    var id: String { "\(fontName)|\(fileType)" }
    let fontName: String
    let fileType: String
    let count: Int
    
    // System Font Presence
    let existsInSystem: Bool?
    let systemFontName: String?

    var description: String {
        switch fileType.lowercased() {
        case ".moti": return "motion_title".localized
        case ".motr": return "motion_transition".localized
        case ".motn": return "motion_generator".localized
        case ".moef": return "motion_effect".localized
        default: return "unknown".localized
        }
    }
}
