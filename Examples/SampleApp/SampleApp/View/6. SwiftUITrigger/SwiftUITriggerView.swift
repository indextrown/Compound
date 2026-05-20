//
//  SwiftUITriggerView.swift
//  SampleApp
//
//  Created by 김동현 on 5/20/26.
//

import Compound
import SwiftUI

struct SwiftUITriggerView: View {
    @State private var compound = SwiftUITriggerCompound()
    @State private var visibleToastMessage: String?
    @State private var triggerCount = 0
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 20) {
            Text("Trigger Example")
                .font(.title2.weight(.semibold))

            VStack(spacing: 8) {
                Text("Persistent State")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("saveCount: \(compound.state.saveCount)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            VStack(spacing: 8) {
                Text("One-shot UI Signal")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("toast fired: \(triggerCount) times")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Text("Tap Save repeatedly. The message stays the same, but each tap still triggers the toast.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Save") {
                compound.send(.saveButtonTapped)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("SwiftUI Trigger")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if let visibleToastMessage {
                Text(visibleToastMessage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.82))
                    )
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: compound.state.$toastMessage.id) { _, _ in
            guard let message = compound.state.toastMessage else { return }

            triggerCount += 1
            toastTask?.cancel()

            withAnimation(.spring(duration: 0.32)) {
                visibleToastMessage = message
            }

            toastTask = Task {
                try? await Task.sleep(for: .seconds(1.4))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        visibleToastMessage = nil
                    }
                }
            }
        }
        .onDisappear {
            toastTask?.cancel()
        }
    }
}

#Preview {
    NavigationStack {
        SwiftUITriggerView()
    }
}
