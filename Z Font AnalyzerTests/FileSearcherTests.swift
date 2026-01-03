import XCTest
import Combine
@testable import Z_Font_Analyzer

final class FileSearcherTests: XCTestCase {
    var fileSearcher: FileSearcher!
    var tempDir: URL!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        fileSearcher = FileSearcher()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        cancellables = []
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        cancellables = nil
        super.tearDown()
    }
    
    func testProcessFileWithFontTag() throws {
        let fileURL = tempDir.appendingPathComponent("test.motn")
        let content = "Some content <font>TestFontName</font> more content"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        let expectation = XCTestExpectation(description: "Search completes")
        
        var searchStarted = false
        fileSearcher.$isSearching
            .receive(on: DispatchQueue.main)
            .sink { isSearching in
                if isSearching {
                    searchStarted = true
                } else if searchStarted && !isSearching {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        fileSearcher.startSearch(in: tempDir, maxConcurrentOperations: 1, skipHiddenFolders: true)
        
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertEqual(fileSearcher.totalFoundCount, 1)
        XCTAssertEqual(fileSearcher.foundFonts.first?.fontName, "TestFontName")
    }
    
    func testSearchCancellation() throws {
        let fileURL = tempDir.appendingPathComponent("test.motn")
        let content = "<font>Test</font>"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        let expectation = XCTestExpectation(description: "Progress updates to Cancel Search")
        fileSearcher.$searchProgress
            .sink { progress in
                if progress == "cancel_search".localized {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
            
        fileSearcher.startSearch(in: tempDir, maxConcurrentOperations: 1, skipHiddenFolders: true)
        fileSearcher.cancelSearch()
        
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(fileSearcher.searchProgress, "cancel_search".localized)
    }
    
    func testInvalidDirectory() {
        let invalidURL = URL(string: "http://google.com")!
        
        let expectation = XCTestExpectation(description: "Error message updated")
        
        fileSearcher.$errorMessage
            .dropFirst()
            .sink { message in
                if message == "invalid_directory".localized {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
            
        fileSearcher.startSearch(in: invalidURL, maxConcurrentOperations: 1, skipHiddenFolders: true)
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertFalse(fileSearcher.isSearching)
        XCTAssertEqual(fileSearcher.errorMessage, "invalid_directory".localized)
    }
    
    func testSkipHiddenFolders() throws {
        let hiddenDir = tempDir.appendingPathComponent(".hidden", isDirectory: true)
        try FileManager.default.createDirectory(at: hiddenDir, withIntermediateDirectories: true)
        let fileURL = hiddenDir.appendingPathComponent("test.motn")
        try "<font>Hidden</font>".write(to: fileURL, atomically: true, encoding: .utf8)
        
        let expectation = XCTestExpectation(description: "Search completes")
        var searchStarted = false
        fileSearcher.$isSearching
            .receive(on: DispatchQueue.main)
            .sink { isSearching in
                if isSearching {
                    searchStarted = true
                } else if searchStarted && !isSearching {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        fileSearcher.startSearch(in: tempDir, maxConcurrentOperations: 1, skipHiddenFolders: true)
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(fileSearcher.totalFoundCount, 0)
    }

    func testDoNotSkipHiddenFolders() throws {
        let hiddenDir = tempDir.appendingPathComponent(".hidden", isDirectory: true)
        try FileManager.default.createDirectory(at: hiddenDir, withIntermediateDirectories: true)
        let fileURL = hiddenDir.appendingPathComponent("test.motn")
        try "<font>VisibleInsideHidden</font>".write(to: fileURL, atomically: true, encoding: .utf8)
        
        let expectation = XCTestExpectation(description: "Search completes")
        var searchStarted = false
        fileSearcher.$isSearching
            .receive(on: DispatchQueue.main)
            .sink { isSearching in
                if isSearching {
                    searchStarted = true
                } else if searchStarted && !isSearching {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        fileSearcher.startSearch(in: tempDir, maxConcurrentOperations: 1, skipHiddenFolders: false)
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(fileSearcher.totalFoundCount, 1)
    }

    func testBatchInsertion() throws {
        for i in 1...600 {
            let fileURL = tempDir.appendingPathComponent("test\(i).motn")
            try "<font>Font\(i)</font>".write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        let expectation = XCTestExpectation(description: "Search completes")
        var searchStarted = false
        fileSearcher.$isSearching
            .receive(on: DispatchQueue.main)
            .sink { isSearching in
                if isSearching {
                    searchStarted = true
                } else if searchStarted && !isSearching {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        fileSearcher.startSearch(in: tempDir, maxConcurrentOperations: 4, skipHiddenFolders: true)
        wait(for: [expectation], timeout: 20.0)
        XCTAssertEqual(fileSearcher.totalFoundCount, 600)
    }

    func testStopAccessingDirectory() {
        fileSearcher.stopAccessingCurrentDirectory()
    }

    func testAccessError() {
        let nonExistentDir = URL(fileURLWithPath: "/private/var/root/non_existent_z_font_test")
        fileSearcher.startSearch(in: nonExistentDir, maxConcurrentOperations: 1, skipHiddenFolders: true)
    }

    func testFinalizeSearch() {
        let emptyDir = tempDir.appendingPathComponent("empty", isDirectory: true)
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        
        let expectation = XCTestExpectation(description: "Search completes")
        var searchStarted = false
        fileSearcher.$isSearching
            .receive(on: DispatchQueue.main)
            .sink { isSearching in
                if isSearching {
                    searchStarted = true
                } else if searchStarted && !isSearching {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
            
        fileSearcher.startSearch(in: emptyDir, maxConcurrentOperations: 1, skipHiddenFolders: true)
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertEqual(fileSearcher.searchProgress, "no_target_files".localized)
    }

    func testProcessFileError() throws {
        let binaryFile = tempDir.appendingPathComponent("binary.motn")
        let data = Data([0xFF, 0xD8, 0xFF]) // Not valid UTF-8
        try data.write(to: binaryFile)
        
        let expectation = XCTestExpectation(description: "Search completes")
        var searchStarted = false
        fileSearcher.$isSearching
            .receive(on: DispatchQueue.main)
            .sink { isSearching in
                if isSearching {
                    searchStarted = true
                } else if searchStarted && !isSearching {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
            
        fileSearcher.startSearch(in: tempDir, maxConcurrentOperations: 1, skipHiddenFolders: true)
        wait(for: [expectation], timeout: 5.0)
        
        // Error is printed to console, matches should be empty
        XCTAssertEqual(fileSearcher.totalFoundCount, 0)
    }
}
