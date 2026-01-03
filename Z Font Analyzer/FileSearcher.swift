import Foundation
import Combine

// MARK: - FileSearcher Class

// ObservableObject responsible for performing file searches, parsing font information,
// and managing search state and results.
class FileSearcher: ObservableObject {
    // Published properties to update SwiftUI views automatically
    @Published var foundFonts: [FontMatch] = [] // All font matches found during the search
    @Published var isSearching: Bool = false // Indicates if a search operation is in progress
    @Published var searchProgress: String = "" // Current status message for the search
    @Published var errorMessage: String? // Stores any error messages encountered
    @Published var fileTypeCounts: [String: Int] = [:] // Counts of each file type processed
    @Published var fontNameCounts: [String: Int] = [:] // Counts of each unique font name found
    @Published var fontNameToFileType: [String: String] = [:] // Stores one associated file type for each font name

    // Private properties for search logic
    private let targetExtensions: Set<String> = [".moti", ".motr", ".motn", ".moef"] // File extensions to target
    private let fontTagPattern = "<font>(.*?)</font>" // Regex pattern to extract font names
    private let fileManager = FileManager.default // FileManager instance for file system operations
    
    // Concurrent queue for parsing files, allowing multiple files to be processed simultaneously.
    private var parsingQueue = DispatchQueue(label: "com.fontfinder.parsingQueue", attributes: .concurrent)
    // DispatchGroup to track completion of all file processing tasks.
    private var dispatchGroup = DispatchGroup()
    // Serial queue to synchronize access to `resultsAccumulator` and temporary count dictionaries.
    private var resultsAccessQueue = DispatchQueue(label: "com.fontfinder.resultsAccessQueue")
    // Temporary array to accumulate results before publishing to `foundFonts`.
    // We'll limit the in-memory results to avoid huge memory usage.
    private var resultsAccumulator = [FontMatch]()
    @Published var totalFoundCount: Int = 0

    private var shouldCancelSearch = false // Flag to signal cancellation of the search
    private var currentDirectoryAccess: URL? // Stores the URL for managing security-scoped bookmark access

    // MARK: - Public Methods

    /// Starts the file search operation in the specified directory.
    /// - Parameters:
    ///   - directoryURL: The URL of the directory to search.
    ///   - maxConcurrentOperations: The maximum number of files to process concurrently.
    ///   - skipHiddenFolders: A boolean indicating whether to skip hidden folders (starting with '.').
    func startSearch(in directoryURL: URL, maxConcurrentOperations: Int, skipHiddenFolders: Bool) {
        guard directoryURL.isFileURL else {
            self.errorMessage = "invalid_directory".localized
            return
        }

        // Stop any ongoing security-scoped access before starting a new one.
        stopAccessingCurrentDirectory()
        currentDirectoryAccess = directoryURL
        // Attempt to start accessing the security-scoped resource.
        _ = directoryURL.startAccessingSecurityScopedResource()

        let semaphore = DispatchSemaphore(value: max(1, maxConcurrentOperations)) // Controls concurrency limit
        shouldCancelSearch = false // Reset cancellation flag for a new search

        // Reset published properties on the main thread before starting the search.
        DispatchQueue.main.async {
            self.isSearching = true
            self.errorMessage = nil
            self.foundFonts = []
            self.fileTypeCounts = [:]
            self.fontNameCounts = [:]
            self.fontNameToFileType = [:]
            self.searchProgress = "starting_search".localized
        }

        // Clear the database and accumulator
        PersistenceService.shared.clearDatabase()
        resultsAccessQueue.sync {
            self.resultsAccumulator = []
            self.totalFoundCount = 0
        }

        // Perform the search operation on a background queue to keep the UI responsive.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return } // Prevent retain cycles

            // Find all target files in the directory.
            let filesToProcess = self.findTargetFiles(in: directoryURL, skipHiddenFolders: skipHiddenFolders)

            // Check for cancellation after finding files.
            guard !self.shouldCancelSearch else {
                self.finalizeSearch(cancelled: true)
                return
            }

            // Handle case where no target files are found.
            guard !filesToProcess.isEmpty else {
                self.finalizeSearch(message: "no_target_files".localized)
                return
            }

            // Update progress on the main thread.
            DispatchQueue.main.async {
                self.searchProgress = String(format: "processing_files".localized, filesToProcess.count)
            }

            let totalFiles = filesToProcess.count
            var processedCount = 0

            var batchBuffer: [(FontMatch, String)] = []
            let batchSize = 500
            
            var tempFontNameCounts: [String: Int] = [:]
            var tempFontNameToFileType: [String: String] = [:]
            var tempFileTypeCounts: [String: Int] = [:]

            // Iterate over each file and process it concurrently.
            for fileURL in filesToProcess {
                // Check for cancellation before processing each file.
                guard !self.shouldCancelSearch else {
                    self.finalizeSearch(cancelled: true)
                    return
                }

                self.dispatchGroup.enter() // Indicate a new task has started
                self.parsingQueue.async {
                    semaphore.wait() // Acquire a semaphore, limiting concurrent tasks

                    let matchPairs = self.processFile(at: fileURL) // Process the file

                    self.resultsAccessQueue.sync { // Synchronize access to shared accumulators
                        batchBuffer.append(contentsOf: matchPairs)
                        
                        for (match, fileType) in matchPairs {
                            tempFontNameCounts[match.fontName, default: 0] += 1
                            if tempFontNameToFileType[match.fontName] == nil {
                                tempFontNameToFileType[match.fontName] = fileType
                            }
                        }
                        
                        processedCount += 1
                        let fileExtension = "." + fileURL.pathExtension.lowercased()
                        tempFileTypeCounts[fileExtension, default: 0] += 1
                        
                        // Batch insert to database
                        if batchBuffer.count >= batchSize || (processedCount == totalFiles && !batchBuffer.isEmpty) {
                            PersistenceService.shared.insertFontsBatch(batchBuffer)
                            self.totalFoundCount += batchBuffer.count
                            self.resultsAccumulator.append(contentsOf: batchBuffer.map { $0.0 })
                            batchBuffer.removeAll()
                        }
                    }

                    // Update progress on main thread periodically to avoid excessive UI updates.
                    if processedCount % max(1, totalFiles / 50) == 0 || processedCount == totalFiles {
                        DispatchQueue.main.async {
                            self.searchProgress = String(format: "processed_status".localized, processedCount, totalFiles)
                        }
                    }

                    semaphore.signal() // Release the semaphore
                    self.dispatchGroup.leave() // Indicate task completion
                }
            }

            // This block executes when all tasks in the dispatchGroup are complete.
            self.dispatchGroup.notify(queue: .main) {
                // Final update of counts on the main thread from temporary accumulators.
                self.resultsAccessQueue.sync {
                    self.fontNameCounts = tempFontNameCounts
                    self.fontNameToFileType = tempFontNameToFileType
                    self.fileTypeCounts = tempFileTypeCounts
                }

                // Sort the final results before publishing.
                let finalResults = self.resultsAccessQueue.sync {
                    self.resultsAccumulator.sorted {
                        $0.fontName.localizedCaseInsensitiveCompare($1.fontName) == .orderedAscending
                    }
                }

                self.foundFonts = finalResults // Publish the final results
                self.finalizeSearch(message: String(format: "search_complete".localized, self.foundFonts.count))
                if self.foundFonts.isEmpty {
                    self.errorMessage = "no_font_tags".localized
                }
            }
        }
    }

    /// Cancels the ongoing search operation.
    func cancelSearch() {
        shouldCancelSearch = true // Set the cancellation flag
        self.searchProgress = "cancel_search".localized
        self.isSearching = false
    }
    
    /// Stops accessing the current security-scoped directory, if any.
    func stopAccessingCurrentDirectory() {
        if let url = currentDirectoryAccess {
            url.stopAccessingSecurityScopedResource()
            currentDirectoryAccess = nil
            print("Stopped accessing security-scoped resource for: \(url.path)")
        }
    }

    // MARK: - Private Helper Methods

    /// Recursively finds all target files within a given directory.
    private func findTargetFiles(in directoryURL: URL, skipHiddenFolders: Bool) -> [URL] {
        var files: [URL] = []
        
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if skipHiddenFolders {
            options.insert(.skipsHiddenFiles)
        }
        
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: options
        ) else {
            DispatchQueue.main.async {
                self.errorMessage = String(format: "access_error".localized, directoryURL.lastPathComponent)
            }
            return []
        }

        for case let fileURL as URL in enumerator {
            guard !shouldCancelSearch else { return [] }

            if skipHiddenFolders {
                let relativePath = fileURL.path.replacingOccurrences(of: directoryURL.path, with: "")
                if relativePath.split(separator: "/").contains(where: { $0.hasPrefix(".") }) {
                    continue
                }
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else { continue }
            guard !isDirectory.boolValue else { continue }

            let pathExtension = fileURL.pathExtension.lowercased()
            if targetExtensions.contains("." + pathExtension) {
                files.append(fileURL)
            }
        }
        return files
    }

    /// Processes a single file to extract font names using a regular expression.
    private func processFile(at fileURL: URL) -> [(FontMatch, String)] {
        var matches: [(FontMatch, String)] = []
        do {
            guard !shouldCancelSearch else { return [] }

            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let regex = try NSRegularExpression(pattern: fontTagPattern, options: [])
            let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)

            regex.enumerateMatches(in: content, options: [], range: nsRange) { (result, _, _) in
                guard !shouldCancelSearch else { return }

                if let match = result, match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: content) {
                    let fontName = String(content[range])
                    let fontMatch = FontMatch(fontName: fontName, filePath: fileURL.path)
                    let fileType = "." + fileURL.pathExtension.lowercased()
                    matches.append((fontMatch, fileType))
                }
            }
        } catch {
            print("Error reading file \(fileURL.lastPathComponent): \(error.localizedDescription)")
        }
        return matches
    }

    /// Finalizes the search operation, updating the UI state.
    private func finalizeSearch(cancelled: Bool = false, message: String? = nil) {
        DispatchQueue.main.async {
            self.isSearching = false
            if cancelled {
                self.searchProgress = "cancel_search".localized
            } else if let msg = message {
                self.searchProgress = msg
            }
        }
    }
}

