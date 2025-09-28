import SwiftUI
import UniformTypeIdentifiers
import AppKit
import Combine

struct ContentView: View {
    @StateObject private var viewModel = DataVisualizationViewModel()
    @State private var isDragOver = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Main content area
            if viewModel.isLoading {
                loadingView
            } else if let chartData = viewModel.chartData {
                chartView(chartData)
            } else {
                dropZoneView
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Header View
    private var headerView: some View {
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
            // Chart info header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(data.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(data.chartType.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                
                if !data.reasoning.isEmpty {
                    Text(data.reasoning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            // Chart visualization
            ChartVisualizationView(chartData: data)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        }
    }
    
    // MARK: - Helper Methods
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
