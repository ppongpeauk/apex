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
            selectedChartType = chartType
            updateChart()
            print("Selected chart type: \(chartType)")
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
          ForEach(availableColumns, id: \.self) { column in
            Button(column) {
              selectedXAxis = column
              updateChart()
              print("Selected X-axis: \(column)")
            }
          }
        } label: {
          HStack {
            Text(selectedXAxis.isEmpty ? "Select Column" : selectedXAxis)
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
          ForEach(availableColumns, id: \.self) { column in
            Button(column) {
              selectedYAxis = column
              updateChart()
              print("Selected Y-axis: \(column)")
            }
          }
        } label: {
          HStack {
            Text(selectedYAxis.isEmpty ? "Select Column" : selectedYAxis)
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
    // Extract columns from original data
    if let originalData = data.originalData as? [String: Any],
      let columns = originalData["columns"] as? [String]
    {
      return columns
    }
    // Fallback: get unique keys from data points
    return Array(Set(data.dataPoints.flatMap { _ in ["Month", "Sales", "Region", "Product"] }))
  }

  private func getXAxisSelection(_ data: ChartData) -> String {
    return data.xLabel ?? "Select Column"
  }

  private func getYAxisSelection(_ data: ChartData) -> String {
    return data.yLabel ?? "Select Column"
  }

  private func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
  }

  private func initializeChartControls(_ data: ChartData) {
    // Initialize available columns
    availableColumns = getAvailableColumns(data)

    // Initialize selections from current chart data
    selectedChartType = data.chartType
    selectedXAxis = data.xLabel ?? ""
    selectedYAxis = data.yLabel ?? ""
  }

  private func updateChart() {
    // Regenerate chart with new selections
    guard let currentData = viewModel.chartData else {
      print("❌ [ContentView] No current chart data available")
      return
    }

    print(
      "🔄 [ContentView] Updating chart: \(selectedChartType) with X:\(selectedXAxis) Y:\(selectedYAxis)"
    )

    // Create updated chart data with new selections
    let updatedData = createUpdatedChartData(
      originalData: currentData,
      chartType: selectedChartType,
      xAxis: selectedXAxis,
      yAxis: selectedYAxis
    )

    print("✅ [ContentView] Created updated chart data with \(updatedData.dataPoints.count) points")

    // Update the view model
    viewModel.chartData = updatedData
  }

  private func createUpdatedChartData(
    originalData: ChartData,
    chartType: String,
    xAxis: String,
    yAxis: String
  ) -> ChartData {
    // Get the raw data from original data and handle AnyCodable properly
    let rawDataPoints: [[String: Any]]

    if let rawData = originalData.originalData["raw_data"] as? [[String: AnyCodable]] {
      print("🔍 [ContentView] Found AnyCodable raw data with \(rawData.count) rows")
      // Convert AnyCodable to regular values
      rawDataPoints = rawData.map { dict in
        var convertedDict: [String: Any] = [:]
        for (key, anyCodable) in dict {
          convertedDict[key] = anyCodable.value
        }
        return convertedDict
      }
      print("🔍 [ContentView] Converted to regular data with \(rawDataPoints.count) rows")
    } else if let rawData = originalData.originalData["raw_data"] as? [[String: Any]] {
      rawDataPoints = rawData
    } else {
      // Fallback: convert existing data points back to dictionaries
      rawDataPoints = originalData.dataPoints.compactMap { point -> [String: Any]? in
        var dict: [String: Any] = [:]

        // Add available data from the point
        if let label = point.label {
          dict[originalData.xLabel ?? "x"] = label
        }

        switch point.x {
        case .string(let value):
          dict[originalData.xLabel ?? "x"] = value
        case .double(let value):
          dict[originalData.xLabel ?? "x"] = value
        case .int(let value):
          dict[originalData.xLabel ?? "x"] = value
        case .date(let value):
          dict[originalData.xLabel ?? "x"] = value
        }

        if let y = point.y {
          switch y {
          case .string(let value):
            dict[originalData.yLabel ?? "y"] = value
          case .double(let value):
            dict[originalData.yLabel ?? "y"] = value
          case .int(let value):
            dict[originalData.yLabel ?? "y"] = value
          case .date(let value):
            dict[originalData.yLabel ?? "y"] = value
          }
        }

        return dict
      }
    }

    // Create new data points with selected axes
    let newDataPoints = rawDataPoints.compactMap { dict -> DataPoint? in
      return DataPoint(from: dict, xKey: xAxis, yKey: yAxis, zKey: nil)
    }

    // Create updated chart data
    return ChartData(
      chartType: chartType,
      title: "\(yAxis) by \(xAxis)",
      xLabel: xAxis,
      yLabel: yAxis,
      reasoning: originalData.reasoning, // Preserve original AI reasoning
      dataPoints: newDataPoints,
      originalData: originalData.originalData
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
}
