import Foundation
import Combine

// MARK: - FontMatch Struct

// Represents a single found font, including its name and the file path where it was found.
struct FontMatch: Identifiable, Hashable, Codable {
    var id: String { "\(fontName)|\(filePath)" } // Stable unique id for SwiftUI
    let fontName: String // The name of the font found
    let filePath: String // The full path to the file containing the font

    // CodingKeys for Codable conformance, ensuring consistent encoding/decoding.
    enum CodingKeys: String, CodingKey {
        case fontName
        case filePath
    }

    // Hashable conformance for efficient storage in sets and dictionaries.
    func hash(into hasher: inout Hasher) {
        hasher.combine(fontName)
        hasher.combine(filePath)
    }
}

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
    private var resultsAccumulator = [FontMatch]()

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
            DispatchQueue.main.async {
                self.errorMessage = "Invalid directory URL."
            }
            return
        }

        // Stop any ongoing security-scoped access before starting a new one.
        stopAccessingCurrentDirectory()
        currentDirectoryAccess = directoryURL
        // Attempt to start accessing the security-scoped resource.
        // This is crucial for accessing directories outside the app's sandbox.
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
            self.searchProgress = "Starting search..."
        }

        // Clear the accumulator on the results access queue for thread safety.
        resultsAccessQueue.sync {
            self.resultsAccumulator = []
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
                self.finalizeSearch(message: "No target files found.")
                return
            }

            // Update progress on the main thread.
            DispatchQueue.main.async {
                self.searchProgress = "Processing \(filesToProcess.count) files..."
            }

            let totalFiles = filesToProcess.count
            var processedCount = 0

            // Temporary dictionaries to accumulate counts for batch updates.
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
                        for (match, fileType) in matchPairs {
                            self.resultsAccumulator.append(match)
                            tempFontNameCounts[match.fontName, default: 0] += 1
                            // Only store the first encountered file type for a font name.
                            if tempFontNameToFileType[match.fontName] == nil {
                                tempFontNameToFileType[match.fontName] = fileType
                            }
                        }
                        processedCount += 1
                        let fileExtension = "." + fileURL.pathExtension.lowercased()
                        tempFileTypeCounts[fileExtension, default: 0] += 1
                    }

                    // Update progress on main thread periodically to avoid excessive UI updates.
                    if processedCount % max(1, totalFiles / 100) == 0 || processedCount == totalFiles {
                        DispatchQueue.main.async {
                            self.searchProgress = "Processed \(processedCount)/\(totalFiles) files."
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
                self.finalizeSearch(message: "Search complete. Found \(self.foundFonts.count) font entries.")
                if self.foundFonts.isEmpty {
                    self.errorMessage = "No font tags found in the target files."
                }
            }
        }
    }

    /// Cancels the ongoing search operation.
    func cancelSearch() {
        shouldCancelSearch = true // Set the cancellation flag
        DispatchQueue.main.async {
            self.searchProgress = "Search cancelled."
            self.isSearching = false
        }
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
    /// - Parameters:
    ///   - directoryURL: The URL of the directory to search.
    ///   - skipHiddenFolders: A boolean indicating whether to skip hidden folders.
    /// - Returns: An array of URLs pointing to the target files.
    private func findTargetFiles(in directoryURL: URL, skipHiddenFolders: Bool) -> [URL] {
        var files: [URL] = []
        
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsPackageDescendants] // Skip contents of packages (e.g., .app bundles)
        ) else {
            DispatchQueue.main.async {
                self.errorMessage = "Could not access directory: \(directoryURL.lastPathComponent)"
            }
            return []
        }

        for case let fileURL as URL in enumerator {
            guard !shouldCancelSearch else { return [] } // Exit early if search is cancelled

            // Skip hidden folders if the option is enabled.
            if skipHiddenFolders, fileURL.lastPathComponent.hasPrefix(".") {
                continue
            }

            var isDirectory: ObjCBool = false
            // Check if the file exists and is not a directory.
            guard fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else { continue }
            guard !isDirectory.boolValue else { continue } // Skip directories

            let pathExtension = fileURL.pathExtension.lowercased()
            // Add file to list if its extension is in the target extensions set.
            if targetExtensions.contains("." + pathExtension) {
                files.append(fileURL)
            }
        }
        return files
    }

    /// Processes a single file to extract font names using a regular expression.
    /// - Parameter fileURL: The URL of the file to process.
    /// - Returns: An array of tuples, each containing a FontMatch and its associated file type.
    private func processFile(at fileURL: URL) -> [(FontMatch, String)] {
        var matches: [(FontMatch, String)] = []
        do {
            // Check for cancellation before processing a potentially large file.
            guard !shouldCancelSearch else { return [] }

            let content = try String(contentsOf: fileURL, encoding: .utf8) // Read file content
            let regex = try NSRegularExpression(pattern: fontTagPattern, options: []) // Create regex
            let nsRange = NSRange(content.startIndex..<content.endIndex, in: content) // Define search range

            // Enumerate all matches of the regex pattern in the file content.
            regex.enumerateMatches(in: content, options: [], range: nsRange) { (result, _, _) in
                guard !shouldCancelSearch else { return } // Check for cancellation during enumeration

                if let match = result, match.numberOfRanges > 1, // Ensure a match and a captured group exist
                   let range = Range(match.range(at: 1), in: content) { // Get range of the captured group (font name)
                    let fontName = String(content[range]) // Extract font name
                    let fontMatch = FontMatch(fontName: fontName, filePath: fileURL.path) // Create FontMatch object
                    let fileType = "." + fileURL.pathExtension.lowercased() // Determine file type
                    matches.append((fontMatch, fileType)) // Add to matches
                }
            }
        } catch {
            // Silently ignore file read errors.
            // In a production app, consider logging these errors for debugging purposes.
            print("Error reading file \(fileURL.lastPathComponent): \(error.localizedDescription)")
        }
        return matches
    }

    /// Finalizes the search operation, updating the UI state.
    /// - Parameters:
    ///   - cancelled: True if the search was cancelled, false otherwise.
    ///   - message: An optional message to display as search progress.
    private func finalizeSearch(cancelled: Bool = false, message: String? = nil) {
        DispatchQueue.main.async {
            self.isSearching = false // Set searching state to false
            if cancelled {
                self.searchProgress = "Search cancelled."
            } else if let msg = message {
                self.searchProgress = msg
            }
        }
    }

    // MARK: - Export Methods

    /// Generates JSON data from the found fonts.
    /// - Returns: Data containing the JSON representation of found fonts, or nil if an error occurs.
    func exportJSONData() -> Data? {
        // Map FontMatch objects to a dictionary format suitable for JSON serialization.
        let exportableFonts = foundFonts.map { ["fontName": $0.fontName, "filePath": $0.filePath] }
        do {
            // Serialize the dictionary to JSON data with pretty printing.
            let jsonData = try JSONSerialization.data(withJSONObject: exportableFonts, options: .prettyPrinted)
            return jsonData
        } catch {
            errorMessage = "Failed to generate JSON data: \(error.localizedDescription)"
            return nil
        }
    }

    /// Generates CSV data from the found fonts.
    /// - Returns: Data containing the CSV representation of found fonts, or nil if an error occurs.
    func exportCSVData() -> Data? {
        var csvString = "Font Name,File Path,File Type\n" // CSV header
        for fontMatch in foundFonts {
            // Escape commas in font name and file path to prevent CSV parsing issues.
            let fontName = fontMatch.fontName.replacingOccurrences(of: ",", with: ";")
            let filePath = fontMatch.filePath.replacingOccurrences(of: ",", with: ";")
            // Get the associated file type, or "-" if not found.
            let fileType = fontNameToFileType[fontMatch.fontName] ?? "-"
            csvString += "\(fontName),\(filePath),\(fileType)\n" // Append data row
        }
        return csvString.data(using: .utf8) // Convert string to Data
    }
}
