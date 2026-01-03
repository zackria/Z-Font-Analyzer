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
    @State private var exportFormat: ExportFormat = .resultsJSON
    @State private var fontsSearchText = ""
    @State private var filesSearchText = ""
    @State private var resultsSearchText = ""
    @State private var activeSheet: ActiveSheet? = nil
    @State private var hasInitialized = false
    
    // High-performance search state
    @State private var fontsSearchTask: Task<Void, Never>?
    @State private var filesSearchTask: Task<Void, Never>?
    @State private var resultsSearchTask: Task<Void, Never>?
    
    @State private var debouncedFontsSummary: [FontSummaryRow] = []
    @State private var debouncedFiles: [FontMatch] = []
    @State private var debouncedResults: [FontMatch] = []
    
    @State private var fontSortOrder = [KeyPathComparator(\FontSummaryRow.fontName)]
    @State private var downloadingFonts: Set<String> = []
    
    enum ActiveSheet: Identifiable {
        case settings
        case downloadFailure(fonts: [String])
        
        var id: String {
            switch self {
            case .settings: return "settings"
            case .downloadFailure: return "downloadFailure"
            }
        }
    }
    
    @State private var statusClearTask: Task<Void, Never>? = nil
    @State private var isShowingWarningStatus = false
    
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
    // mapping logic is handled in the specialized performSearch functions

    @State private var selectedTab = 0
    @State private var viewWidth: CGFloat = 1000

    // ───────── Body ─────────
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Header Controls
                headerControls
                
                // MARK: - Search Status
                if selectedTab == 1 || fileSearcher.isSearching || !downloadingFonts.isEmpty {
                    searchStatusArea
                }

                // MARK: - Search Field (Only show if not on Dashboard)
                if selectedTab != 0 {
                    searchFieldArea
                }

                // MARK: - Tab View
                TabView(selection: $selectedTab) {
                    DashboardView(fileSearcher: fileSearcher)
                        .tabItem { 
                            Label("dashboard".localized, systemImage: "rectangle.grid.2x2.fill")
                                .accessibilityIdentifier("dashboard_tab")
                        }
                        .tag(0)

                    fontsTabView
                        .tabItem { 
                            Label("fonts".localized, systemImage: "textformat")
                                .accessibilityIdentifier("fonts_tab")
                        }
                        .tag(1)

                    filesTabView
                        .tabItem { 
                            Label("files".localized, systemImage: "doc.plaintext")
                                .accessibilityIdentifier("files_tab")
                        }
                        .tag(2)

                    resultsTabView
                        .tabItem { 
                            Label("results".localized, systemImage: "doc.text.magnifyingglass")
                                .accessibilityIdentifier("results_tab")
                        }
                        .tag(3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("app_name".localized)
            .preferredColorScheme(forcedScheme)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { 
                            DispatchQueue.main.async { viewWidth = geo.size.width }
                        }
                        .onChange(of: geo.size.width) { _, newValue in 
                            DispatchQueue.main.async { viewWidth = newValue }
                        }
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
            .sheet(item: $activeSheet) { item in
                switch item {
                case .settings:
                    SettingsView(
                        maxConcurrentOperations: $maxConcurrentOperations,
                        skipHiddenFolders: $skipHiddenFolders
                    )
                    .environmentObject(localization)
                case .downloadFailure(let fonts):
                    DownloadFailureSheet(failedFonts: fonts)
                        .environmentObject(localization)
                }
            }
            .onAppear {
                if !hasInitialized {
                    loadBookmark()
                    PersistenceService.shared.clearDatabase()
                    hasInitialized = true
                }
            }
            .onDisappear(perform: fileSearcher.stopAccessingCurrentDirectory)
            .onChange(of: fontsSearchText) { _, _ in scheduleFontsSearch() }
            .onChange(of: filesSearchText) { _, _ in scheduleFilesSearch() }
            .onChange(of: resultsSearchText) { _, _ in scheduleResultsSearch() }
            .onChange(of: fileSearcher.isSearching) { _, isSearching in
                if !isSearching {
                    performAllSearches() // Refresh lists after search finishes
                    
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
            
            Button(action: { activeSheet = .settings }) {
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
            
            if selectedTab == 1 && !fileSearcher.foundFonts.isEmpty && debouncedFontsSummary.contains(where: { $0.existsInSystem == false }) {
                Button(action: {
                    print("Download All Missing button pressed")
                    downloadAllMissingFonts()
                }) {
                    Label("download_all".localized, systemImage: "arrow.down.circle")
                }
                .disabled(fileSearcher.isSearching)
            }
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
        let isBusy = fileSearcher.isSearching || !downloadingFonts.isEmpty
        let isNotFound = isShowingWarningStatus
        
        return HStack {
            if isBusy {
                ProgressView().controlSize(.small).padding(.trailing, 6)
            } else if isNotFound {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
            }
            
            Text(fileSearcher.searchProgress)
                .font(isNotFound ? .title3.bold() : (isBusy ? .headline : .caption))
                .foregroundColor(isNotFound ? .red : (isBusy ? .primary : .secondary))
                .multilineTextAlignment(.leading)
            
            if let error = fileSearcher.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.body.bold())
                    .padding(.leading, 8)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isNotFound ? Color.red.opacity(0.1) : (isBusy ? Color.accentColor.opacity(0.1) : Color.clear))
        )
        .padding(.horizontal)
        .animation(.easeInOut, value: fileSearcher.searchProgress)
    }

    private var searchFieldArea: some View {
        let binding = Binding<String>(
            get: {
                switch selectedTagForSearch {
                case 1: return fontsSearchText
                case 2: return filesSearchText
                case 3: return resultsSearchText
                default: return ""
                }
            },
            set: { newValue in
                switch selectedTagForSearch {
                case 1: fontsSearchText = newValue
                case 2: filesSearchText = newValue
                case 3: resultsSearchText = newValue
                default: break
                }
            }
        )

        return HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("search_fonts_placeholder".localized, text: binding)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("search_field")
            if !binding.wrappedValue.isEmpty {
                Button(action: { binding.wrappedValue = "" }) {
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

    private var selectedTagForSearch: Int { selectedTab }

    private var fontsTabView: some View {
        VStack(spacing: 0) {
            Table(debouncedFontsSummary, sortOrder: $fontSortOrder) {
                TableColumn("font_name".localized, value: \.fontName)
                TableColumn("file_type".localized, value: \.fileType)
                TableColumn("description".localized, value: \.description)
                TableColumn("count".localized, value: \.count) { row in
                    Text("\(row.count)")
                }
                TableColumn("font_exists".localized, value: \.existsSortValue) { row in
                    statusIndicator(for: row.existsInSystem)
                }
                TableColumn("real_font_name".localized, value: \.realNameSortValue) { row in
                    Text(row.systemFontName ?? "—").foregroundColor(.secondary)
                }
                TableColumn("actions".localized) { row in
                    actionButton(for: row)
                }
            }
        }
        .accessibilityIdentifier("fonts_table")
        .onChange(of: fontSortOrder) { _, newOrder in
            debouncedFontsSummary.sort(using: newOrder)
        }
        .overlay {
            if debouncedFontsSummary.isEmpty && !fileSearcher.isSearching {
                if fontsSearchText.isEmpty {
                    ContentUnavailableView("no_fonts_found".localized, systemImage: "textformat.alt")
                } else {
                    ContentUnavailableView("no_matching_fonts".localized, systemImage: "textformat.alt")
                }
            }
        }
    }

    private var filesTabView: some View {
        VStack(spacing: 0) {
            Table(debouncedFiles) {
                TableColumn("file_name".localized) { font in
                    Text(URL(fileURLWithPath: font.filePath).lastPathComponent)
                }
                TableColumn("file_path".localized) { font in
                    Text(font.filePath).lineLimit(1).help(font.filePath)
                }
                TableColumn("font".localized, value: \.fontName)
            }
        }
        .accessibilityIdentifier("files_table")
        .overlay {
            if debouncedFiles.isEmpty && !fileSearcher.isSearching {
                if filesSearchText.isEmpty {
                    ContentUnavailableView("no_fonts_found".localized, systemImage: "textformat.alt")
                } else {
                    ContentUnavailableView("no_matching_fonts".localized, systemImage: "textformat.alt")
                }
            }
        }
    }

    private var resultsTabView: some View {
        VStack(spacing: 0) {
            Table(debouncedResults) {
                TableColumn("font_name".localized, value: \.fontName)
                    .width(min: 150, ideal: 180, max: 250)
                TableColumn("file_path".localized) { font in
                    Text(font.filePath).lineLimit(1).help(font.filePath)
                }
            }
        }
        .accessibilityIdentifier("results_table")
        .overlay {
            if debouncedResults.isEmpty && !fileSearcher.isSearching {
                if resultsSearchText.isEmpty {
                    ContentUnavailableView("no_fonts_found".localized, systemImage: "textformat.alt")
                } else {
                    ContentUnavailableView("no_matching_fonts".localized, systemImage: "textformat.alt")
                }
            }
        }
    }

    // MARK: - Search Pipeline

    private func scheduleFontsSearch() {
        fontsSearchTask?.cancel()
        fontsSearchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled { performFontsSearch() }
        }
    }

    private func scheduleFilesSearch() {
        filesSearchTask?.cancel()
        filesSearchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled { performFilesSearch() }
        }
    }

    private func scheduleResultsSearch() {
        resultsSearchTask?.cancel()
        resultsSearchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled { performResultsSearch() }
        }
    }

    private func performAllSearches() {
        performFontsSearch()
        performFilesSearch()
        performResultsSearch()
    }

    private func performFontsSearch() {
        let query = fontsSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentSortOrder = self.fontSortOrder
        
        DispatchQueue.global(qos: .userInitiated).async {
            let summary = PersistenceService.shared.getFilteredFontsSummary(query: query)
            var sortedSummary = summary
            sortedSummary.sort(using: currentSortOrder)
            
            DispatchQueue.main.async {
                self.debouncedFontsSummary = sortedSummary
            }
        }
    }

    private func performFilesSearch() {
        let query = filesSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.global(qos: .userInitiated).async {
            let matches = PersistenceService.shared.searchFonts(query: query, limit: 1000)
            DispatchQueue.main.async {
                self.debouncedFiles = matches
            }
        }
    }

    private func performResultsSearch() {
        let query = resultsSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.global(qos: .userInitiated).async {
            let matches = PersistenceService.shared.searchFonts(query: query, limit: 1000)
            DispatchQueue.main.async {
                self.debouncedResults = matches
            }
        }
    }

    private func checkSystemFontsInBackground() {
        let uniqueFonts = Array(fileSearcher.fontNameCounts.keys)
        
        SystemFontService.shared.refreshSystemFonts {
            DispatchQueue.global(qos: .background).async {
                for fontName in uniqueFonts {
                    let match = SystemFontService.shared.findBestMatch(for: fontName)
                    PersistenceService.shared.updateSystemFontInfo(
                        fontName: fontName,
                        isInstalled: match.exists,
                        realName: match.realName
                    )
                }
                
                // Final refresh to show results
                DispatchQueue.main.async {
                    self.performAllSearches()
                }
            }
        }
    }

    private func downloadSpecificFont(_ fontName: String) {
        DispatchQueue.main.async {
            self.fileSearcher.searchProgress = "download_started".localized
            self.downloadingFonts.insert(fontName)
        }
        
        SystemFontService.shared.downloadFont(fontName) { success in
            DispatchQueue.main.async {
                let status = success ? "download_finished".localized : String(format: "download_not_found".localized, fontName)
                self.updateStatus(status, isWarning: !success)
                self.downloadingFonts.remove(fontName)
                if success {
                    self.checkSystemFontsInBackground()
                }
            }
        }
    }
    
    private func updateStatus(_ message: String, isWarning: Bool = false) {
        statusClearTask?.cancel()
        fileSearcher.searchProgress = message
        isShowingWarningStatus = isWarning
        
        if isWarning {
            statusClearTask = Task {
                try? await Task.sleep(nanoseconds: 10 * 1_000_000_000) // 10 seconds
                if !Task.isCancelled {
                    withAnimation {
                        fileSearcher.searchProgress = ""
                        isShowingWarningStatus = false
                    }
                }
            }
        }
    }

    private func downloadAllMissingFonts() {
        let missing = debouncedFontsSummary
            .filter { $0.existsInSystem == false }
            .map { $0.fontName }
        
        print("downloadAllMissingFonts called. Missing count: \(missing.count). Fonts: \(missing)")
        
        guard !missing.isEmpty else { return }
        
        DispatchQueue.main.async {
            self.fileSearcher.searchProgress = "download_started".localized
            for font in missing {
                self.downloadingFonts.insert(font)
            }
        }
        
        SystemFontService.shared.downloadFonts(missing) { success in
            DispatchQueue.main.async {
                // Check which fonts are still missing after the attempt
                let stillMissing = missing.filter { font in
                    !SystemFontService.shared.findBestMatch(for: font).exists
                }
                
                let status: String
                if stillMissing.isEmpty {
                    status = "download_finished".localized
                } else if stillMissing.count == 1 {
                    status = String(format: "download_not_found".localized, stillMissing[0])
                } else {
                    status = String(format: "download_not_found".localized, "Multiple Fonts")
                }
                
                self.updateStatus(status, isWarning: !stillMissing.isEmpty)
                
                for font in missing {
                    self.downloadingFonts.remove(font)
                }
                
                if !stillMissing.isEmpty {
                    self.activeSheet = .downloadFailure(fonts: stillMissing)
                }
                
                if success {
                    self.checkSystemFontsInBackground()
                }
            }
        }
    }

    // MARK: - Handlers

    private var exportDocument: ExportDocument {
        let data: Data?
        if exportFormat == .fontsCSV || exportFormat == .fontsJSON {
            data = Exporter.exportSummary(debouncedFontsSummary, as: exportFormat)
        } else {
            data = Exporter.exportFonts(fileSearcher.foundFonts, fontNameToFileType: fileSearcher.fontNameToFileType, as: exportFormat)
        }
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
            self.updateStatus("export_success".localized)
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

    @ViewBuilder
    private func statusIndicator(for exists: Bool?) -> some View {
        if let exists = exists {
            Image(systemName: exists ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(exists ? .green : .red)
        } else {
            ProgressView().controlSize(.small)
        }
    }

    @ViewBuilder
    private func actionButton(for row: FontSummaryRow) -> some View {
        if row.existsInSystem == false {
            if downloadingFonts.contains(row.fontName) {
                ProgressView().controlSize(.small)
            } else {
                Button(action: { downloadSpecificFont(row.fontName) }) {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .help("download".localized)
            }
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

    init(fontName: String, fileType: String, count: Int, existsInSystem: Bool? = nil, systemFontName: String? = nil) {
        self.fontName = fontName
        self.fileType = fileType
        self.count = count
        self.existsInSystem = existsInSystem
        self.systemFontName = systemFontName
    }

    var description: String {
        switch fileType.lowercased() {
        case ".moti": return "motion_title".localized
        case ".motr": return "motion_transition".localized
        case ".motn": return "motion_generator".localized
        case ".moef": return "motion_effect".localized
        default: return "unknown".localized
        }
    }
    
    // Sorting helpers
    var existsSortValue: Int {
        guard let exists = existsInSystem else { return 0 }
        return exists ? 1 : -1
    }
    
    var realNameSortValue: String {
        systemFontName ?? "—"
    }
}

// MARK: - Download Failure View

struct DownloadFailureSheet: View {
    let failedFonts: [String]
    @Environment(\.dismiss) var dismiss
    @State private var showingCopyToast = false
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("download_failure_title".localized)
                    .font(.title2.bold())
                
                Text("download_failure_message".localized)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .trailing, spacing: 8) {
                ScrollView {
                    Text(failedFonts.joined(separator: "\n"))
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                
                Button(action: copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: showingCopyToast ? "checkmark" : "doc.on.doc")
                        Text(showingCopyToast ? "copied".localized : "copy_to_clipboard".localized)
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            // External resources section
            VStack(alignment: .leading, spacing: 12) {
                Text("download_resources_title".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 15) {
                    resourceLink(title: "google_fonts".localized, url: "https://fonts.google.com/")
                    resourceLink(title: "font_squirrel".localized, url: "https://www.fontsquirrel.com/")
                    resourceLink(title: "dafont".localized, url: "https://www.dafont.com/")
                    resourceLink(title: "adobe_fonts".localized, url: "https://fonts.adobe.com/")
                }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button("done".localized) {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(30)
        .frame(width: 530, height: 680)
    }
    
    @ViewBuilder
    private func resourceLink(title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(failedFonts.joined(separator: "\n"), forType: .string)
        
        withAnimation {
            showingCopyToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingCopyToast = false
            }
        }
    }
}

