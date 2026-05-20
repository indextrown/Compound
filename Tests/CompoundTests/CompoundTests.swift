import Foundation
import Testing
@testable import CompoundCore

private final class SerialActionCompound: CompoundType {
    enum Action: Sendable {
        case refresh
        case reset
    }

    enum Reaction: Sendable {
        case setLoading(Bool)
        case setItems([String])
    }

    struct State: Equatable {
        var isLoading = false
        var items: [String] = []
    }

    @MainActor
    let _compoundRuntime = CompoundRuntimeStorage()

    @MainActor
    var state = State()

    @MainActor
    init() {}

    func react(action: Action) -> AsyncStream<Reaction> {
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

    @MainActor
    func reduce(state: State, reaction: Reaction) -> State {
        var newState = state

        switch reaction {
        case .setLoading(let isLoading):
            newState.isLoading = isLoading
        case .setItems(let items):
            newState.items = items
        }

        return newState
    }
}

private final class CountingCompound: CompoundType {
    enum Action: Sendable {
        case sameValue
    }

    enum Reaction: Sendable {
        case setCount(Int)
    }

    struct State: Equatable {
        var count = 0
    }

    @MainActor
    let _compoundRuntime = CompoundRuntimeStorage()

    @MainActor
    var state = State() {
        didSet {
            stateAssignmentCount += 1
        }
    }

    @MainActor
    private(set) var stateAssignmentCount = 0

    @MainActor
    init() {}

    func react(action: Action) -> AsyncStream<Reaction> {
        .just(.setCount(0))
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

private final class CounterCompound: CompoundType {
    enum Action: Sendable {
        case increase
    }

    enum Reaction: Sendable {
        case setCount(Int)
    }

    struct State: Equatable {
        var count = 0
    }

    @MainActor
    let _compoundRuntime = CompoundRuntimeStorage()

    @MainActor
    var state = State()

    @MainActor
    init() {}

    func react(action: Action) -> AsyncStream<Reaction> {
        switch action {
        case .increase:
            return .just(.setCount(1))
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

private final class TriggerCompound: CompoundType {
    enum Action: Sendable {
        case showToast
    }

    enum Reaction: Sendable {
        case showToast(String)
    }

    struct State: Equatable {
        @Trigger var toastMessage: String?
    }

    @MainActor
    let _compoundRuntime = CompoundRuntimeStorage()

    @MainActor
    var state = State()

    @MainActor
    init() {}

    func react(action: Action) -> AsyncStream<Reaction> {
        switch action {
        case .showToast:
            return .just(.showToast("Saved"))
        }
    }

    @MainActor
    func reduce(state: State, reaction: Reaction) -> State {
        var newState = state

        switch reaction {
        case .showToast(let message):
            newState.toastMessage = message
        }

        return newState
    }
}

@Suite("Compound")
struct CompoundTests {
    @Test("currentState는 현재 state를 그대로 노출한다")
    @MainActor
    func currentStateReflectsState() {
        let compound = CounterCompound()

        compound.state.count = 3

        #expect(compound.currentState == .init(count: 3))
    }

    @Test("send(_:)는 react(action:)이 방출한 reaction을 reduce에 적용해 state를 갱신한다")
    @MainActor
    func sendAppliesReactionToState() async throws {
        let compound = CounterCompound()

        compound.send(.increase)
        try await waitUntil { compound.state == .init(count: 1) }

        #expect(compound.state == .init(count: 1))
    }

    @Test("send(_:)는 이전 action의 reaction sequence가 끝난 뒤 다음 action을 처리한다")
    @MainActor
    func sendProcessesActionsSequentially() async throws {
        let compound = SerialActionCompound()

        compound.send(.refresh)
        compound.send(.reset)

        try await waitUntil { compound.state.items == [] && compound.state.isLoading == false }

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

        compound.send(.sameValue)
        try await waitUntil { compound.state == .init(count: 0) }

        #expect(compound.state == .init(count: 0))
        #expect(compound.stateAssignmentCount == 0)
    }

    @Test("@Trigger는 같은 값을 다시 대입해도 새로운 state 변화로 구분한다")
    @MainActor
    func triggerTreatsSameValueAssignmentAsNewSignal() async throws {
        let compound = TriggerCompound()

        compound.send(.showToast)
        try await waitUntil { compound.state.toastMessage == "Saved" }

        let firstTrigger = compound.state.$toastMessage

        compound.send(.showToast)
        try await waitUntil { compound.state.$toastMessage.id != firstTrigger.id }

        #expect(compound.state.toastMessage == "Saved")
        #expect(compound.state.$toastMessage.id != firstTrigger.id)
    }

    @Test("@Trigger projected value는 같은 값 재할당마다 새로운 식별자를 만든다")
    func triggerProjectedValueChangesIdentityOnRepeatedAssignments() {
        var state = TriggerCompound.State()

        let initial = state.$toastMessage
        state.toastMessage = "Saved"
        let first = state.$toastMessage
        state.toastMessage = "Saved"
        let second = state.$toastMessage

        #expect(initial.id != first.id)
        #expect(first.id != second.id)
        #expect(first.value == second.value)
    }

    @MainActor
    private func waitUntil(
        _ condition: @escaping @MainActor () async -> Bool
    ) async throws {
        for _ in 0..<40 {
            if await condition() {
                return
            }

            try await Task.sleep(nanoseconds: 5_000_000)
        }

        #expect(await condition())
    }
}
