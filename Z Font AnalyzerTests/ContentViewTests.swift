import XCTest
import SwiftUI
@testable import Z_Font_Analyzer

final class ContentViewTests: XCTestCase {
    
    @MainActor
    func testContentViewInitialization() {
        let fileSearcher = FileSearcher()
        let localization = LocalizationService.shared
        
        // This will at least initialize the view and execute the top-level property initializers
        let contentView = ContentView()
            .environmentObject(fileSearcher)
            .environmentObject(localization)
        
        let hostedView = NSHostingView(rootView: contentView)
        hostedView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        hostedView.display()
        
        XCTAssertNotNil(contentView)
    }
}
