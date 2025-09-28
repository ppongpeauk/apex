import SwiftUI
import AppKit

@main
struct ApexVisualizerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = DataVisualizationViewModel()
    @State private var isDragOver = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                
                Text("Apex Visualizer")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                if viewModel.chartData != nil {
                    Button("Clear") {
                        viewModel.clearData()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            // Main content area
            if viewModel.isLoading {
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
            } else if let chartData = viewModel.chartData {
                VStack(spacing: 0) {
                    // Chart info header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(chartData.title)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Text(chartData.chartType.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        if !chartData.reasoning.isEmpty {
                            Text(chartData.reasoning)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    
                    // Simple chart visualization
                    SimpleChartView(chartData: chartData)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                }
            } else {
                // Drop zone
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
                    
                    Button("Choose File") {
                        viewModel.selectFile()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
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
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(.systemBackground))
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url = url,
                  url.pathExtension.lowercased() == "csv" else { return }
            
            DispatchQueue.main.async {
                viewModel.processFile(url: url)
            }
        }
        
        return true
    }
}

struct SimpleChartView: View {
    let chartData: ChartData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Simple text-based chart representation
            VStack(alignment: .leading, spacing: 8) {
                Text("Chart Type: \(chartData.chartType.capitalized)")
                    .font(.headline)
                
                Text("Data Points: \(chartData.dataPoints.count)")
                    .font(.subheadline)
                
                if let xLabel = chartData.xLabel {
                    Text("X-Axis: \(xLabel)")
                        .font(.caption)
                }
                
                if let yLabel = chartData.yLabel {
                    Text("Y-Axis: \(yLabel)")
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            
            // Sample data preview
            VStack(alignment: .leading, spacing: 4) {
                Text("Sample Data:")
                    .font(.headline)
                
                ForEach(Array(chartData.dataPoints.prefix(5))) { point in
                    HStack {
                        Text("X: \(point.x.stringValue)")
                        if let y = point.y {
                            Text("Y: \(y.stringValue)")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
    }
}

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

class APIService {
    private let baseURL = "http://127.0.0.1:8000"
    private let session = URLSession.shared
    
    func analyzeCSV(fileURL: URL) async throws -> ChartData {
        let url = URL(string: "\(baseURL)/analyze-csv")!
        
        let fileData = try Data(contentsOf: fileURL)
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: text/csv\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.serverError(detail)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        do {
            let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
            return ChartData(from: apiResponse)
        } catch {
            print("Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Response JSON: \(jsonString)")
            }
            throw APIError.decodingError(error)
        }
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(String)
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return "Server error: \(message)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
