import SwiftUI
import Foundation
import Combine

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
                await MainActor.run {
                    self.chartData = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
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
}

// MARK: - Data Models
struct ChartData {
    let chartType: String
    let title: String
    let xLabel: String?
    let yLabel: String?
    let reasoning: String
    let dataPoints: [DataPoint]
    let originalData: [String: Any]
    
    init(from apiResponse: APIResponse) {
        self.chartType = apiResponse.analysis.recommendation.chartType
        self.title = apiResponse.analysis.recommendation.title
        self.xLabel = apiResponse.analysis.recommendation.xLabel
        self.yLabel = apiResponse.analysis.recommendation.yLabel
        self.reasoning = apiResponse.analysis.recommendation.reasoning
        
        // Convert processed data to chart-friendly format
        self.dataPoints = apiResponse.analysis.processedData.compactMap { dict in
            DataPoint(from: dict, 
                     xKey: apiResponse.analysis.recommendation.xAxis,
                     yKey: apiResponse.analysis.recommendation.yAxis,
                     zKey: apiResponse.analysis.recommendation.zAxis)
        }
        
        self.originalData = [
            "filename": apiResponse.filename,
            "shape": apiResponse.analysis.dataInfo.shape,
            "columns": apiResponse.analysis.dataInfo.columns
        ]
    }
}

struct DataPoint: Identifiable {
    let id = UUID()
    let x: ChartValue
    let y: ChartValue?
    let z: ChartValue?
    let label: String?
    
    init?(from dict: [String: Any], xKey: String?, yKey: String?, zKey: String?) {
        guard let xKey = xKey,
              let xValue = dict[xKey] else { return nil }
        
        self.x = ChartValue(from: xValue)
        self.y = yKey != nil ? ChartValue(from: dict[yKey!]) : nil
        self.z = zKey != nil ? ChartValue(from: dict[zKey!]) : nil
        self.label = String(describing: xValue)
    }
}

enum ChartValue {
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
}

struct DataInfo: Codable {
    let shape: [Int]
    let columns: [String]
    let dtypes: [String: String]
    let numericColumns: [String]
    let categoricalColumns: [String]
    let datetimeColumns: [String]
    
    enum CodingKeys: String, CodingKey {
        case shape, columns, dtypes
        case numericColumns = "numeric_columns"
        case categoricalColumns = "categorical_columns"
        case datetimeColumns = "datetime_columns"
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
