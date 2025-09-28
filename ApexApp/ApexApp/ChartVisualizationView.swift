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
                case "scatter":
                    scatterChartView
                case "pie":
                    pieChartView
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
      if getDisplayedDataPointCount() > 20 {
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

  // MARK: - Scatter Chart
  private var scatterChartView: some View {
    let processedData: [ScatterChartItem] = aggregateDataForScatterChart()
    let xLabel: String = chartData.xLabel ?? "X"
    let yLabel: String = chartData.yLabel ?? "Y"
    
    print("📊 [ScatterChart] Rendering chart with \(processedData.count) points")
    if let first = processedData.first, let last = processedData.last {
      print("📊 [ScatterChart] X range: \(first.xValue) to \(last.xValue)")
      print("📊 [ScatterChart] Y range: \(first.yValue) to \(last.yValue)")
    }
    
    return Chart(processedData) { item in
      PointMark(
        x: .value(xLabel, item.xValue),
        y: .value(yLabel, item.yValue)
      )
      .foregroundStyle(.blue)
      .symbolSize(50)
    }
    .chartXAxisLabel(xLabel)
    .chartYAxisLabel(yLabel)
    .chartXAxis {
      AxisMarks { _ in
        AxisValueLabel()
      }
    }
    .chartYAxis {
      AxisMarks { _ in
        AxisValueLabel()
      }
    }
  }

  // MARK: - Pie Chart
  private var pieChartView: some View {
    let processedData: [PieChartItem] = aggregateDataForPieChart()
    let xLabel: String = chartData.xLabel ?? "Category"
    let yLabel: String = chartData.yLabel ?? "Value"
    
    print("📊 [PieChart] Rendering chart with \(processedData.count) segments")
    
    return Chart(processedData) { item in
      SectorMark(
        angle: .value(yLabel, item.value),
        innerRadius: .ratio(0.2),
        angularInset: 2
      )
      .foregroundStyle(by: .value(xLabel, item.label))
    }
    .chartLegend(position: .bottom, alignment: .center)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .frame(width: 400, height: 400)
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
      Text("\(getDisplayedDataPointCount()) displayed points")
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
  
  // Calculate optimal chart width based on actual displayed data points
  private func calculateOptimalChartWidth() -> CGFloat {
    let displayedDataPointCount = getDisplayedDataPointCount()
    let baseWidth: CGFloat = 600
    
    switch chartData.chartType {
    case "bar":
      // For bar charts, we need more space per data point
      return max(baseWidth, CGFloat(displayedDataPointCount) * 60)
      
    case "line":
      // For line charts, we can be more compact
      return max(baseWidth, CGFloat(displayedDataPointCount) * 40)
      
    case "scatter":
      // For scatter plots, we need space for all points
      return max(baseWidth, CGFloat(displayedDataPointCount) * 30)
      
    case "pie":
      // For pie charts, we don't need much horizontal space
      return baseWidth
      
    default:
      // Default to line chart behavior
      return max(baseWidth, CGFloat(displayedDataPointCount) * 40)
    }
  }
  
  // Get the actual number of data points that will be displayed after aggregation
  private func getDisplayedDataPointCount() -> Int {
    switch chartData.chartType {
    case "bar":
      // For bar charts, count unique X-axis values after aggregation
      let uniqueXValues = Set(chartData.dataPoints.map { $0.x.stringValue })
      return uniqueXValues.count
      
    case "line":
      // For line charts, check if data is categorical or temporal
      let uniqueXValues = Set(chartData.dataPoints.map { $0.x.stringValue })
      let isCategoricalData = uniqueXValues.count < Int(Double(chartData.dataPoints.count) * 0.5)
      
      if isCategoricalData {
        // For categorical data, count unique X-axis values (aggregated)
        return uniqueXValues.count
      } else {
        // For temporal data, use all data points
        return chartData.dataPoints.count
      }
      
    case "scatter":
      // For scatter plots, use all data points (no aggregation)
      return chartData.dataPoints.count
      
    case "pie":
      // For pie charts, count unique X-axis values (categories) after aggregation
      let uniqueXValues = Set(chartData.dataPoints.map { $0.x.stringValue })
      // Limit to top 10 for readability (same as in aggregation function)
      return min(uniqueXValues.count, 10)
      
    default:
      // Default to line chart behavior
      let uniqueXValues = Set(chartData.dataPoints.map { $0.x.stringValue })
      let isCategoricalData = uniqueXValues.count < Int(Double(chartData.dataPoints.count) * 0.5)
      return isCategoricalData ? uniqueXValues.count : chartData.dataPoints.count
    }
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

  struct ScatterChartItem: Identifiable {
    let id = UUID()
    let xValue: Double  // Scatter plots typically use numeric values
    let yValue: Double
  }

  struct PieChartItem: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
  }

  private func aggregateDataForBarChart() -> [BarChartItem] {
    // Group by X-axis values and aggregate Y values
    var groupedData: [String: [Double]] = [:]
    
    print("🔍 [BarChart] Processing \(chartData.dataPoints.count) data points")
    
    // Debug: Show unique countries in the data
    let uniqueCountries = Set(chartData.dataPoints.map { $0.x.stringValue })
    print("🔍 [BarChart] Unique countries found: \(uniqueCountries.count)")
    print("🔍 [BarChart] Countries: \(Array(uniqueCountries).sorted())")

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
      print("📊 [BarChart] Country \(key): \(values.count) points, total=\(sum)")
      return BarChartItem(label: key, value: sum)
    }

    // Sort by value (descending) and return all items
    let sorted = items.sorted { $0.value > $1.value }
    print("📊 [BarChart] Returning \(sorted.count) countries")
    return sorted
  }

  private func aggregateDataForLineChart() -> [LineChartItem] {
    // For line charts, we need to handle different data types appropriately
    // For categorical data (like countries), we should aggregate like bar charts
    // For temporal data (like dates), we should show progression
    
    print("🔍 [LineChart] Processing \(chartData.dataPoints.count) data points")
    
    // Check if we're dealing with categorical data by looking at unique x-values
    let uniqueXValues = Set(chartData.dataPoints.map { $0.x.stringValue })
    let isCategoricalData = uniqueXValues.count < Int(Double(chartData.dataPoints.count) * 0.5) // If less than 50% unique, likely categorical
    
    print("🔍 [LineChart] Unique x-values: \(uniqueXValues.count), Total points: \(chartData.dataPoints.count)")
    print("🔍 [LineChart] Is categorical data: \(isCategoricalData)")
    
    if isCategoricalData {
      // For categorical data (like countries), aggregate like bar charts
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
      let items = groupedData.compactMap { (key, values) -> LineChartItem? in
        guard !values.isEmpty else { return nil }
        let sum = values.reduce(0, +)
        print("📊 [LineChart] Country \(key): \(values.count) points, total=\(sum)")
        return LineChartItem(xValue: key, yValue: sum)
      }
      
      // Sort by value (descending) for categorical data
      let sorted = items.sorted { (item1: LineChartItem, item2: LineChartItem) in
        item1.yValue > item2.yValue
      }
      print("📊 [LineChart] Returning \(sorted.count) aggregated countries")
      return sorted
    } else {
      // For temporal/sequential data, process each point individually
      var items: [LineChartItem] = []
      
      for (index, point) in chartData.dataPoints.enumerated() {
        guard let y = point.y else { 
          print("⚠️ [LineChart] Skipping point \(index): no y value")
          continue 
        }

        let xValue = point.x.stringValue
        let yValue = y.doubleValue
        
        print("📊 [LineChart] Point \(index): x=\(xValue), y=\(yValue)")
        items.append(LineChartItem(xValue: xValue, yValue: yValue))
      }

      // Sort by X value for proper line progression
      let sorted = items.sorted { $0.xValue < $1.xValue }
      print("📊 [LineChart] Returning all \(sorted.count) sequential data points")
      return sorted
    }
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

  private func aggregateDataForScatterChart() -> [ScatterChartItem] {
    // For scatter plots, we need numeric X and Y values
    // Convert string values to numbers where possible
    print("🔍 [ScatterChart] Processing \(chartData.dataPoints.count) data points")
    
    var items: [ScatterChartItem] = []
    
    for (index, point) in chartData.dataPoints.enumerated() {
      guard let y = point.y else { 
        print("⚠️ [ScatterChart] Skipping point \(index): no y value")
        continue 
      }
      
      // Try to convert X value to number
      let xValue: Double
      switch point.x {
      case .double(let value):
        xValue = value
      case .int(let value):
        xValue = Double(value)
      case .string(let value):
        // Try to parse string as number
        if let parsed = Double(value) {
          xValue = parsed
        } else {
          // Use hash of string as numeric value for categorical data
          xValue = Double(value.hash) / 1000000.0
        }
      case .date(let value):
        xValue = value.timeIntervalSince1970
      }
      
      let yValue = y.doubleValue
      
      print("📊 [ScatterChart] Point \(index): x=\(xValue), y=\(yValue)")
      items.append(ScatterChartItem(xValue: xValue, yValue: yValue))
    }
    
    print("📊 [ScatterChart] Returning \(items.count) scatter points")
    return items
  }

  private func aggregateDataForPieChart() -> [PieChartItem] {
    // For pie charts, we aggregate by X-axis values (categories) and sum Y values
    print("🔍 [PieChart] Processing \(chartData.dataPoints.count) data points")
    
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
    
    // Convert to pie chart items (sum by default)
    let items = groupedData.compactMap { (key, values) -> PieChartItem? in
      guard !values.isEmpty else { return nil }
      let sum = values.reduce(0, +)
      print("📊 [PieChart] Category \(key): \(values.count) points, total=\(sum)")
      return PieChartItem(label: key, value: sum)
    }
    
    // Sort by value (descending) and limit to top 10 for readability
    let sorted = items.sorted { $0.value > $1.value }
    let limited = Array(sorted.prefix(10))
    print("📊 [PieChart] Returning \(limited.count) pie segments")
    return limited
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
