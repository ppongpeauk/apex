import SwiftUI
import Charts
import Combine

struct ChartVisualizationView: View {
    let chartData: ChartData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chart content
            Group {
                switch chartData.chartType {
                case "line":
                    lineChartView
                case "bar":
                    barChartView
                case "scatter":
                    scatterChartView
                case "pie":
                    pieChartView
                case "histogram":
                    histogramView
                case "box":
                    boxPlotView
                case "heatmap":
                    heatmapView
                default:
                    barChartView // Default fallback
                }
            }
            .frame(minHeight: 300)
            .chartBackground { chartProxy in
                Color.clear
            }
            
            // Data summary
            dataSummaryView
        }
        .padding()
    }
    
    // MARK: - Line Chart
    private var lineChartView: some View {
        Chart {
            ForEach(chartData.dataPoints) { point in
                if let y = point.y {
                    LineMark(
                        x: .value(chartData.xLabel ?? "X", point.x.doubleValue),
                        y: .value(chartData.yLabel ?? "Y", y.doubleValue)
                    )
                    .foregroundStyle(.blue)
                    .symbol(.circle)
                }
            }
        }
        .chartXAxisLabel(chartData.xLabel ?? "X")
        .chartYAxisLabel(chartData.yLabel ?? "Y")
    }
    
    // MARK: - Bar Chart
    private var barChartView: some View {
        Chart {
            ForEach(chartData.dataPoints.prefix(20)) { point in // Limit for readability
                if let y = point.y {
                    BarMark(
                        x: .value(chartData.xLabel ?? "X", point.x.stringValue),
                        y: .value(chartData.yLabel ?? "Y", y.doubleValue)
                    )
                    .foregroundStyle(.blue)
                }
            }
        }
        .chartXAxisLabel(chartData.xLabel ?? "X")
        .chartYAxisLabel(chartData.yLabel ?? "Y")
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .rotationEffect(.degrees(-45))
            }
        }
    }
    
    // MARK: - Scatter Plot
    private var scatterChartView: some View {
        Chart {
            ForEach(chartData.dataPoints) { point in
                if let y = point.y {
                    PointMark(
                        x: .value(chartData.xLabel ?? "X", point.x.doubleValue),
                        y: .value(chartData.yLabel ?? "Y", y.doubleValue)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(50)
                }
            }
        }
        .chartXAxisLabel(chartData.xLabel ?? "X")
        .chartYAxisLabel(chartData.yLabel ?? "Y")
    }
    
    // MARK: - Pie Chart (using SectorMark)
    private var pieChartView: some View {
        let limitedData = Array(chartData.dataPoints.prefix(8)) // Limit slices for readability
        
        return Chart {
            ForEach(limitedData) { point in
                if let y = point.y {
                    SectorMark(
                        angle: .value("Value", y.doubleValue),
                        innerRadius: .ratio(0.4),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", point.x.stringValue))
                }
            }
        }
        .frame(height: 400)
        .chartLegend(position: .trailing)
    }
    
    // MARK: - Histogram
    private var histogramView: some View {
        let bins = createHistogramBins(from: chartData.dataPoints.compactMap { $0.y?.doubleValue })
        
        return Chart {
            ForEach(bins, id: \.range) { bin in
                BarMark(
                    x: .value("Range", "\(String(format: "%.1f", bin.range.lowerBound))-\(String(format: "%.1f", bin.range.upperBound))"),
                    y: .value("Frequency", bin.count)
                )
                .foregroundStyle(.blue)
            }
        }
        .chartXAxisLabel("Value Range")
        .chartYAxisLabel("Frequency")
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .rotationEffect(.degrees(-45))
            }
        }
    }
    
    // MARK: - Box Plot (simplified as range bars)
    private var boxPlotView: some View {
        let stats = calculateBoxPlotStats(from: chartData.dataPoints.compactMap { $0.y?.doubleValue })
        
        return Chart {
            // Whiskers
            RectangleMark(
                xStart: .value("Category", "Data"),
                xEnd: .value("Category", "Data"),
                yStart: .value("Min", stats.min),
                yEnd: .value("Q1", stats.q1)
            )
            .foregroundStyle(.gray)
            
            // Box
            RectangleMark(
                xStart: .value("Category", "Data"),
                xEnd: .value("Category", "Data"),
                yStart: .value("Q1", stats.q1),
                yEnd: .value("Q3", stats.q3)
            )
            .foregroundStyle(.blue.opacity(0.7))
            
            // Median line
            RectangleMark(
                xStart: .value("Category", "Data"),
                xEnd: .value("Category", "Data"),
                yStart: .value("Median", stats.median),
                yEnd: .value("Median", stats.median + 0.1)
            )
            .foregroundStyle(.red)
            
            // Upper whisker
            RectangleMark(
                xStart: .value("Category", "Data"),
                xEnd: .value("Category", "Data"),
                yStart: .value("Q3", stats.q3),
                yEnd: .value("Max", stats.max)
            )
            .foregroundStyle(.gray)
        }
        .chartYAxisLabel(chartData.yLabel ?? "Values")
    }
    
    // MARK: - Heatmap (simplified grid)
    private var heatmapView: some View {
        let gridData = createHeatmapGrid(from: chartData.dataPoints)
        
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(gridData.columns, 10))) {
            ForEach(0..<min(gridData.data.count, 100), id: \.self) { index in
                Rectangle()
                    .fill(Color.blue.opacity(gridData.data[index]))
                    .frame(height: 30)
                    .cornerRadius(4)
            }
        }
        .padding()
    }
    
    // MARK: - Data Summary
    private var dataSummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data Summary")
                .font(.headline)
            
            HStack {
                Label("\(chartData.dataPoints.count) data points", systemImage: "number.circle")
                Spacer()
                if let originalData = chartData.originalData as? [String: Any],
                   let shape = originalData["shape"] as? [Int] {
                    Label("\(shape[0]) rows × \(shape[1]) columns", systemImage: "tablecells")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Helper Functions
extension ChartVisualizationView {
    private func createHistogramBins(from values: [Double]) -> [(range: ClosedRange<Double>, count: Int)] {
        guard !values.isEmpty else { return [] }
        
        let sortedValues = values.sorted()
        let min = sortedValues.first!
        let max = sortedValues.last!
        let binCount = min(Int(sqrt(Double(values.count))), 20) // Optimal bin count
        let binWidth = (max - min) / Double(binCount)
        
        var bins: [(range: ClosedRange<Double>, count: Int)] = []
        
        for i in 0..<binCount {
            let start = min + Double(i) * binWidth
            let end = i == binCount - 1 ? max : start + binWidth
            let range = start...end
            let count = values.filter { range.contains($0) }.count
            bins.append((range: range, count: count))
        }
        
        return bins
    }
    
    private func calculateBoxPlotStats(from values: [Double]) -> (min: Double, q1: Double, median: Double, q3: Double, max: Double) {
        guard !values.isEmpty else { return (0, 0, 0, 0, 0) }
        
        let sorted = values.sorted()
        let count = sorted.count
        
        let min = sorted.first!
        let max = sorted.last!
        let median = count % 2 == 0 ? (sorted[count/2 - 1] + sorted[count/2]) / 2 : sorted[count/2]
        let q1 = sorted[count/4]
        let q3 = sorted[3*count/4]
        
        return (min: min, q1: q1, median: median, q3: q3, max: max)
    }
    
    private func createHeatmapGrid(from points: [DataPoint]) -> (data: [Double], columns: Int) {
        // Simplified heatmap - create a grid based on data distribution
        let values = points.compactMap { $0.y?.doubleValue }
        guard !values.isEmpty else { return (data: [], columns: 0) }
        
        let max = values.max()!
        let normalized = values.map { $0 / max }
        
        let columns = min(Int(sqrt(Double(normalized.count))), 10)
        return (data: normalized, columns: columns)
    }
}
