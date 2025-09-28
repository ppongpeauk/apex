/**
 * @author Pete Pongpeauk <ppongpeauk@gmail.com>
 * @author Arman Mahjoor
 * @description Simple chat sidebar rectangle
 */

import SwiftUI

struct ChatSidebar: View {
    @State private var messages: [ChatMessage] = []
    @State private var isLoading: Bool = false
    @EnvironmentObject private var viewModel: DataVisualizationViewModel
    private let apiService = APIService()

    var body: some View {
        VStack(spacing: 0) {
            // Chat history area
            ChatHistoryView(messages: messages, isLoading: isLoading)

            // Chat input at bottom
            ChatInputView(onSendMessage: sendMessage, isDisabled: isLoading)
        }
        .frame(width: 300)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            loadInitialExplanation()
        }
        .onChange(of: viewModel.chartData?.title) { _ in
            loadInitialExplanation()
        }
    }

    private func sendMessage(_ text: String) {
        // Add user message
        let userMessage = ChatMessage(text: text, isUser: true)
        messages.append(userMessage)

        // Set loading state
        isLoading = true

        // Build conversation history for context
        let conversationHistory = buildConversationHistory()

        // Send to OpenAI via backend
        Task {
            do {
                let chatResponse = try await apiService.sendChatMessage(text, history: conversationHistory)
                await MainActor.run {
                    let aiMessage = ChatMessage(text: chatResponse.response, isUser: false)
                    messages.append(aiMessage)
                    
                    // Handle chart change if present
                    if let chartChange = chatResponse.chartChange {
                        handleChartChange(chartChange)
                    }
                    
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false)
                    messages.append(errorMessage)
                    isLoading = false
                }
            }
        }
    }

    private func buildConversationHistory() -> [[String: String]] {
        // Get last 10 messages (excluding the current one we just added)
        let recentMessages = Array(messages.dropLast().suffix(10))

        // Convert to API format
        return recentMessages.map { message in
            [
                "role": message.isUser ? "user" : "assistant",
                "content": message.text
            ]
        }
    }

    private func loadInitialExplanation() {
        // Clear existing messages when new data is loaded
        messages.removeAll()

        // Add AI reasoning as first message if chart data exists
        if let chartData = viewModel.chartData {
            let explanationMessage = ChatMessage(
                text: chartData.reasoning,
                isUser: false
            )
            messages.append(explanationMessage)
        }
    }
    
    private func handleChartChange(_ chartChange: ChartChange) {
        guard let currentChartData = viewModel.chartData else { return }
        
        // Create new chart data with the requested chart type
        let newChartData = ChartData(
            chartType: chartChange.chartType,
            title: currentChartData.title,
            xLabel: currentChartData.xLabel,
            yLabel: currentChartData.yLabel,
            reasoning: chartChange.reason,
            dataPoints: currentChartData.dataPoints,
            originalData: currentChartData.originalData
        )
        
        // Update the view model with the new chart data
        viewModel.chartData = newChartData
        
        print("📊 [ChatSidebar] Chart type changed to: \(chartChange.chartType)")
    }
}
