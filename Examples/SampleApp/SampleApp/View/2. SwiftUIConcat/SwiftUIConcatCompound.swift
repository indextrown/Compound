//
//  SwiftUIConcatCompound.swift
//  SampleApp
//
//  Created by 김동현 on 5/16/26.
//

import Combine
import Compound
import Foundation

final class SwiftUIConcatCompound: Compound {
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

    @Published var state = State()

    func react(action: Action) -> AsyncStream<Reaction> {
        switch action {
        case .refreshButtonTapped:
            let nextCount = currentState.refreshCount + 1

            return .concat(
                .just(.setLoading(true)),
                delayedRefreshStream(nextCount: nextCount),
                .just(.setLoading(false))
            )
        }
    }

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

    private func delayedRefreshStream(nextCount: Int) -> AsyncStream<Reaction> {
        AsyncStream { continuation in
            let task = Task {
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
