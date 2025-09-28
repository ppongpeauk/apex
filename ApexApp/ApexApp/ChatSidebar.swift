/**
 * @author Pete Pongpeauk <ppongpeauk@gmail.com>
 * @author Arman Mahjoor
 * @description Simple chat sidebar rectangle
 */

import SwiftUI

struct ChatSidebar: View {
    @State private var isLoading: Bool = false
    @EnvironmentObject private var viewModel: DataVisualizationViewModel
    private let apiService = APIService()

    var body: some View {
        VStack(spacing: 0) {
            ChatHistoryView(messages: viewModel.chatMessages, isLoading: isLoading)
            ChatInputView(onSendMessage: sendMessage, isDisabled: isLoading)
        }
        .frame(width: 300)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            viewModel.loadInitialChatMessages()
        }
        .onChange(of: viewModel.chartData?.title) { _ in
            viewModel.loadInitialChatMessages()
        }
    }

    private func sendMessage(_ text: String) {
        viewModel.appendChatMessage(ChatMessage(text: text, isUser: true))
        isLoading = true

        let conversationHistory = viewModel.buildConversationHistory()
        let currentDataContext = viewModel.buildChatContext()

        Task {
            do {
                let chatResponse = try await apiService.sendChatMessage(text, history: conversationHistory, currentData: currentDataContext)
                await MainActor.run {
                    viewModel.appendChatMessage(ChatMessage(text: chatResponse.response, isUser: false))

                    if let chartChange = chatResponse.chartChange {
                        viewModel.applyChartChange(chartChange)
                    }

                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    viewModel.appendChatMessage(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
                    isLoading = false
                }
            }
        }
    }
}
