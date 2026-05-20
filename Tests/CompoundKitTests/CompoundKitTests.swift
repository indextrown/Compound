import Combine
import Foundation
import Testing
@testable import CompoundKit

@MainActor
@CompoundKit
private final class CounterCompound {
    enum Action: Sendable {
        case increase
    }

    enum Reaction: Sendable {
        case setCount(Int)
    }

    struct State: Equatable {
        var count = 0
    }

    @Published var state = State()

    func react(action: Action) -> AsyncStream<Reaction> {
        switch action {
        case .increase:
            return .just(.setCount(currentState.count + 1))
        }
    }

    @MainActor
    func reduce(state: State, reaction: Reaction) -> State {
        var newState = state

        switch reaction {
        case .setCount(let count):
            newState.count = count
        }

        return newState
    }
}

@MainActor
@CompoundKit
private final class TriggerCompound {
    enum Action: Sendable {
        case showAlert
        case idle
    }

    enum Reaction: Sendable {
        case setAlertMessage(String?)
    }

    struct State: Equatable {
        @Trigger var alertMessage: String?
    }

    @Published var state = State()

    func react(action: Action) -> AsyncStream<Reaction> {
        switch action {
        case .showAlert:
            return .just(.setAlertMessage("Hello"))
        case .idle:
            return .just(.setAlertMessage(nil))
        }
    }

    @MainActor
    func reduce(state: State, reaction: Reaction) -> State {
        var newState = state

        switch reaction {
        case .setAlertMessage(let message):
            newState.alertMessage = message
        }

        return newState
    }
}

@Suite("CompoundKit")
struct CompoundKitTests {
    @Test("publisher(\\.field)는 해당 field의 중복 없는 값만 방출한다")
    @MainActor
    func publisherEmitsDistinctValues() async throws {
        let compound = CounterCompound()
        var values: [Int] = []
        let cancellable = compound.publisher(\.count)
            .sink { values.append($0) }

        compound.send(.increase)
        try await Task.sleep(nanoseconds: 50_000_000)

        compound.state.count = 1
        compound.state.count = 2

        try await Task.sleep(nanoseconds: 50_000_000)

        cancellable.cancel()

        #expect(values == [0, 1, 2])
    }

    @Test("trigger(\\.$field)는 같은 값을 다시 대입해도 새 trigger를 방출한다")
    @MainActor
    func triggerEmitsRepeatedAssignments() async throws {
        let compound = TriggerCompound()
        var values: [String] = []
        let cancellable = compound.trigger(\.$alertMessage)
            .compactMap { $0 }
            .sink { values.append($0) }

        compound.send(.showAlert)
        compound.send(.showAlert)
        compound.send(.idle)
        compound.send(.showAlert)

        try await Task.sleep(nanoseconds: 100_000_000)

        cancellable.cancel()

        #expect(values == ["Hello", "Hello", "Hello"])
    }
}
