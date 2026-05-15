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

    struct State: Equatable, Sendable {
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
}
