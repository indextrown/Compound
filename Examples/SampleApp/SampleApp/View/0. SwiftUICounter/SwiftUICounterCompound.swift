//
//  SwiftUICounterCompound.swift
//  SampleApp
//
//  Created by 김동현 on 5/16/26.
//

import Compound

@Compound
final class SwiftUICounterCompound {
    enum Action {
        case increaseButtonTapped
        case decreaseButtonTapped
        case resetButtonTapped
    }

    enum Reaction {
        case increase
        case decrease
        case reset
    }

    struct State: Equatable {
        var count = 0
    }

    var state = State()

    func react(action: Action) -> AsyncStream<Reaction> {
        switch action {
        case .increaseButtonTapped:
            return .just(.increase)
        case .decreaseButtonTapped:
            return .just(.decrease)
        case .resetButtonTapped:
            return .just(.reset)
        }
    }

    func reduce(state: State, reaction: Reaction) -> State {
        var newState = state

        switch reaction {
        case .increase:
            newState.count += 1
        case .decrease:
            newState.count -= 1
        case .reset:
            newState.count = 0
        }

        return newState
    }
}
