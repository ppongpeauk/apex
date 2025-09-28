/**
 * @author Assistant <assistant@openai.com>
 * @description SwiftUI helper to capture the hosting window once created.
 */

import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      guard let window = view.window else { return }
      StatusItemController.shared.configure(for: window)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}


