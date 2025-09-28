//
//  DropZoneOverlay.swift
//  ApexApp
//
//  Created by Assistant on 9/28/25.
//
/**
 * @author Pete Pongpeauk <ppongpeauk@gmail.com>
 * @description Bottom-right transparent dropzone overlay using a borderless NSPanel.
 *              It fades in after 0.5s of drag-over, accepts CSV file drops,
 *              triggers backend processing via shared view model, shows a loader,
 *              and then lets the main chart window present results.
 */

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

private extension Notification.Name {
  static let dropZoneGlobalDragBegan = Notification.Name("DropZoneController.globalDragBegan")
  static let dropZoneGlobalDragEnded = Notification.Name("DropZoneController.globalDragEnded")
}

// MARK: - Overlay View
struct DropZoneOverlayView: View {
  @EnvironmentObject var viewModel: DataVisualizationViewModel

  @State private var isDragTargeted = false
  @State private var isPromptVisible = false
  @State private var dragEnterAt: Date?
  @State private var isGlobalDragActive = false

  private let appearDelay: TimeInterval = 0.5

  private var shouldShowPrompt: Bool {
    viewModel.isLoading || isPromptVisible || isGlobalDragActive
  }

  var body: some View {
    ZStack {
      // Invisible hit area that always accepts drag to detect dwelling
      Color.clear
        .contentShape(Rectangle())

      // Prompt card
      Group {
        if viewModel.isLoading {
          loadingCard
        } else {
          promptCard
        }
      }
      .opacity(shouldShowPrompt ? 1 : 0)
      .animation(.easeInOut(duration: 0.2), value: shouldShowPrompt)
      .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }
    .frame(width: 260, height: 140)
    .onDrop(of: [.fileURL], isTargeted: $isDragTargeted, perform: handleDrop(providers:))
    .onChange(of: isDragTargeted) { _, targeted in
      if targeted {
        dragEnterAt = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + appearDelay) {
          if isDragTargeted, let enter = dragEnterAt, Date().timeIntervalSince(enter) >= appearDelay {
            isPromptVisible = true
          }
        }
      } else {
        dragEnterAt = nil
        if !viewModel.isLoading && !isGlobalDragActive {
          isPromptVisible = false
        }
      }
    }
    .onReceive(viewModel.$chartData) { _ in
      // Once data is ready, hide prompt
      isPromptVisible = false
      bringAppToFront()
      DropZoneController.shared.fadeOutIfPossible()
    }
    .onChange(of: viewModel.isLoading) { _, loading in
      if loading {
        DropZoneController.shared.fadeInNow()
      } else {
        DropZoneController.shared.fadeOutIfPossible()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .dropZoneGlobalDragBegan)) { _ in
      isGlobalDragActive = true
      if !viewModel.isLoading {
        isPromptVisible = true
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .dropZoneGlobalDragEnded)) { _ in
      isGlobalDragActive = false
      if !viewModel.isLoading && !isDragTargeted {
        isPromptVisible = false
      }
    }
  }

  private var promptCard: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: "square.and.arrow.down.on.square")
        .font(.system(size: 28, weight: .semibold))
        .foregroundColor(.white)
      VStack(alignment: .leading, spacing: 4) {
        Text("Drop data files")
          .font(.headline)
          .foregroundColor(.white)
        Text("CSV supported")
          .font(.caption)
          .foregroundColor(.white.opacity(0.85))
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .background(.ultraThinMaterial)
    .background(Color.black.opacity(0.25))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
    )
  }

  private var loadingCard: some View {
    HStack(alignment: .center, spacing: 12) {
      ProgressView()
        .scaleEffect(1.2)
      VStack(alignment: .leading, spacing: 4) {
        Text("Processing...")
          .font(.headline)
        Text("Sending to backend")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private func handleDrop(providers: [NSItemProvider]) -> Bool {
    guard let provider = providers.first else { return false }
    _ = provider.loadObject(ofClass: URL.self) { url, _ in
      guard let url = url, url.pathExtension.lowercased() == "csv" else { return }
      DispatchQueue.main.async {
        NSApp.activate(ignoringOtherApps: true)
        viewModel.processFile(url: url)
      }
    }
    return true
  }

  private func bringAppToFront() {
    NSApp.activate(ignoringOtherApps: true)
  }
}

// MARK: - Overlay Window Controller
final class DropZoneController {
  static let shared = DropZoneController()
  private var panel: NSPanel?
  private weak var viewModel: DataVisualizationViewModel?

  // Global drag monitoring
  private var globalDragMonitor: Any?
  private var localDragMonitor: Any?
  private var globalMouseUpMonitor: Any?
  private var revealWorkItem: DispatchWorkItem?
  private var isDragging = false

  private init() {}

  @MainActor
  func show(viewModel: DataVisualizationViewModel) {
    guard panel == nil else { return }
    self.viewModel = viewModel

    let content = DropZoneOverlayView().environmentObject(viewModel)
    let hosting = NSHostingController(rootView: content)

    let size = NSSize(width: 260, height: 140)
    let panel = NSPanel(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    panel.level = .statusBar
    panel.isFloatingPanel = true
    panel.becomesKeyOnlyIfNeeded = true
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    panel.ignoresMouseEvents = false // must receive drops
    panel.contentViewController = hosting
    panel.alphaValue = 0 // start hidden

    positionPanel(panel, size: size)
    panel.orderFrontRegardless()

    self.panel = panel

    startGlobalDragMonitoring()
  }

  @MainActor
  private func positionPanel(_ panel: NSPanel, size: NSSize) {
    guard let screen = NSScreen.main else { return }
    let vf = screen.visibleFrame
    let margin: CGFloat = 24
    let origin = CGPoint(x: vf.maxX - size.width - margin, y: vf.minY + margin)
    panel.setFrame(NSRect(origin: origin, size: size), display: true)
  }

  @MainActor
  func hide() {
    stopGlobalDragMonitoring()
    panel?.orderOut(nil)
    panel = nil
  }

  @MainActor
  func fadeOutIfPossible() {
    guard let panel = panel else { return }
    if viewModel?.isLoading == true { return }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.2
      panel.animator().alphaValue = 0
    }
  }

  @MainActor
  func fadeInNow() {
    guard let panel = panel else { return }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.2
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.2
        panel.animator().alphaValue = 1
      }
    }
  }

  // MARK: - Global Drag Detection
  private func startGlobalDragMonitoring() {
    guard globalDragMonitor == nil else { return }

    globalDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
      guard let self = self else { return }
      Task { @MainActor in
        self.handleDragProgress()
      }
    }

    localDragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
      if let self = self {
        Task { @MainActor in
          self.handleDragEnded()
        }
      }
      return event
    }

    globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
      guard let self = self else { return }
      Task { @MainActor in
        self.handleDragEnded()
      }
    }
  }

  private func stopGlobalDragMonitoring() {
    if let gm = globalDragMonitor {
      NSEvent.removeMonitor(gm)
      globalDragMonitor = nil
    }
    if let lm = localDragMonitor {
      NSEvent.removeMonitor(lm)
      localDragMonitor = nil
    }
    if let gum = globalMouseUpMonitor {
      NSEvent.removeMonitor(gum)
      globalMouseUpMonitor = nil
    }
    revealWorkItem?.cancel()
    revealWorkItem = nil
    isDragging = false
  }

  @MainActor
  private func handleDragProgress() {
    if isDragging { return }
    isDragging = true

    guard panel != nil else { return }
    NotificationCenter.default.post(name: .dropZoneGlobalDragBegan, object: nil)
    triggerPanelFadeIn()
  }

  @MainActor
  private func handleDragEnded() {
    isDragging = false
    revealWorkItem?.cancel()
    revealWorkItem = nil

    guard let panel = panel else { return }
    // Keep visible if loading; otherwise fade out
    if viewModel?.isLoading == true {
      NotificationCenter.default.post(name: .dropZoneGlobalDragEnded, object: nil)
      return
    }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.2
      panel.animator().alphaValue = 0
    }
    NotificationCenter.default.post(name: .dropZoneGlobalDragEnded, object: nil)
  }

  @MainActor
  private func triggerPanelFadeIn() {
    guard let panel = panel else { return }
    if shouldRevealOverlay() {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.2
        panel.animator().alphaValue = 1
      }
    } else {
      panel.animator().alphaValue = 1
    }
  }

  private func isDraggingFiles() -> Bool {
    let pb = NSPasteboard.general
    let fileURLType = NSPasteboard.PasteboardType("public.file-url")
    if let types = pb.types, types.contains(fileURLType) || types.contains(.fileURL) {
      return true
    }
    // Older Finder drags may use filenames type
    let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    return pb.types?.contains(filenamesType) == true
  }

  private func shouldRevealOverlay() -> Bool {
    if isDraggingFiles() {
      return true
    }
    if let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
      bundleId == "com.apple.finder"
    {
      return true
    }
    return false
  }
}


