//
//  ContentView.swift
//  ApexApp
//
//  Created by Arman Mahjoor on 9/27/25.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @EnvironmentObject private var viewModel: DataVisualizationViewModel
  @State private var isDragOver = false

  // Interactive chart controls
  @State private var selectedChartType: String = "bar"
  @State private var selectedXAxis: String = ""
  @State private var selectedYAxis: String = ""
  @State private var availableColumns: [String] = []
  @State private var isSidebarCollapsed: Bool = false
  
  // Additional state variables for chart management
  @State private var columnOptions: [ColumnOption] = []
  @State private var selectedXAxisKey: String = ""
  @State private var selectedYAxisKey: String = ""
  @State private var selectedXAxisDisplay: String = ""
  @State private var selectedYAxisDisplay: String = ""

  var body: some View {
    if viewModel.chartData != nil {
      // Data visualization page with chat sidebar
      HStack(spacing: 0) {
        // Main content area
        VStack(spacing: 0) {
          // Header
          headerView

          // Main content area
          if viewModel.isLoading {
            loadingView
          } else if let chartData = viewModel.chartData {
            chartView(chartData)
              .onAppear {
                initializeChartControls(chartData)
                syncChartStates(with: chartData)
              }
              .onChange(of: viewModel.chartData) { newData in
                if let newData = newData {
                  syncChartStates(with: newData)
                }
              }
          }
        }
        .frame(minWidth: 600)
        .background(Color(.windowBackgroundColor))

        // Divider (only show when sidebar is visible)
        if !isSidebarCollapsed {
          Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(width: 0.5)
            .padding(.vertical, 20)

          // Chat sidebar (only when chart data exists and not collapsed)
          ChatSidebar()
        }
      }
      .frame(minWidth: 1100, minHeight: 600)
      .background(Color(.windowBackgroundColor))
    } else {
      // Upload/loading page without chat sidebar
      VStack(spacing: 0) {
        // Header
        headerView

        // Main content area
        if viewModel.isLoading {
          loadingView
        } else {
          dropZoneView
        }
      }
      .frame(minWidth: 800, minHeight: 600)
      .background(Color(.windowBackgroundColor))
    }
  }

  // MARK: - Header View
  private var headerView: some View {
    HStack(spacing: 0) {
      // Left side of header
      HStack {
        Image(systemName: "fork.knife")
          .font(.title)
          .foregroundColor(.blue)

        Text("Chopped Shi")
          .font(.title)
          .fontWeight(.bold)
      }
      .padding(.leading)

      if viewModel.chartData != nil {
        // Flexible spacer to push Clear button towards divider position
        Spacer()

        Button("Clear") {
          viewModel.clearData()
        }
        .buttonStyle(.bordered)
        .frame(minWidth: 60)
        .padding(.leading, 80)

        // Larger spacer to position arrow button on far right
        Spacer()
          .frame(minWidth: 100)
      } else {
        Spacer()
      }

      if viewModel.chartData != nil {
        Button(action: {
          withAnimation(.easeInOut(duration: 0.3)) {
            isSidebarCollapsed.toggle()
          }
        }) {
          Image(systemName: isSidebarCollapsed ? "chevron.left" : "chevron.right")
            .font(.system(size: 12))
            .padding(.horizontal, 12)
        }
        .buttonStyle(.bordered)
        .frame(minWidth: 60)
        .padding(.trailing)
      }
    }
    .frame(height: 44)
    .background(Color(.windowBackgroundColor))
  }

  // MARK: - Drop Zone View
  private var dropZoneView: some View {
    VStack(spacing: 30) {
      Image(systemName: "doc.text.fill")
        .font(.system(size: 80))
        .foregroundColor(isDragOver ? .blue : .secondary)
        .scaleEffect(isDragOver ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDragOver)

      VStack(spacing: 10) {
        Text("Drop your CSV file here")
          .font(.title2)
          .fontWeight(.semibold)

        Text("Supported formats: .csv")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }

      VStack(spacing: 15) {
        Button("Choose File") {
          viewModel.selectFile()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        Button("Test Server Connection") {
          viewModel.testConnection()
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)

        if let errorMessage = viewModel.errorMessage {
          Text(errorMessage)
            .font(.caption)
            .foregroundColor(errorMessage.contains("✅") ? .green : .red)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(
          isDragOver ? Color.blue : Color.secondary.opacity(0.3),
          style: StrokeStyle(lineWidth: 2, dash: [10])
        )
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(isDragOver ? Color.blue.opacity(0.1) : Color.clear)
        )
    )
    .padding()
    .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
      handleDrop(providers: providers)
    }
  }

  // MARK: - Loading View
  private var loadingView: some View {
    VStack(spacing: 20) {
      ProgressView()
        .scaleEffect(1.5)

      Text("Analyzing your data...")
        .font(.title3)
        .foregroundColor(.secondary)

      Text("AI is determining the best way to visualize your data")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Chart View
  private func chartView(_ data: ChartData) -> some View {
    VStack(spacing: 0) {
      // Column selection and chart visualization
      HStack(spacing: 0) {
        // Column selection sidebar
        columnSelectionSidebar(data)
          .frame(width: 250)
          .background(Color(.windowBackgroundColor))

        Divider()

        // Chart visualization with title
        VStack(spacing: 16) {
          // Chart title - properly centered over chart area only
          Text(data.title)
            .font(.title)
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
            .padding(.top, 20)

          // Chart visualization
          ChartVisualizationView(chartData: data)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id("\(data.chartType)-\(selectedChartType)-\(data.xLabel ?? "")-\(data.yLabel ?? "")-\(selectedXAxis)-\(selectedYAxis)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal)
        .padding(.bottom)
      }
    }
  }

  // MARK: - Column Selection Sidebar
  private func columnSelectionSidebar(_ data: ChartData) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header
      VStack(alignment: .leading, spacing: 4) {
        Text("Chart Controls")
          .font(.headline)
          .fontWeight(.semibold)

        Text("Customize your visualization")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.horizontal)
      .padding(.top)

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          // Chart Type Selection
          chartTypeSection(data)

          Divider()

          // Column Selection
          columnSelectionSection(data)

          Divider()

          // Data Info
          dataInfoSection(data)
        }
        .padding(.horizontal)
      }
    }
  }

  private func chartTypeSection(_ data: ChartData) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Chart Type")
        .font(.subheadline)
        .fontWeight(.medium)

      let chartTypes = ["line", "bar", "scatter", "pie"]
      LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
        ForEach(chartTypes, id: \.self) { chartType in
          Button(action: {
            print("🎯 [ContentView] Switching to chart type: \(chartType)")
            selectedChartType = chartType
            
            // Ensure we have valid axis key selections before updating
            if selectedXAxisKey.isEmpty, let currentData = viewModel.chartData {
              selectedXAxisKey = currentData.xAxisKey ?? ""
              selectedXAxisDisplay = currentData.xLabel ?? ""
              print("   - Using existing X axis key: \(selectedXAxisKey)")
            }
            if selectedYAxisKey.isEmpty, let currentData = viewModel.chartData {
              selectedYAxisKey = currentData.yAxisKey ?? ""
              selectedYAxisDisplay = currentData.yLabel ?? ""
              print("   - Using existing Y axis key: \(selectedYAxisKey)")
            }
            
            updateChart()
            print("✅ [ContentView] Chart type switched to: \(chartType)")
          }) {
            VStack(spacing: 4) {
              Image(systemName: chartTypeIcon(chartType))
                .font(.title2)
              Text(chartType.capitalized)
                .font(.caption)
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(
              selectedChartType == chartType
                ? Color.blue.opacity(0.2) : Color(.controlBackgroundColor)
            )
            .cornerRadius(8)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(selectedChartType == chartType ? Color.blue : Color.clear, lineWidth: 2)
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func columnSelectionSection(_ data: ChartData) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Data Mapping")
        .font(.subheadline)
        .fontWeight(.medium)

      // X-Axis Selection
      VStack(alignment: .leading, spacing: 4) {
        Text("X-Axis")
          .font(.caption)
          .foregroundColor(.secondary)

        Menu {
          ForEach(columnOptions, id: \.column) { option in
            Button(option.displayName) {
              print("🎯 [ContentView] Switching X-axis to: \(option.column)")
              selectedXAxisKey = option.column
              selectedXAxisDisplay = option.displayName
              updateChart()
              print("✅ [ContentView] X-axis switched to: \(option.column)")
            }
          }
        } label: {
          HStack {
            Text(selectedXAxisDisplay.isEmpty ? "Select Column" : selectedXAxisDisplay)
              .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.down")
              .foregroundColor(.secondary)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color(.windowBackgroundColor))
          .cornerRadius(6)
          .overlay(
            RoundedRectangle(cornerRadius: 6)
              .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
          )
        }
        .buttonStyle(.plain)
      }

      // Y-Axis Selection
      VStack(alignment: .leading, spacing: 4) {
        Text("Y-Axis")
          .font(.caption)
          .foregroundColor(.secondary)

        Menu {
          ForEach(columnOptions, id: \.column) { option in
            Button(option.displayName) {
              print("🎯 [ContentView] Switching Y-axis to: \(option.column)")
              selectedYAxisKey = option.column
              selectedYAxisDisplay = option.displayName
              updateChart()
              print("✅ [ContentView] Y-axis switched to: \(option.column)")
            }
          }
        } label: {
          HStack {
            Text(selectedYAxisDisplay.isEmpty ? "Select Column" : selectedYAxisDisplay)
              .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.down")
              .foregroundColor(.secondary)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color(.windowBackgroundColor))
          .cornerRadius(6)
          .overlay(
            RoundedRectangle(cornerRadius: 6)
              .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
          )
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func dataInfoSection(_ data: ChartData) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Dataset Info")
        .font(.subheadline)
        .fontWeight(.medium)

      VStack(alignment: .leading, spacing: 4) {
        if let originalData = data.originalData as? [String: Any],
          let shape = originalData["shape"] as? [Int]
        {
          HStack {
            Image(systemName: "tablecells")
            Text("\(formatNumber(shape[0])) rows × \(shape[1]) columns")
          }
          .font(.caption)
          .foregroundColor(.secondary)
        }

        HStack {
          Image(systemName: "chart.dots.scatter")
          Text("\(formatNumber(data.dataPoints.count)) data points")
        }
        .font(.caption)
        .foregroundColor(.secondary)
      }
    }
  }

  // MARK: - Helper Methods
  private func chartTypeIcon(_ chartType: String) -> String {
    switch chartType {
    case "line": return "chart.line.uptrend.xyaxis"
    case "bar": return "chart.bar"
    case "scatter": return "chart.dots.scatter"
    case "pie": return "chart.pie"
    default: return "chart.bar"
    }
  }

  private func getAvailableColumns(_ data: ChartData) -> [String] {
    return buildColumnOptions(data).map { $0.column }
  }

  private func getXAxisSelection(_ data: ChartData) -> String {
    return displayName(for: data.xAxisKey, defaultLabel: data.xLabel)
  }

  private func getYAxisSelection(_ data: ChartData) -> String {
    return displayName(for: data.yAxisKey, defaultLabel: data.yLabel)
  }

  private func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
  }

  private func initializeChartControls(_ data: ChartData) {
    // Initialize available columns
    availableColumns = getAvailableColumns(data)
    columnOptions = buildColumnOptions(data)

    // Initialize selections from current chart data - prioritize keys
    selectedChartType = data.chartType
    selectedXAxisKey = data.xAxisKey ?? ""
    selectedYAxisKey = data.yAxisKey ?? ""
    selectedXAxisDisplay = data.xLabel ?? ""
    selectedYAxisDisplay = data.yLabel ?? ""
    selectedXAxis = data.xLabel ?? ""  // Keep for backward compatibility
    selectedYAxis = data.yLabel ?? ""  // Keep for backward compatibility
    
    print("🔧 [ContentView] Initialized chart controls:")
    print("   - Chart Type: \(selectedChartType)")
    print("   - Data points: \(data.dataPoints.count)")
    print("   - X Axis Key: '\(selectedXAxisKey)' (display: '\(selectedXAxisDisplay)')")
    print("   - Y Axis Key: '\(selectedYAxisKey)' (display: '\(selectedYAxisDisplay)')")
    print("   - Available Columns: \(availableColumns)")
    
    // Debug: Check if keys exist in columns
    if !availableColumns.isEmpty {
      let xKeyExists = availableColumns.contains(selectedXAxisKey)
      let yKeyExists = availableColumns.contains(selectedYAxisKey)
      print("   - X Key '\(selectedXAxisKey)' exists in columns: \(xKeyExists)")
      print("   - Y Key '\(selectedYAxisKey)' exists in columns: \(yKeyExists)")
    }
  }

  private func updateChart() {
    // Regenerate chart with new selections
    guard let currentData = viewModel.chartData else {
      print("❌ [ContentView] No current chart data available")
      return
    }

    print("🔄 [ContentView] Updating chart: \(selectedChartType) with X:\(selectedXAxisKey) Y:\(selectedYAxisKey)")

    // Use the actual column keys, not display names
    let xAxisKeyToUse = selectedXAxisKey.isEmpty ? (currentData.xAxisKey ?? "") : selectedXAxisKey
    let yAxisKeyToUse = selectedYAxisKey.isEmpty ? (currentData.yAxisKey ?? "") : selectedYAxisKey
    
    // Validate that we have the necessary data for the selected chart type
    if !validateChartTypeCompatibility(chartType: selectedChartType, xAxis: xAxisKeyToUse, yAxis: yAxisKeyToUse, data: currentData) {
      print("⚠️ [ContentView] Chart type \(selectedChartType) not compatible with current data, using fallback")
      // Don't return here, let the chart try to render with fallback logic
    }

    // Create updated chart data with new selections using actual column keys
    let updatedData = createUpdatedChartData(
      originalData: currentData,
      chartType: selectedChartType,
      xAxisKey: xAxisKeyToUse,
      yAxisKey: yAxisKeyToUse,
      xAxisDisplay: selectedXAxisDisplay,
      yAxisDisplay: selectedYAxisDisplay
    )

    print("✅ [ContentView] Created updated chart data with \(updatedData.dataPoints.count) points")

    // Update the view model - this should trigger a re-render
    DispatchQueue.main.async {
      self.viewModel.chartData = updatedData
    }
  }

  private func createUpdatedChartData(
    originalData: ChartData,
    chartType: String,
    xAxisKey: String,
    yAxisKey: String,
    xAxisDisplay: String = "",
    yAxisDisplay: String = ""
  ) -> ChartData {
    print("🔨 [ContentView] Creating chart data with xKey: '\(xAxisKey)', yKey: '\(yAxisKey)'")
    
    // Get the raw data from original data - prefer raw_data over processed_data for full dataset
    let rawDataPoints: [[String: Any]]

    if let rawData = originalData.originalData["raw_data"] as? [[String: AnyCodable]] {
      print("📊 [ContentView] Using raw_data with \(rawData.count) rows")
      rawDataPoints = rawData.map { dict in
        var convertedDict: [String: Any] = [:]
        for (key, anyCodable) in dict {
          convertedDict[key] = anyCodable.value
        }
        return convertedDict
      }
    } else if let rawData = originalData.originalData["raw_data"] as? [[String: Any]] {
      print("📊 [ContentView] Using raw_data (non-AnyCodable) with \(rawData.count) rows")
      rawDataPoints = rawData
    } else if let processedData = originalData.originalData["processed_data"] as? [[String: AnyCodable]] {
      print("📊 [ContentView] Falling back to processed_data with \(processedData.count) rows")
      rawDataPoints = processedData.map { dict in
        var convertedDict: [String: Any] = [:]
        for (key, anyCodable) in dict {
          convertedDict[key] = anyCodable.value
        }
        return convertedDict
      }
    } else if let processedData = originalData.originalData["processed_data"] as? [[String: Any]] {
      print("📊 [ContentView] Falling back to processed_data (non-AnyCodable) with \(processedData.count) rows")
      rawDataPoints = processedData
    } else {
      print("⚠️ [ContentView] No raw or processed data found, reconstructing from data points")
      rawDataPoints = originalData.dataPoints.compactMap { point -> [String: Any]? in
        var dict: [String: Any] = [:]

        if let key = originalData.xAxisKey {
          dict[key] = point.x.stringValue
        }

        if let key = originalData.yAxisKey,
           let yVal = point.y {
          dict[key] = yVal.stringValue
        }

        return dict
      }
    }

    print("📊 [ContentView] Processing \(rawDataPoints.count) raw data points")
    
    // Debug: print available columns in first row
    if let firstRow = rawDataPoints.first {
      print("📊 [ContentView] Available columns in data: \(firstRow.keys.sorted())")
    }

    // Create new data points with selected axes
    let newDataPoints = rawDataPoints.compactMap { dict -> DataPoint? in
      let dataPoint = DataPoint(from: dict, xKey: xAxisKey, yKey: yAxisKey, zKey: originalData.zAxisKey)
      if dataPoint == nil {
        // Debug why it failed
        let hasXKey = dict[xAxisKey] != nil
        let hasYKey = dict[yAxisKey] != nil
        if !hasXKey || !hasYKey {
          print("⚠️ [ContentView] Failed to create DataPoint - xKey '\(xAxisKey)' exists: \(hasXKey), yKey '\(yAxisKey)' exists: \(hasYKey)")
        }
      }
      return dataPoint
    }

    print("✅ [ContentView] Created \(newDataPoints.count) data points from \(rawDataPoints.count) raw records")

    // Use provided display names or fall back to formatted column names
    let xDisplay = xAxisDisplay.isEmpty ? formatColumnName(xAxisKey) : xAxisDisplay
    let yDisplay = yAxisDisplay.isEmpty ? formatColumnName(yAxisKey) : yAxisDisplay

    // Create updated chart data
    return ChartData(
      chartType: chartType,
      title: "\(yDisplay) by \(xDisplay)",
      xLabel: xDisplay,
      yLabel: yDisplay,
      reasoning: originalData.reasoning, // Preserve original AI reasoning
      dataPoints: newDataPoints,
      originalData: originalData.originalData,
      xAxisKey: xAxisKey,
      yAxisKey: yAxisKey,
      zAxisKey: originalData.zAxisKey
    )
  }

  private func handleDrop(providers: [NSItemProvider]) -> Bool {
    guard let provider = providers.first else { return false }

    _ = provider.loadObject(ofClass: URL.self) { url, _ in
      guard let url = url,
        url.pathExtension.lowercased() == "csv"
      else { return }

      DispatchQueue.main.async {
        viewModel.processFile(url: url)
      }
    }

    return true
  }

  private struct ColumnOption: Hashable {
    let column: String
    let displayName: String
  }

  private func buildColumnOptions(_ data: ChartData) -> [ColumnOption] {
    // Try to get columns from originalData
    if let columns = data.originalData["columns"] as? [String] {
      print("📊 [ContentView] Building column options from columns list: \(columns)")
      return columns.map { ColumnOption(column: $0, displayName: formatColumnName($0)) }
    }
    
    // Fallback: Extract from raw data
    if let rawData = data.originalData["raw_data"] as? [[String: AnyCodable]],
       let firstRow = rawData.first {
      let columns = Array(firstRow.keys).sorted()
      print("📊 [ContentView] Building column options from raw data: \(columns)")
      return columns.map { ColumnOption(column: $0, displayName: formatColumnName($0)) }
    }
    
    if let rawData = data.originalData["raw_data"] as? [[String: Any]],
       let firstRow = rawData.first {
      let columns = Array(firstRow.keys).sorted()
      print("📊 [ContentView] Building column options from raw data (non-AnyCodable): \(columns)")
      return columns.map { ColumnOption(column: $0, displayName: formatColumnName($0)) }
    }
    
    print("⚠️ [ContentView] Could not build column options")
    return []
  }

  private func buildSanitizedChartContext(_ data: ChartData) -> [String: Any] {
    var context: [String: Any] = [
      "chart_type": data.chartType,
      "title": data.title,
      "x_label": data.xLabel ?? "",
      "y_label": data.yLabel ?? "",
      "x_axis_key": data.xAxisKey ?? "",
      "y_axis_key": data.yAxisKey ?? ""
    ]

    if let sample = data.originalData["processed_data"] as? [[String: AnyCodable]] {
      context["data_sample"] = sample.prefix(10).map { row in
        row.reduce(into: [String: Any]()) { result, entry in
          result[entry.key] = entry.value.value
        }
      }
    } else if let sample = data.originalData["processed_data"] as? [[String: Any]] {
      context["data_sample"] = Array(sample.prefix(10))
    }

    return context
  }

  private func formatColumnName(_ column: String) -> String {
    column
      .replacingOccurrences(of: "_", with: " ")
      .replacingOccurrences(of: "-", with: " ")
      .capitalized
  }

  private func displayName(for key: String?, defaultLabel: String?) -> String {
    if let key = key,
       let option = columnOptions.first(where: { $0.column == key }) {
      return option.displayName
    }
    return defaultLabel ?? (key ?? "")
  }
  
  private func validateChartTypeCompatibility(chartType: String, xAxis: String, yAxis: String, data: ChartData) -> Bool {
    // Basic validation - ensure we have valid axis selections
    guard !xAxis.isEmpty else {
      print("⚠️ [ContentView] X-axis is empty for chart type \(chartType)")
      return false
    }
    
    // For pie charts, we only need X-axis (categories)
    if chartType == "pie" {
      return true
    }
    
    // For other charts, we need both X and Y axes
    guard !yAxis.isEmpty else {
      print("⚠️ [ContentView] Y-axis is empty for chart type \(chartType)")
      return false
    }
    
    // Additional validation could be added here for specific chart types
    // For example, scatter plots work best with numeric data
    
    return true
  }
  
  private func syncChartStates(with data: ChartData) {
    // Ensure all state variables are properly synchronized
    print("🔄 [ContentView] Syncing chart states with data")
    print("   - Data has \(data.dataPoints.count) points")
    print("   - Data xAxisKey: '\(data.xAxisKey ?? "nil")', yAxisKey: '\(data.yAxisKey ?? "nil")'")
    
    // Update chart type selection to match current data
    if selectedChartType != data.chartType {
      selectedChartType = data.chartType
      print("   - Updated chart type to: \(selectedChartType)")
    }
    
    // Update axis selections to match current data - prioritize keys over labels
    let currentXKey = data.xAxisKey ?? ""
    let currentYKey = data.yAxisKey ?? ""
    let currentXLabel = data.xLabel ?? ""
    let currentYLabel = data.yLabel ?? ""
    
    if selectedXAxisKey != currentXKey {
      selectedXAxisKey = currentXKey
      selectedXAxisDisplay = currentXLabel
      selectedXAxis = currentXLabel  // Keep for backward compatibility
      print("   - Updated X-axis key to: '\(selectedXAxisKey)' (display: '\(selectedXAxisDisplay)')")
    }
    
    if selectedYAxisKey != currentYKey {
      selectedYAxisKey = currentYKey
      selectedYAxisDisplay = currentYLabel
      selectedYAxis = currentYLabel  // Keep for backward compatibility
      print("   - Updated Y-axis key to: '\(selectedYAxisKey)' (display: '\(selectedYAxisDisplay)')")
    }
    
    print("✅ [ContentView] Chart states synchronized")
  }
}
