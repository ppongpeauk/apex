//
//  DataVisualizationViewModel.swift
//  ApexApp
//
//  Created by Arman Mahjoor on 9/27/25.
//

import SwiftUI
import Foundation
import Combine
import UniformTypeIdentifiers

@MainActor
class DataVisualizationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var chartData: ChartData?
    @Published var errorMessage: String?

    private let apiService = APIService()

    func processFile(url: URL) {
        guard url.pathExtension.lowercased() == "csv" else {
            errorMessage = "Please select a CSV file"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await apiService.analyzeCSV(fileURL: url)
                self.chartData = result
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK {
            if let url = panel.url {
                processFile(url: url)
            }
        }
    }

    func clearData() {
        chartData = nil
        errorMessage = nil
    }

    func testConnection() {
        errorMessage = nil
        print("🧪 [ViewModel] Starting connection test...")

        Task {
            let isHealthy = await apiService.checkServerHealth()
            await MainActor.run {
                if isHealthy {
                    self.errorMessage = "✅ Server connection successful!"
                    print("✅ [ViewModel] Connection test passed")
                } else {
                    self.errorMessage = "❌ Failed to connect to server. Check logs for details."
                    print("❌ [ViewModel] Connection test failed")
                }
            }
        }
    }
}

// MARK: - Data Models
struct ChartData: Equatable {
    let chartType: String
    let title: String
    let xLabel: String?
    let yLabel: String?
    let reasoning: String
    let dataPoints: [DataPoint]
    let originalData: [String: Any]
    
    // Custom equality implementation to handle [String: Any]
    static func == (lhs: ChartData, rhs: ChartData) -> Bool {
        return lhs.chartType == rhs.chartType &&
               lhs.title == rhs.title &&
               lhs.xLabel == rhs.xLabel &&
               lhs.yLabel == rhs.yLabel &&
               lhs.reasoning == rhs.reasoning &&
               lhs.dataPoints == rhs.dataPoints &&
               NSDictionary(dictionary: lhs.originalData).isEqual(to: rhs.originalData)
    }
    
    init(from apiResponse: APIResponse) {
        self.chartType = apiResponse.analysis.recommendation.chartType
        self.title = apiResponse.analysis.recommendation.title
        self.xLabel = apiResponse.analysis.recommendation.xLabel
        self.yLabel = apiResponse.analysis.recommendation.yLabel
        self.reasoning = apiResponse.analysis.recommendation.reasoning

        // Convert processed data to chart-friendly format
        self.dataPoints = Self.createDataPoints(
            from: apiResponse.analysis.processedData,
            xAxis: apiResponse.analysis.recommendation.xAxis,
            yAxis: apiResponse.analysis.recommendation.yAxis,
            zAxis: apiResponse.analysis.recommendation.zAxis
        )

        self.originalData = [
            "filename": apiResponse.filename,
            "shape": apiResponse.analysis.dataInfo.shape,
            "columns": apiResponse.analysis.dataInfo.columns,
            "raw_data": apiResponse.analysis.rawData
        ]
    }

    // Static helper function to create data points without self reference
    private static func createDataPoints(
        from processedData: [[String: AnyCodable]],
        xAxis: String?,
        yAxis: String?,
        zAxis: String?
    ) -> [DataPoint] {
        print("🔍 [ViewModel] Processing \(processedData.count) data records")
        print("🔍 [ViewModel] Recommended axes - X: '\(xAxis ?? "nil")', Y: '\(yAxis ?? "nil")'")

        // Debug: Show available columns in first record
        if let firstRecord = processedData.first {
            let dict = firstRecord.mapValues { $0.value }
            let availableColumns = Array(dict.keys).sorted()
            print("🔍 [ViewModel] Available columns in processed data: \(availableColumns)")
        }

        let dataPoints = processedData.compactMap { anyCodableDict in
            // Convert AnyCodable dict to regular dict
            let dict = anyCodableDict.mapValues { $0.value }

            // Try exact match first
            var dataPoint = DataPoint(from: dict,
                     xKey: xAxis,
                     yKey: yAxis,
                     zKey: zAxis)

            // If exact match fails, try fallback column name matching
            if dataPoint == nil {
                let availableKeys = Array(dict.keys)
                let recommendedX = xAxis ?? ""
                let recommendedY = yAxis ?? ""

                // Find best matching column names (case-insensitive, partial match)
                let matchedX = findBestMatch(target: recommendedX, in: availableKeys)
                let matchedY = findBestMatch(target: recommendedY, in: availableKeys)

                print("🔄 [ViewModel] Fallback matching: '\(recommendedX)' -> '\(matchedX ?? "nil")', '\(recommendedY)' -> '\(matchedY ?? "nil")'")

                dataPoint = DataPoint(from: dict,
                         xKey: matchedX,
                         yKey: matchedY,
                         zKey: nil)
            }

            if dataPoint == nil {
                print("⚠️ [ViewModel] DataPoint creation failed even with fallback. Dict keys: \(Array(dict.keys))")
            }

            return dataPoint
        }

        print("✅ [ViewModel] Successfully created \(dataPoints.count) data points")
        return dataPoints
    }

    // Helper function for fuzzy column name matching
    private static func findBestMatch(target: String, in candidates: [String]) -> String? {
        guard !target.isEmpty else { return nil }

        // Try exact match first
        if candidates.contains(target) {
            return target
        }

        let targetLower = target.lowercased()

        // Try case-insensitive exact match
        for candidate in candidates {
            if candidate.lowercased() == targetLower {
                return candidate
            }
        }

        // Try partial match (candidate contains target or vice versa)
        for candidate in candidates {
            let candidateLower = candidate.lowercased()
            if candidateLower.contains(targetLower) || targetLower.contains(candidateLower) {
                return candidate
            }
        }

        // Try removing common separators and matching
        let cleanTarget = targetLower.replacingOccurrences(of: "[\\s\\-_\\(\\)\\.]", with: "", options: .regularExpression)
        for candidate in candidates {
            let cleanCandidate = candidate.lowercased().replacingOccurrences(of: "[\\s\\-_\\(\\)\\.]", with: "", options: .regularExpression)
            if cleanCandidate == cleanTarget {
                return candidate
            }
        }

        print("⚠️ [ViewModel] No match found for '\(target)' in \(candidates)")
        return nil
    }

    // Custom initializer for interactive updates
    init(
        chartType: String,
        title: String,
        xLabel: String?,
        yLabel: String?,
        reasoning: String,
        dataPoints: [DataPoint],
        originalData: [String: Any]
    ) {
        self.chartType = chartType
        self.title = title
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.reasoning = reasoning
        self.dataPoints = dataPoints
        self.originalData = originalData
    }
}

struct DataPoint: Identifiable, Equatable {
    let id = UUID()
    let x: ChartValue
    let y: ChartValue?
    let z: ChartValue?
    let label: String?
    
    // Custom equality implementation (ignoring id since it's always unique)
    static func == (lhs: DataPoint, rhs: DataPoint) -> Bool {
        return lhs.x == rhs.x &&
               lhs.y == rhs.y &&
               lhs.z == rhs.z &&
               lhs.label == rhs.label
    }
    
    init?(from dict: [String: Any], xKey: String?, yKey: String?, zKey: String?) {
        guard let xKey = xKey,
              let xValue = dict[xKey] else { return nil }

        self.x = ChartValue(from: xValue)
        self.y = yKey != nil ? ChartValue(from: dict[yKey!]) : nil
        self.z = zKey != nil ? ChartValue(from: dict[zKey!]) : nil
        self.label = String(describing: xValue)
    }
}

enum ChartValue: Equatable {
    case string(String)
    case double(Double)
    case int(Int)
    case date(Date)

    init(from value: Any?) {
        switch value {
        case let str as String:
            // Try to parse as number first
            if let double = Double(str) {
                self = .double(double)
            } else if let date = ISO8601DateFormatter().date(from: str) {
                self = .date(date)
            } else {
                self = .string(str)
            }
        case let num as Double:
            self = .double(num)
        case let num as Int:
            self = .int(num)
        case let num as NSNumber:
            self = .double(num.doubleValue)
        default:
            self = .string(String(describing: value ?? ""))
        }
    }

    var doubleValue: Double {
        switch self {
        case .double(let value): return value
        case .int(let value): return Double(value)
        case .string(let str): return Double(str) ?? 0
        case .date(let date): return date.timeIntervalSince1970
        }
    }

    var stringValue: String {
        switch self {
        case .string(let value): return value
        case .double(let value): return String(format: "%.2f", value)
        case .int(let value): return String(value)
        case .date(let date): return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
        }
    }
    
    // Return the appropriate plottable value for Swift Charts
    var plottableValue: Any {
        switch self {
        case .string(let value): return value
        case .double(let value): return value
        case .int(let value): return value
        case .date(let date): return date
        }
    }
}

// MARK: - API Models
struct APIResponse: Codable {
    let filename: String
    let analysis: AnalysisResult
}

struct AnalysisResult: Codable {
    let success: Bool
    let dataInfo: DataInfo
    let recommendation: ChartRecommendation
    let processedData: [[String: AnyCodable]]
    let rawData: [[String: AnyCodable]]

    enum CodingKeys: String, CodingKey {
        case success
        case dataInfo = "data_info"
        case recommendation
        case processedData = "processed_data"
        case rawData = "raw_data"
    }
}

struct DataInfo: Codable {
    let shape: [Int]
    let columns: [String]
    let dtypes: [String: String]
    let missingValues: [String: Int]
    let numericColumns: [String]
    let categoricalColumns: [String]
    let datetimeColumns: [String]
    let sampleData: [String: [AnyCodable]]
    let isSampled: Bool?

    enum CodingKeys: String, CodingKey {
        case shape, columns, dtypes
        case missingValues = "missing_values"
        case numericColumns = "numeric_columns"
        case categoricalColumns = "categorical_columns"
        case datetimeColumns = "datetime_columns"
        case sampleData = "sample_data"
        case isSampled = "is_sampled"
    }
}

struct ChartRecommendation: Codable {
    let chartType: String
    let xAxis: String?
    let yAxis: String?
    let zAxis: String?
    let title: String
    let xLabel: String?
    let yLabel: String?
    let reasoning: String

    enum CodingKeys: String, CodingKey {
        case chartType = "chart_type"
        case xAxis = "x_axis"
        case yAxis = "y_axis"
        case zAxis = "z_axis"
        case title
        case xLabel = "x_label"
        case yLabel = "y_label"
        case reasoning
    }
}

// Helper for handling Any values in JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case is NSNull:
            try container.encodeNil()
        default:
            try container.encode(String(describing: value))
        }
    }
}

extension AnyCodable {
    subscript(key: String) -> Any? {
        guard let dict = value as? [String: Any] else { return nil }
        return dict[key]
    }
}
