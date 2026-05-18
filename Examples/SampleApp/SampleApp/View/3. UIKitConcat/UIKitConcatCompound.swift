//
//  UIKitConcatCompound.swift
//  SampleApp
//
//  Created by 김동현 on 5/16/26.
//

import Combine
import Compound
import Foundation

final class UIKitConcatCompound: CompoundType {
    enum Action {
        case refreshButtonTapped
    }

    enum Reaction {
        case setLoading(Bool)
        case setRefreshCount(Int)
        case setStatusMessage(String)
    }

    struct State: Equatable {
        var isLoading = false
        var refreshCount = 0
        var statusMessage = "Refresh를 눌러 concat sequence를 시작해보세요."
    }

    @MainActor
    let _compoundRuntime = CompoundRuntimeStorage()

    @MainActor
    @Published var state = State()

    @MainActor
    init() {}

    func react(action: Action) -> AsyncStream<Reaction> {
        switch action {
        case .refreshButtonTapped:
            return .concat(
                .just(.setLoading(true)),
                delayedRefreshStream(),
                .just(.setLoading(false))
            )
        }
    }

    @MainActor
    func reduce(state: State, reaction: Reaction) -> State {
        var newState = state

        switch reaction {
        case .setLoading(let isLoading):
            newState.isLoading = isLoading
        case .setRefreshCount(let refreshCount):
            newState.refreshCount = refreshCount
        case .setStatusMessage(let statusMessage):
            newState.statusMessage = statusMessage
        }

        return newState
    }

    private func delayedRefreshStream() -> AsyncStream<Reaction> {
        AsyncStream { continuation in
            let task = Task {
                let nextCount = await MainActor.run { currentState.refreshCount + 1 }
                try? await Task.sleep(nanoseconds: 800_000_000)
                continuation.yield(.setRefreshCount(nextCount))
                continuation.yield(.setStatusMessage("Refresh #\(nextCount) completed"))
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
