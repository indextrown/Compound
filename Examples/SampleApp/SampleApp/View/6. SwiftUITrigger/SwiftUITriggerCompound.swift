//
//  SwiftUITriggerCompound.swift
//  SampleApp
//
//  Created by 김동현 on 5/20/26.
//

import Compound

@Compound
final class SwiftUITriggerCompound {
    enum Action: Sendable {
        case saveButtonTapped
    }

    enum Reaction: Sendable {
        case incrementSaveCount
        case showToast(String)
    }

    struct State: Equatable {
        var saveCount = 0
        @Trigger var toastMessage: String?
    }

    var state = State()

    func react(action: Action) -> AsyncStream<Reaction> {
        switch action {
        case .saveButtonTapped:
            return .concat(
                .just(.incrementSaveCount),
                .just(.showToast("Saved"))
            )
        }
    }

    func reduce(state: State, reaction: Reaction) -> State {
        var newState = state

        switch reaction {
        case .incrementSaveCount:
            newState.saveCount += 1
        case .showToast(let message):
            newState.toastMessage = message
        }

        return newState
    }
}
