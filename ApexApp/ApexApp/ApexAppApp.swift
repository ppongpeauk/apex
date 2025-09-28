//
//  ApexAppApp.swift
//  ApexApp
//
//  Created by Arman Mahjoor on 9/27/25.
//

import SwiftUI
import AppKit

@main
struct ApexAppApp: App {
  @StateObject private var viewModel = DataVisualizationViewModel()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(viewModel)
        .background(WindowAccessor())
        .onAppear {
          StatusItemController.shared.ensureDropZoneVisible(with: viewModel)
        }
    }
  }
}
