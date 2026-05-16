import Combine
import Foundation
import Testing
@testable import Compound

@MainActor
private final class SerialActionCompound: Compound {
    enum Action: Sendable {
        case refresh
        case reset
    }

    enum Mutation: Sendable {
        case setLoading(Bool)
        case setItems([String])
    }

    struct State: Equatable {
        var isLoading = false
        var items: [String] = []
    }

    @Published var state = State()

    func mutate(action: Action) -> AsyncStream<Mutation> {
        switch action {
        case .refresh:
            return AsyncStream { continuation in
                continuation.yield(.setLoading(true))

                Task {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    continuation.yield(.setItems(["A", "B", "C"]))
                    continuation.yield(.setLoading(false))
                    continuation.finish()
                }
            }

        case .reset:
            return .just(.setItems([]))
        }
    }

    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state

        switch mutation {
        case .setLoading(let isLoading):
            newState.isLoading = isLoading
        case .setItems(let items):
            newState.items = items
        }

        return newState
    }
}

private final class CountingCompound: Compound {
    enum Action: Sendable {
        case sameValue
    }

    enum Mutation: Sendable {
        case setCount(Int)
    }

    struct State: Equatable {
        var count = 0
    }

    @Published var state = State()

    func mutate(action: Action) -> AsyncStream<Mutation> {
        .just(.setCount(0))
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

@Suite("Compound")
struct CompoundTests {
    @Test("send(_:)는 이전 action의 mutation sequence가 끝난 뒤 다음 action을 처리한다")
    @MainActor
    func sendProcessesActionsSequentially() async throws {
        let compound = SerialActionCompound()

        compound.send(.refresh)
        compound.send(.reset)

        try await Task.sleep(nanoseconds: 120_000_000)

        #expect(compound.state.items == [])
        #expect(compound.state.isLoading == false)
    }

    @Test("concat은 앞선 stream이 끝난 뒤 다음 stream을 순서대로 방출한다")
    func concatEmitsValuesInOrder() async {
        let stream = AsyncStream.concat(
            .just(1),
            .just(2),
            .just(3)
        )

        var values: [Int] = []

        for await value in stream {
            values.append(value)
        }

        #expect(values == [1, 2, 3])
    }

    @Test("merge는 입력 순서는 보장하지 않지만 모든 값을 방출한다")
    func mergeEmitsAllValues() async {
        let stream = AsyncStream.merge(
            .just(1),
            .just(2),
            .just(3)
        )

        var values: [Int] = []

        for await value in stream {
            values.append(value)
        }

        #expect(Set(values) == Set([1, 2, 3]))
        #expect(values.count == 3)
    }

    @Test("send(_:)는 reduce 결과가 이전 state와 같으면 상태를 다시 대입하지 않는다")
    @MainActor
    func sendSkipsReassigningSameState() async throws {
        let compound = CountingCompound()
        var states: [CountingCompound.State] = []
        let cancellable = compound.$state.sink { states.append($0) }

        compound.send(.sameValue)
        try await Task.sleep(nanoseconds: 50_000_000)
        cancellable.cancel()

        #expect(states == [.init(count: 0)])
    }

}
