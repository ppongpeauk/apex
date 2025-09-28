/**
 * @author Assistant <assistant@openai.com>
 * @description Manages the NSStatusItem menu, window toggling, quit action, and launch-at-login toggle.
 */

import AppKit
import Combine

@MainActor
final class StatusItemController: NSObject {
  static let shared = StatusItemController()

  private var statusItem: NSStatusItem?
  private var statusMenu: NSMenu?
  private var launchAtLoginManager = LaunchAtLoginManager()
  private var cancellables: Set<AnyCancellable> = []

  private weak var window: NSWindow?

  private override init() {
    super.init()
  }

  func configure(for window: NSWindow?) {
    self.window = window

    if statusItem == nil {
      let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
      statusItem.button?.image = NSImage(systemSymbolName: "chart.xyaxis.line", accessibilityDescription: "ApexApp")

      let menu = buildMenu()
      menu.delegate = self

      statusItem.menu = menu

      self.statusItem = statusItem
      self.statusMenu = menu

      bindLaunchAtLoginState()
    } else {
      refreshMenuState()
    }
  }

  private func bindLaunchAtLoginState() {
    launchAtLoginManager.$isEnabled
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isEnabled in
        guard let item = self?.statusMenu?.item(withTitle: "Launch at Login") else { return }
        item.state = isEnabled ? .on : .off
      }
      .store(in: &cancellables)

    launchAtLoginManager.$lastError
      .compactMap { $0 }
      .receive(on: DispatchQueue.main)
      .sink { message in
        let alert = NSAlert()
        alert.messageText = "Launch at Login"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
      }
      .store(in: &cancellables)
  }

  func ensureDropZoneVisible(with viewModel: DataVisualizationViewModel) {
    DropZoneController.shared.show(viewModel: viewModel)
  }

  private func buildMenu() -> NSMenu {
    let menu = NSMenu()

    let toggleWindowItem = NSMenuItem(title: titleForWindowToggle(), action: #selector(toggleWindow(_:)), keyEquivalent: "w")
    toggleWindowItem.target = self
    menu.addItem(toggleWindowItem)

    let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "l")
    launchAtLoginItem.target = self
    launchAtLoginItem.state = launchAtLoginManager.isEnabled ? .on : .off
    menu.addItem(launchAtLoginItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(title: "Quit Apex", action: #selector(quitApp(_:)), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    return menu
  }

  private func refreshMenuState() {
    statusMenu?.item(at: 0)?.title = titleForWindowToggle()
    let launchItem = statusMenu?.item(withTitle: "Launch at Login")
    launchItem?.state = launchAtLoginManager.isEnabled ? .on : .off
  }

  private func titleForWindowToggle() -> String {
    guard let window = window else { return "Show Window" }
    return window.isVisible ? "Hide Window" : "Show Window"
  }

  @objc
  private func toggleWindow(_ sender: Any?) {
    guard let window = window else {
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    if window.isVisible {
      window.orderOut(nil)
    } else {
      NSApp.activate(ignoringOtherApps: true)
      window.makeKeyAndOrderFront(nil)
    }
  }

  @objc
  private func toggleLaunchAtLogin(_ sender: Any?) {
    let newValue = !launchAtLoginManager.isEnabled
    launchAtLoginManager.updateState(to: newValue)
  }

  @objc
  private func quitApp(_ sender: Any?) {
    NSApp.terminate(nil)
  }
}

extension StatusItemController: NSMenuDelegate {
  func menuWillOpen(_ menu: NSMenu) {
    launchAtLoginManager.refreshState()
    refreshMenuState()
  }
}


