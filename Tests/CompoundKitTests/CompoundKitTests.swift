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
}
