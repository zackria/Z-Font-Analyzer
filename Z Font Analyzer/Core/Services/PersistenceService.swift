import Foundation
import SQLite3

final class PersistenceService: @unchecked Sendable {
    static let shared = PersistenceService()
    private var db: OpaquePointer?
    
    // Serial queue for database operations to ensure thread safety
    private let dbQueue = DispatchQueue(label: "com.zfontanalyzer.dbQueue", qos: .userInitiated)
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let dbURL = documentsURL.appendingPathComponent("fonts.sqlite")
        
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(dbURL.path, &db, flags, nil) != SQLITE_OK {
            print("Error opening database")
            return
        }
        
        // Optimize SQLite for performance and to reduce system file-access warnings
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA temp_store=MEMORY;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA cache_size=-5000;", nil, nil, nil) // 5MB cache
        sqlite3_exec(db, "PRAGMA mmap_size=268435456;", nil, nil, nil) // 256MB mmap
        sqlite3_exec(db, "PRAGMA page_size=4096;", nil, nil, nil)
        
        // Create FTS5 virtual table for high-performance searching
        let createTableQuery = """
        CREATE VIRTUAL TABLE IF NOT EXISTS fonts_fts USING fts5(
            fontName,
            filePath,
            fileType,
            tokenize='porter'
        );
        """
        
        if sqlite3_exec(db, createTableQuery, nil, nil, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("Error creating FTS table: \(error)")
        }
        
        // Create table for system font cache
        let createCacheTableQuery = """
        CREATE TABLE IF NOT EXISTS font_system_cache (
            fontName TEXT PRIMARY KEY,
            isInstalled INTEGER,
            realName TEXT
        );
        """
        sqlite3_exec(db, createCacheTableQuery, nil, nil, nil)
    }
    
    func clearDatabase() {
        dbQueue.sync {
            let deleteQuery = "DELETE FROM fonts_fts;"
            sqlite3_exec(db, deleteQuery, nil, nil, nil)
            let deleteCacheQuery = "DELETE FROM font_system_cache;"
            sqlite3_exec(db, deleteCacheQuery, nil, nil, nil)
        }
    }

    func updateSystemFontInfo(fontName: String, isInstalled: Bool, realName: String?) {
        dbQueue.sync {
            let query = "INSERT OR REPLACE INTO font_system_cache (fontName, isInstalled, realName) VALUES (?, ?, ?);"
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (fontName as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 2, isInstalled ? 1 : 0)
                if let realName = realName {
                    sqlite3_bind_text(statement, 3, (realName as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(statement, 3)
                }
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }
    
    func insertFontsBatch(_ fonts: [(FontMatch, String)]) {
        dbQueue.sync {
            sqlite3_exec(self.db, "BEGIN TRANSACTION;", nil, nil, nil)
            
            let insertQuery = "INSERT INTO fonts_fts (fontName, filePath, fileType) VALUES (?, ?, ?);"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, insertQuery, -1, &statement, nil) == SQLITE_OK {
                for (match, fileType) in fonts {
                    sqlite3_bind_text(statement, 1, (match.fontName as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(statement, 2, (match.filePath as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(statement, 3, (fileType as NSString).utf8String, -1, nil)
                    
                    if sqlite3_step(statement) != SQLITE_DONE {
                        print("Error inserting row")
                    }
                    sqlite3_reset(statement)
                }
            }
            sqlite3_finalize(statement)
            sqlite3_exec(self.db, "COMMIT;", nil, nil, nil)
        }
    }
    
    func searchFonts(query: String, limit: Int = 1000) -> [FontMatch] {
        var results = [FontMatch]()
        dbQueue.sync {
            let escapedQuery = query.replacingOccurrences(of: "\"", with: "\"\"")
            let searchQuery: String
            
            if query.isEmpty {
                searchQuery = "SELECT rowid, fontName, filePath FROM fonts_fts LIMIT ?;"
            } else {
                searchQuery = "SELECT rowid, fontName, filePath FROM fonts_fts WHERE fonts_fts MATCH ? ORDER BY rank LIMIT ?;"
            }
            
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, searchQuery, -1, &statement, nil) == SQLITE_OK {
                var bindIndex: Int32 = 1
                if !query.isEmpty {
                    // Wrap query in quotes to handle special characters like - or spaces
                    let ftsQuery = "\"\(escapedQuery)\"*"
                    sqlite3_bind_text(statement, bindIndex, (ftsQuery as NSString).utf8String, -1, nil)
                    bindIndex += 1
                }
                sqlite3_bind_int(statement, bindIndex, Int32(limit))
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let rowId = sqlite3_column_int64(statement, 0)
                    let fontName = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
                    let filePath = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
                    results.append(FontMatch(id: String(rowId), fontName: fontName, filePath: filePath))
                }
            } else {
                let error = String(cString: sqlite3_errmsg(db))
                print("Error preparing searchFonts statement: \(error)")
            }
            sqlite3_finalize(statement)
        }
        return results
    }
    
    func getTotalFontsCount() -> Int {
        var count = 0
        dbQueue.sync {
            let query = "SELECT COUNT(*) FROM fonts_fts;"
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                if sqlite3_step(statement) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(statement, 0))
                }
            }
            sqlite3_finalize(statement)
        }
        return count
    }
    
    func getAllFonts(limit: Int = 1000) -> [FontMatch] {
        var results = [FontMatch]()
        dbQueue.sync {
            let query = "SELECT rowid, fontName, filePath FROM fonts_fts LIMIT ?;"
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_int(statement, 1, Int32(limit))
                while sqlite3_step(statement) == SQLITE_ROW {
                    let rowId = sqlite3_column_int64(statement, 0)
                    let fontName = String(cString: sqlite3_column_text(statement, 1))
                    let filePath = String(cString: sqlite3_column_text(statement, 2))
                    results.append(FontMatch(id: String(rowId), fontName: fontName, filePath: filePath))
                }
            }
            sqlite3_finalize(statement)
        }
        return results
    }
    
    func getFilteredFontsSummary(query: String) -> [FontSummaryRow] {
        var results = [FontSummaryRow]()
        dbQueue.sync {
            let escapedQuery = query.replacingOccurrences(of: "\"", with: "\"\"")
            let searchQuery: String
            
            if query.isEmpty {
                searchQuery = """
                SELECT f.fontName, f.fileType, COUNT(*) as count, s.isInstalled, s.realName
                FROM fonts_fts f
                LEFT JOIN font_system_cache s ON f.fontName = s.fontName
                GROUP BY f.fontName, f.fileType 
                ORDER BY f.fontName;
                """
            } else {
                searchQuery = """
                SELECT f.fontName, f.fileType, COUNT(*) as count, s.isInstalled, s.realName
                FROM fonts_fts f
                JOIN (
                    SELECT DISTINCT fontName 
                    FROM fonts_fts 
                    WHERE fonts_fts MATCH ?
                ) m ON f.fontName = m.fontName
                LEFT JOIN font_system_cache s ON f.fontName = s.fontName
                GROUP BY f.fontName, f.fileType 
                ORDER BY f.fontName;
                """
            }
            
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, searchQuery, -1, &statement, nil) == SQLITE_OK {
                if !query.isEmpty {
                    // Wrap query in quotes to handle special characters like - or spaces
                    let ftsQuery = "\"\(escapedQuery)\"*"
                    sqlite3_bind_text(statement, 1, (ftsQuery as NSString).utf8String, -1, nil)
                }
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let fontName = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
                    let fileType = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ".moti"
                    let count = Int(sqlite3_column_int(statement, 2))
                    
                    let existsInSystem: Bool? = sqlite3_column_type(statement, 3) == SQLITE_NULL ? nil : (sqlite3_column_int(statement, 3) != 0)
                    let realNameInSystem: String? = sqlite3_column_text(statement, 4).map { String(cString: $0) }
                    
                    results.append(FontSummaryRow(
                        fontName: fontName, 
                        fileType: fileType, 
                        count: count,
                        existsInSystem: existsInSystem,
                        systemFontName: realNameInSystem
                    ))
                }
            } else {
                let error = String(cString: sqlite3_errmsg(db))
                print("Error preparing getFilteredFontsSummary statement: \(error)")
            }
            sqlite3_finalize(statement)
        }
        return results
    }


    // MARK: - Async Support
    
    func getFilteredFontsSummaryAsync(query: String) async -> [FontSummaryRow] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.getFilteredFontsSummary(query: query)
                continuation.resume(returning: result)
            }
        }
    }
    
    func searchFontsAsync(query: String, limit: Int = 1000) async -> [FontMatch] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.searchFonts(query: query, limit: limit)
                continuation.resume(returning: result)
            }
        }
    }
}

