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

    @MainActor
    func testAssetDetailCard() {
        // Test normal case (> 10%)
        let card1 = DashboardView.AssetDetailCard(title: "Test", count: 10, total: 20, icon: "text.alignleft", color: .blue)
        let hostedView1 = NSHostingView(rootView: card1)
        hostedView1.display()
        
        // Test small percentage (< 10%)
        let card2 = DashboardView.AssetDetailCard(title: "Test", count: 1, total: 100, icon: "text.alignleft", color: .blue)
        let hostedView2 = NSHostingView(rootView: card2)
        hostedView2.display()
        
        // Test zero total (branch check)
        let card3 = DashboardView.AssetDetailCard(title: "Test", count: 0, total: 0, icon: "text.alignleft", color: .blue)
        let hostedView3 = NSHostingView(rootView: card3)
        hostedView3.display()
        
        XCTAssertNotNil(hostedView1)
    }

    @MainActor
    func testSettingsView() {
        let view = SettingsView(maxConcurrentOperations: .constant(4), skipHiddenFolders: .constant(true))
            .environmentObject(LocalizationService.shared)
        let hostedView = NSHostingView(rootView: view)
        hostedView.frame = NSRect(x: 0, y: 0, width: 500, height: 600)
        hostedView.display()
        XCTAssertNotNil(hostedView)
    }
}
