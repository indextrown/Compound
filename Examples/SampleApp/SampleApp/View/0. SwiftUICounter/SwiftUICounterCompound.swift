//
//  SwiftUICounterCompound.swift
//  SampleApp
//
//  Created by 김동현 on 5/16/26.
//

import Combine
import Compound

final class SwiftUICounterCompound: Compound {
    enum Action: Sendable {
        case increaseButtonTapped
        case decreaseButtonTapped
        case resetButtonTapped
    }

    enum Mutation: Sendable {
        case setCount(Int)
    }

    struct State: Equatable {
        var count = 0
    }

    @Published var state = State()

    func mutate(action: Action) -> AsyncStream<Mutation> {
        switch action {
        case .increaseButtonTapped:
            return .just(.setCount(currentState.count + 1))
        case .decreaseButtonTapped:
            return .just(.setCount(currentState.count - 1))
        case .resetButtonTapped:
            return .just(.setCount(0))
        }
    }

    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state

        switch mutation {
        case .setCount(let count):
            newState.count = count
        }

        return newState
    }
}
