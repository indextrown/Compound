//
//  SwiftUIStateChangeProbeCompound.swift
//  SampleApp
//
//  Created by 김동현 on 5/19/26.
//

import Compound

@Compound
final class SwiftUIStateChangeProbeCompound {
    enum Action {
        case increaseCountButtonTapped
        case changeMessageButtonTapped
        case toggleHighlightButtonTapped
        case resetButtonTapped
    }

    enum Reaction {
        case setCount(Int)
        case setMessage(String)
        case setHighlight(Bool)
    }

    struct State: Equatable {
        var count = 0
        var message = "Ready"
        var isHighlighted = false
    }

    var state = State()

    func react(action: Action) -> AsyncStream<Reaction> {
        switch action {
        case .increaseCountButtonTapped:
            return .just(.setCount(currentState.count + 1))

        case .changeMessageButtonTapped:
            let nextMessage = currentState.message == "Ready" ? "Updated" : "Ready"
            return .just(.setMessage(nextMessage))

        case .toggleHighlightButtonTapped:
            return .just(.setHighlight(!currentState.isHighlighted))

        case .resetButtonTapped:
            return .concat(
                .just(.setCount(0)),
                .just(.setMessage("Ready")),
                .just(.setHighlight(false))
            )
        }
    }

    func reduce(state: State, reaction: Reaction) -> State {
        var newState = state

        switch reaction {
        case .setCount(let count):
            newState.count = count

        case .setMessage(let message):
            newState.message = message

        case .setHighlight(let isHighlighted):
            newState.isHighlighted = isHighlighted
        }

        return newState
    }
}
