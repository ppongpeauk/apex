/**
 * @author Pete Pongpeauk <ppongpeauk@gmail.com>
 * @author Arman Mahjoor
 * @description Chat input component with text field and send button
 */

import SwiftUI

struct ChatInputView: View {
    @State private var inputText: String = ""
    let onSendMessage: (String) -> Void
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Type a message...", text: $inputText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .onSubmit {
                    sendMessage()
                }
                .disabled(isDisabled)

            SendButton(action: sendMessage, isDisabled: isDisabled || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isDisabled else { return }
        onSendMessage(inputText)
        inputText = ""
    }
}

struct SendButton: View {
    let action: () -> Void
    let isDisabled: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundColor(isDisabled ? .secondary : .blue)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
