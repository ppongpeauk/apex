//
//  ChartVisualizationView.swift
//  ApexApp
//
//  Created by Arman Mahjoor on 9/27/25.
//

import Charts
import Combine
import SwiftUI

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
          lineChartView  // Default to line chart
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
    // Check if we should use stacked bar chart (multiple categories per X value)
    let shouldUseStacked = shouldUseStackedBarChart()

    if shouldUseStacked {
      let processedData = aggregateDataForStackedBarChart()
      return AnyView(stackedBarChartView(processedData))
    } else {
      let processedData = aggregateDataForBarChart()
      return AnyView(regularBarChartView(processedData))
    }
  }

  private func regularBarChartView(_ processedData: [BarChartItem]) -> some View {
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

  private func stackedBarChartView(_ processedData: [StackedBarChartItem]) -> some View {
    let uniqueCategories = Set(processedData.map { $0.category })

    return Chart {
      ForEach(Array(processedData.enumerated()), id: \.offset) { index, item in
        BarMark(
          x: .value(chartData.xLabel ?? "X", item.xValue),
          y: .value(chartData.yLabel ?? "Y", item.yValue)
        )
        .foregroundStyle(by: .value("Category", item.category))
        .position(by: .value("Category", item.category))
      }
    }
    .chartXAxisLabel(chartData.xLabel ?? "X")
    .chartYAxisLabel(chartData.yLabel ?? "Y")
    .chartXAxis {
      AxisMarks(
        values: .automatic(desiredCount: min(processedData.map { $0.xValue }.unique().count, 10))
      ) { _ in
        AxisValueLabel(anchor: .topLeading)
          .font(.caption2)
      }
    }
    .chartYAxis {
      AxisMarks { _ in
        AxisValueLabel()
      }
    }
    .chartLegend(position: .top, alignment: .leading) {
      ForEach(Array(uniqueCategories).sorted(), id: \.self) { category in
        HStack {
          Circle()
            .fill(getCategoryColor(category))
            .frame(width: 8, height: 8)
          Text(category)
            .font(.caption)
        }
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
          let shape = originalData["shape"] as? [Int]
        {
          Label("\(shape[0]) rows × \(shape[1]) columns", systemImage: "tablecells")
        }
      }
      .font(.caption)
      .foregroundColor(.secondary)
    }
    .padding()
    .background(Color(.windowBackgroundColor))
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

  struct StackedBarChartItem {
    let xValue: String
    let category: String
    let yValue: Double
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

  private func shouldUseStackedBarChart() -> Bool {
    // Check if we have categorical data that would benefit from stacking
    guard let originalData = chartData.originalData as? [String: Any],
      let columns = originalData["columns"] as? [String]
    else {
      return false
    }

    // Look for potential category columns (non-numeric, non-datetime columns)
    let categoricalColumns = columns.filter { column in
      guard let dtypes = originalData["dtypes"] as? [String: String] else { return false }
      let dtype = dtypes[column] ?? ""
      return !dtype.contains("int") && !dtype.contains("float") && !dtype.contains("datetime")
        && column != chartData.xLabel && column != chartData.yLabel
    }

    // Check if we have multiple categories per X value
    if let rawData = originalData["raw_data"] as? [[String: Any]] {
      let xColumn = chartData.xLabel ?? ""
      let categoryColumns = categoricalColumns.filter { $0 != xColumn }

      for categoryColumn in categoryColumns {
        var xCategoryCount: [String: Set<String>] = [:]

        for row in rawData {
          if let xValue = row[xColumn] as? String,
            let categoryValue = row[categoryColumn] as? String
          {
            if xCategoryCount[xValue] == nil {
              xCategoryCount[xValue] = Set<String>()
            }
            xCategoryCount[xValue]?.insert(categoryValue)
          }
        }

        // If any X value has multiple categories, use stacked chart
        for (_, categories) in xCategoryCount {
          if categories.count > 1 {
            return true
          }
        }
      }
    }

    return false
  }

  private func aggregateDataForStackedBarChart() -> [StackedBarChartItem] {
    guard let originalData = chartData.originalData as? [String: Any],
      let rawData = originalData["raw_data"] as? [[String: Any]]
    else {
      return []
    }

    let xColumn = chartData.xLabel ?? ""
    let yColumn = chartData.yLabel ?? ""

    // Find a suitable category column
    let categoryColumn = findBestCategoryColumn()

    var stackedItems: [StackedBarChartItem] = []

    for row in rawData {
      if let xValue = row[xColumn] as? String,
        let yValue = row[yColumn] as? Double,
        let categoryValue = row[categoryColumn] as? String
      {
        stackedItems.append(
          StackedBarChartItem(
            xValue: xValue,
            category: categoryValue,
            yValue: yValue
          ))
      }
    }

    return stackedItems
  }

  private func findBestCategoryColumn() -> String {
    guard let originalData = chartData.originalData as? [String: Any],
      let columns = originalData["columns"] as? [String]
    else {
      return ""
    }

    let xColumn = chartData.xLabel ?? ""
    let yColumn = chartData.yLabel ?? ""

    // Look for categorical columns that aren't X or Y
    let candidateColumns = columns.filter { column in
      guard let dtypes = originalData["dtypes"] as? [String: String] else { return false }
      let dtype = dtypes[column] ?? ""
      return column != xColumn && column != yColumn && !dtype.contains("int")
        && !dtype.contains("float") && !dtype.contains("datetime")
    }

    // Return the first suitable category column
    return candidateColumns.first ?? ""
  }

  private func getCategoryColor(_ category: String) -> Color {
    // Generate consistent colors for categories
    let colors: [Color] = [
      .blue, .green, .orange, .purple, .pink, .red, .yellow, .cyan, .mint, .indigo,
    ]

    let hash = category.hash
    let index = abs(hash) % colors.count
    return colors[index]
  }
}

extension Array where Element == String {
  func unique() -> [Element] {
    var uniqueElements: [Element] = []
    for element in self {
      if !uniqueElements.contains(element) {
        uniqueElements.append(element)
      }
    }
    return uniqueElements
  }
}
