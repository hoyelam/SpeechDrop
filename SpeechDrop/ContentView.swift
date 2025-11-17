    //
//  ContentView.swift
//  SpeechDrop
//
//  Created by Hoye Lam on 16/11/2025.
//

import SwiftUI
import SQLiteData
import GRDB
import Dependencies

struct ContentView: View {
    @State private var viewModel = JournalViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Left Panel: Sidebar with list of entries
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
        } content: {
            // Middle Panel: Detail view with transcription
            DetailView(entry: $viewModel.selectedEntry, viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 400, ideal: 600)
        } detail: {
            // Right Panel: Inspector with metadata
            InspectorView(entry: viewModel.selectedEntry)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    withDependencies {
        $0.defaultDatabase = try! DatabaseQueue()
    } operation: {
        ContentView()
    }
}
