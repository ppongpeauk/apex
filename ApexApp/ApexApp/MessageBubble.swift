/**
 * @author Pete Pongpeauk <ppongpeauk@gmail.com>
 * @author Arman Mahjoor
 * @description Message bubble component for chat messages
 */

import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date = Date()
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
                bubbleContent
            } else {
                bubbleContent
                Spacer(minLength: 50)
            }
        }
    }

    private var bubbleContent: some View {
        Text(message.text)
            .font(.system(size: 14))
            .foregroundColor(message.isUser ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(message.isUser ? Color.blue : Color(.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(message.isUser ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
            )
    }
}
