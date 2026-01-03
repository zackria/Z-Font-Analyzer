import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var fileSearcher: FileSearcher
    @EnvironmentObject private var localization: LocalizationService
    
    @State private var viewWidth: CGFloat = 1000 // Default width
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("dashboard".localized)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .padding(.top, 8)
                    .accessibilityIdentifier("dashboard_title")
                
                // Responsive Metrics Row
                metricsSection
                
                // Responsive Charts Section
                chartsSection
            }
            .padding(32)
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
        }
    }
    
    @ViewBuilder
    private var metricsSection: some View {
        let columns = viewWidth > 800 ? 3 : (viewWidth > 500 ? 2 : 1)
        let assetColumns = viewWidth > 500 ? 4 : 2
        
        VStack(spacing: 24) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: columns), spacing: 20) {
                DashboardCard(
                    title: "files_processed".localized,
                    value: "\(fileSearcher.totalFoundCount)",
                    systemImage: "doc.on.doc"
                )
                DashboardCard(
                    title: "unique_fonts".localized,
                    value: "\(fileSearcher.fontNameCounts.keys.count)",
                    systemImage: "textformat"
                )
                DashboardCard(
                    title: "file_types".localized,
                    value: "\(fileSearcher.fileTypeCounts.count)",
                    systemImage: "folder.fill"
                )
            }
            
            // Motion Assets Detail Row
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: assetColumns), spacing: 16) {
                let total = fileSearcher.totalFoundCount
                AssetDetailCard(title: "motion_title".localized, count: fileSearcher.fileTypeCounts[".moti"] ?? 0, total: total, icon: "text.alignleft", color: .blue)
                AssetDetailCard(title: "motion_effect".localized, count: fileSearcher.fileTypeCounts[".moef"] ?? 0, total: total, icon: "wand.and.stars", color: .purple)
                AssetDetailCard(title: "motion_generator".localized, count: fileSearcher.fileTypeCounts[".motn"] ?? 0, total: total, icon: "gearshape.2.fill", color: .orange)
                AssetDetailCard(title: "motion_transition".localized, count: fileSearcher.fileTypeCounts[".motr"] ?? 0, total: total, icon: "arrow.left.and.right", color: .green)
            }
        }
    }
    
    // Sub-component for Asset Details
    struct AssetDetailCard: View {
        let title: String
        let count: Int
        let total: Int
        let icon: String
        let color: Color
        
        private var percentage: String {
            guard total > 0 else { return "0%" }
            let percent = Double(count) / Double(total) * 100
            if percent >= 10 {
                return String(format: "%.0f%%", percent)
            } else {
                return String(format: "%.1f%%", percent)
            }
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(count)")
                            .font(.title3.bold())
                        Text(percentage)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }
    
    @ViewBuilder
    private var chartsSection: some View {
        let columns = viewWidth > 900 ? 2 : 1
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: columns), spacing: 24) {
            chartContainer(title: "file_types_distribution".localized) {
                fileTypeChart
            }
            
            chartContainer(title: "top_fonts_used".localized) {
                topFontsChart
            }
        }
    }
    
    private func chartContainer<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            content()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
    
    @ViewBuilder
    private var fileTypeChart: some View {
        if !fileSearcher.fileTypeCounts.isEmpty {
            Chart {
                ForEach(fileSearcher.fileTypeCounts.sorted(by: { $0.key < $1.key }), id: \.key) { fileType, count in
                    SectorMark(
                        angle: .value("Count", count),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("File Type", fileType))
                    .cornerRadius(6)
                }
            }
            .frame(height: 300)
            .chartLegend(position: .bottom, spacing: 20)
        } else {
            emptyDataView(systemImage: "chart.pie")
        }
    }
    
    @ViewBuilder
    private var topFontsChart: some View {
        if !fileSearcher.fontNameCounts.isEmpty {
            let topFonts = Array(fileSearcher.fontNameCounts.sorted { $0.value > $1.value }.prefix(5))
            Chart {
                ForEach(topFonts, id: \.key) { font, count in
                    BarMark(
                        x: .value("Font", font),
                        y: .value("Count", count)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
            .frame(height: 300)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        } else {
            emptyDataView(systemImage: "chart.bar")
        }
    }
    
    private func emptyDataView(systemImage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text("no_data_available".localized)
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
    }
}
