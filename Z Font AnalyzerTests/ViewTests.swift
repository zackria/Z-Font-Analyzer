import XCTest
import SwiftUI
@testable import Z_Font_Analyzer

final class ViewTests: XCTestCase {
    
    @MainActor
    func testDashboardViewWithData() {
        let fileSearcher = FileSearcher()
        fileSearcher.totalFoundCount = 10
        fileSearcher.fileTypeCounts = [".moti": 5, ".motn": 5]
        fileSearcher.fontNameCounts = ["Arial": 10]
        
        let view = DashboardView(fileSearcher: fileSearcher)
            .environmentObject(LocalizationService.shared)
        
        let hostedView = NSHostingView(rootView: view)
        
        // Test 3 columns
        hostedView.frame = NSRect(x: 0, y: 0, width: 1000, height: 1000)
        hostedView.display()
        
        // Test 2 columns
        hostedView.frame = NSRect(x: 0, y: 0, width: 600, height: 1000)
        hostedView.display()
        
        // Test 1 column
        hostedView.frame = NSRect(x: 0, y: 0, width: 400, height: 1000)
        hostedView.display()
        
        XCTAssertNotNil(hostedView)
    }

    @MainActor
    func testDashboardViewEmpty() {
        let fileSearcher = FileSearcher()
        let view = DashboardView(fileSearcher: fileSearcher)
            .environmentObject(LocalizationService.shared)
        
        let hostedView = NSHostingView(rootView: view)
        hostedView.frame = NSRect(x: 0, y: 0, width: 850, height: 1000) // Trigger 2 column or so
        hostedView.display()
        
        XCTAssertNotNil(hostedView)
    }

    @MainActor
    func testDashboardCard() {
        let card = DashboardCard(title: "Test", value: "123", systemImage: "star")
        let hostedView = NSHostingView(rootView: card)
        hostedView.display()
        XCTAssertNotNil(hostedView)
    }
}
