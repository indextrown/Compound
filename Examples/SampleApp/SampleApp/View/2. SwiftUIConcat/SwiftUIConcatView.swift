//
//  SwiftUIConcatView.swift
//  SampleApp
//
//  Created by 김동현 on 5/16/26.
//

import Compound
import SwiftUI

struct SwiftUIConcatView: View {
    @StateObject private var compound = SwiftUIConcatCompound()

    var body: some View {
        VStack(spacing: 20) {
            Text("Concat Refresh")
                .font(.title2.weight(.semibold))

            Text(compound.state.isLoading ? "Loading..." : "Idle")
                .font(.headline)
                .foregroundStyle(compound.state.isLoading ? .orange : .secondary)

            Text("Refresh Count: \(compound.state.refreshCount)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text(compound.state.statusMessage)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if compound.state.isLoading {
                ProgressView()
                    .controlSize(.large)
            }

            Button("Refresh") {
                compound.send(.refreshButtonTapped)
            }
            .buttonStyle(.borderedProminent)
            .disabled(compound.state.isLoading)
        }
        .padding()
        .navigationTitle("Concat Refresh")
        .navigationBarTitleDisplayMode(.inline)
    }
}
