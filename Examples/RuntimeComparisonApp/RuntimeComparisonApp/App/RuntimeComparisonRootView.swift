//
//  RuntimeComparisonRootView.swift
//  RuntimeComparisonApp
//
//  Created by Codex on 5/21/26.
//

import SwiftUI

struct RuntimeComparisonRootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ArrayReactionDemoView()
            }
            .tabItem {
                Label("[Mutation]", systemImage: "square.stack.3d.up")
            }

            NavigationStack {
                ManagedArrayReactionDemoView()
            }
            .tabItem {
                Label("Array Fix", systemImage: "wrench.and.screwdriver")
            }

            NavigationStack {
                AsyncStreamReactionDemoView()
            }
            .tabItem {
                Label("AsyncStream", systemImage: "waveform.path.ecg")
            }
        }
    }
}

#Preview {
    RuntimeComparisonRootView()
}
