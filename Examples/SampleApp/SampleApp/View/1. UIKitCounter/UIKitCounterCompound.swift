//
//  UIKitCounterCompound.swift
//  SampleApp
//
//  Created by 김동현 on 5/16/26.
//

import Combine
import Compound

final class UIKitCounterCompound: Compound {
    enum Action {
        case increaseButtonTapped
        case decreaseButtonTapped
        case resetButtonTapped
    }

    enum Reaction {
        case setCount(Int)
    }

    struct State: Equatable {
        var count = 0
    }

    @Published var state = State()

    func react(action: Action) -> AsyncStream<Reaction> {
        switch action {
        case .increaseButtonTapped:
            return .just(.setCount(currentState.count + 1))
        case .decreaseButtonTapped:
            return .just(.setCount(currentState.count - 1))
        case .resetButtonTapped:
            return .just(.setCount(0))
        }
    }

    func reduce(state: State, reaction: Reaction) -> State {
        var newState = state

        switch reaction {
        case .setCount(let count):
            newState.count = count
        }

        return newState
    }
}
