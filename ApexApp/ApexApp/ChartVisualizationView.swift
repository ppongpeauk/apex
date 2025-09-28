//
//  ChartVisualizationView.swift
//  ApexApp
//
//  Created by Arman Mahjoor on 9/27/25.
//

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
                case "bar":
                    barChartView
                case "line":
                    lineChartView
                default:
                    lineChartView // Default to line chart
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
        let processedData = aggregateDataForLineChart()

        return Chart {
            ForEach(Array(processedData.enumerated()), id: \.offset) { index, item in
                LineMark(
                    x: .value(chartData.xLabel ?? "X", item.xValue),
                    y: .value(chartData.yLabel ?? "Y", item.yValue)
                )
                .foregroundStyle(.blue)
                .symbol(.circle)
            }
        }
        .chartXAxisLabel(chartData.xLabel ?? "X")
        .chartYAxisLabel(chartData.yLabel ?? "Y")
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(processedData.count, 8))) { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
    }
    
    // MARK: - Bar Chart
    private var barChartView: some View {
        // Aggregate and limit data for better visualization
        let processedData = aggregateDataForBarChart()

        return Chart {
            ForEach(Array(processedData.enumerated()), id: \.offset) { index, item in
                BarMark(
                    x: .value(chartData.xLabel ?? "X", item.label),
                    y: .value(chartData.yLabel ?? "Y", item.value)
                )
                .foregroundStyle(.blue)
            }
        }
        .chartXAxisLabel(chartData.xLabel ?? "X")
        .chartYAxisLabel(chartData.yLabel ?? "Y")
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(processedData.count, 10))) { _ in
                AxisValueLabel(anchor: .topLeading)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
            }
        }
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

    // MARK: - Data Processing
    struct BarChartItem {
        let label: String
        let value: Double
    }

    struct LineChartItem {
        let xValue: Double
        let yValue: Double
    }

    private func aggregateDataForBarChart() -> [BarChartItem] {
        // Group by X-axis values and aggregate Y values
        var groupedData: [String: [Double]] = [:]

        for point in chartData.dataPoints {
            guard let y = point.y else { continue }

            let xKey = point.x.stringValue
            let yValue = y.doubleValue

            if groupedData[xKey] == nil {
                groupedData[xKey] = []
            }
            groupedData[xKey]?.append(yValue)
        }

        // Convert to aggregated items (sum by default)
        let items = groupedData.compactMap { (key, values) -> BarChartItem? in
            guard !values.isEmpty else { return nil }
            let sum = values.reduce(0, +)
            return BarChartItem(label: key, value: sum)
        }

        // Sort by value (descending) and limit to 5 items for clean visualization
        return Array(items.sorted { $0.value > $1.value }.prefix(5))
    }

    private func aggregateDataForLineChart() -> [LineChartItem] {
        // For line charts, we want to show progression over X-axis
        var items: [LineChartItem] = []

        for point in chartData.dataPoints {
            guard let y = point.y else { continue }

            let xValue = point.x.doubleValue
            let yValue = y.doubleValue

            items.append(LineChartItem(xValue: xValue, yValue: yValue))
        }

        // Sort by X value and limit data points
        let sorted = items.sorted { $0.xValue < $1.xValue }

        // If we have too many points, sample them evenly (limit to 50 for performance)
        if sorted.count > 50 {
            let step = sorted.count / 50
            return stride(from: 0, to: sorted.count, by: step).compactMap { index in
                index < sorted.count ? sorted[index] : nil
            }
        }

        return sorted
    }

}
