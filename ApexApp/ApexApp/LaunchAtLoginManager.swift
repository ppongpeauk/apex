/**
 * @author Assistant <assistant@openai.com>
 * @description Handles toggling of the application's launch-at-login behavior.
 */

import Foundation
import Combine
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
  @Published private(set) var isEnabled: Bool = false
  @Published var lastError: String?

  init() {
    refreshState()
  }

  func refreshState() {
    if #available(macOS 13.0, *) {
      isEnabled = SMAppService.mainApp.status == .enabled
    } else {
      isEnabled = false
      lastError = "Launch at Login requires macOS 13.0 or later."
    }
  }

  func updateState(to newValue: Bool) {
    let previousValue = isEnabled
    guard newValue != previousValue else { return }

    if #available(macOS 13.0, *) {
      do {
        if newValue {
          try SMAppService.mainApp.register()
        } else {
          try SMAppService.mainApp.unregister()
        }
        isEnabled = newValue
        lastError = nil
      } catch {
        isEnabled = previousValue
        lastError = "Failed to update Launch at Login: \(error.localizedDescription)"
      }
    } else {
      lastError = "Launch at Login requires macOS 13.0 or later."
    }
  }
}


