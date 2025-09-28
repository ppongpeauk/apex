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
  @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
      // Chart content with horizontal scrolling
      ScrollView(.horizontal, showsIndicators: true) {
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
        .frame(minWidth: calculateOptimalChartWidth()) // Dynamic width based on data points
            .chartBackground { chartProxy in
                Color.clear
        }
      }
      .scrollIndicators(.visible)
      .frame(maxHeight: 400)

      // Scroll position indicator
      if chartData.dataPoints.count > 20 {
        scrollPositionIndicator
            }
            
            // Data summary
            dataSummaryView
        }
        .padding()
    }
    
    // MARK: - Line Chart
    private var lineChartView: some View {
    let processedData: [LineChartItem] = aggregateDataForLineChart()
    let xLabel: String = chartData.xLabel ?? "X"
    let yLabel: String = chartData.yLabel ?? "Y"
    
    print("📊 [LineChart] Rendering chart with \(processedData.count) points")
    if let first = processedData.first, let last = processedData.last {
      print("📊 [LineChart] X range: \(first.xValue) to \(last.xValue)")
      print("📊 [LineChart] Y range: \(first.yValue) to \(last.yValue)")
    }
    
    return Chart(processedData) { item in
                    LineMark(
        x: .value(xLabel, item.xValue),
        y: .value(yLabel, item.yValue)
                    )
                    .foregroundStyle(.blue)
                    .symbol(.circle)
      .symbolSize(50)
    }
    .chartXAxisLabel(xLabel)
    .chartYAxisLabel(yLabel)
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: min(processedData.count, 10))) { value in
        AxisValueLabel()
          .font(.caption2)
        AxisGridLine()
      }
    }
    .chartYAxis {
      AxisMarks { value in
        AxisValueLabel()
          .font(.caption2)
        AxisGridLine()
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
    let xLabel: String = chartData.xLabel ?? "X"
    let yLabel: String = chartData.yLabel ?? "Y"
    
    return Chart(processedData) { item in
                    BarMark(
        x: .value(xLabel, item.label),
        y: .value(yLabel, item.value)
                    )
                    .foregroundStyle(.blue)
                }
    .chartXAxisLabel(xLabel)
    .chartYAxisLabel(yLabel)
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: min(processedData.count, 15))) { _ in
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
    let xLabel: String = chartData.xLabel ?? "X"
    let yLabel: String = chartData.yLabel ?? "Y"
    let uniqueXValues = unique(processedData.map { $0.xValue })

    return Chart(processedData) { item in
      BarMark(
        x: .value(xLabel, item.xValue),
        y: .value(yLabel, item.yValue)
      )
      .foregroundStyle(by: .value("Category", item.category))
      .position(by: .value("Category", item.category))
    }
    .chartXAxisLabel(xLabel)
    .chartYAxisLabel(yLabel)
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: min(uniqueXValues.count, 15))) { _ in
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

  // MARK: - Scroll Position Indicator
  private var scrollPositionIndicator: some View {
    HStack {
      Image(systemName: "arrow.left.and.right")
        .foregroundColor(.secondary)
      Text("Scroll horizontally to view all data points")
        .font(.caption)
        .foregroundColor(.secondary)
      Spacer()
      Text("\(chartData.dataPoints.count) total points")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .background(Color(.windowBackgroundColor))
    .cornerRadius(6)
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
  
  // Helper extension for Array to get unique values
  private func unique<T: Hashable>(_ array: [T]) -> [T] {
    return Array(Set(array))
  }
  
  // Calculate optimal chart width based on data characteristics
  private func calculateOptimalChartWidth() -> CGFloat {
    let dataPointCount = chartData.dataPoints.count
    let baseWidth: CGFloat = 600
    
    // For bar charts, we need more space per data point
    if chartData.chartType == "bar" {
      return max(baseWidth, CGFloat(dataPointCount) * 60)
    }
    
    // For line charts, we can be more compact
    return max(baseWidth, CGFloat(dataPointCount) * 40)
  }

  // MARK: - Data Processing
  struct BarChartItem: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
  }

  struct StackedBarChartItem: Identifiable {
    let id = UUID()
    let xValue: String
    let category: String
    let yValue: Double
  }

  struct LineChartItem: Identifiable {
    let id = UUID()
    let xValue: String  // Use String to preserve actual date/number formatting
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

    // Sort by value (descending) and return all items
    return items.sorted { $0.value > $1.value }
  }

  private func aggregateDataForLineChart() -> [LineChartItem] {
    // For line charts, we want to show progression over X-axis using actual values
    var items: [LineChartItem] = []
    
    print("🔍 [LineChart] Processing \(chartData.dataPoints.count) data points")
    
    for (index, point) in chartData.dataPoints.enumerated() {
      guard let y = point.y else { 
        print("⚠️ [LineChart] Skipping point \(index): no y value")
        continue 
      }

      // Use the string representation to preserve actual date/number formatting
      let xValue = point.x.stringValue
      let yValue = y.doubleValue
      
      print("📊 [LineChart] Point \(index): x=\(xValue), y=\(yValue)")
      items.append(LineChartItem(xValue: xValue, yValue: yValue))
    }

    // Sort by X value for proper line progression
    let sorted = items.sorted { 
      // Sort by the string representation for consistent ordering
      $0.xValue < $1.xValue 
    }
    
    print("📊 [LineChart] Sorted data range: x=\(sorted.first?.xValue ?? "nil") to \(sorted.last?.xValue ?? "nil")")
    print("📊 [LineChart] Returning all \(sorted.count) data points")
    return sorted
  }
  
  // Helper function to parse date strings
  private func parseDateString(_ dateString: String) -> Date? {
    let formatters = [
      "yyyy-MM-dd",
      "yyyy-MM-dd HH:mm:ss",
      "MM/dd/yyyy",
      "dd/MM/yyyy",
      "yyyy-MM-dd'T'HH:mm:ss",
      "yyyy-MM-dd'T'HH:mm:ss.SSS",
      "yyyy-MM-dd'T'HH:mm:ss'Z'"
    ]
    
    for format in formatters {
      let formatter = DateFormatter()
      formatter.dateFormat = format
      if let date = formatter.date(from: dateString) {
        return date
      }
    }
    
    // Try ISO8601 as fallback
    let iso8601Formatter = ISO8601DateFormatter()
    return iso8601Formatter.date(from: dateString)
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
