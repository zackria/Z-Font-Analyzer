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
                            viewWidth = geo.size.width
                        }
                        .onChange(of: geo.size.width) { _, newValue in
                            viewWidth = newValue
                        }
                }
            )
        }
    }
    
    @ViewBuilder
    private var metricsSection: some View {
        let columns = viewWidth > 800 ? 3 : (viewWidth > 500 ? 2 : 1)
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
