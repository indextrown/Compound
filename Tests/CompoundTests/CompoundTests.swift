import Combine
import Foundation
import SwiftUI
import Testing
@testable import Compound

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
    @Published var state = State()

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
    @Published var state = State()

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

@Compound
private final class FlatAccessCompound {
    enum Action: Sendable {
        case increase
    }

    enum Reaction: Sendable {
        case setCount(Int)
        case setTitle(String)
    }

    @ObservableState
    struct State: Equatable {
        var count: Int = 0
        var title: String = "Hello"
        var isLoading: Bool = false
    }

    @MainActor
    @Published var state = State()

    @MainActor
    init() {}

    func react(action: Action) -> AsyncStream<Reaction> {
        switch action {
        case .increase:
            .concat(
                .just(.setCount(1)),
                .just(.setTitle("Updated"))
            )
        }
    }

    @MainActor
    func reduce(state: State, reaction: Reaction) -> State {
        var newState = state

        switch reaction {
        case .setCount(let count):
            newState.count = count
        case .setTitle(let title):
            newState.title = title
        }

        return newState
    }
}

@Suite("Compound")
struct CompoundTests {
    @Test("send(_:)는 이전 action의 reaction sequence가 끝난 뒤 다음 action을 처리한다")
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

    @Test("@Compound는 @ObservableState가 붙은 nested State의 top-level property를 flat access로 노출한다")
    @MainActor
    func compoundExposesFlatAccessorsFromObservableState() {
        let compound = FlatAccessCompound()

        #expect(compound.count == 0)
        #expect(compound.title == "Hello")
        #expect(compound.isLoading == false)
        #expect(compound.count == compound.state.count)
        #expect(compound.title == compound.state.title)
        #expect(compound.isLoading == compound.state.isLoading)
    }

    @Test("flat access는 state 변경 이후에도 최신 값을 그대로 반영한다")
    @MainActor
    func flatAccessorsReflectUpdatedState() async throws {
        let compound = FlatAccessCompound()

        compound.send(.increase)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(compound.count == 1)
        #expect(compound.title == "Updated")
        #expect(compound.count == compound.state.count)
        #expect(compound.title == compound.state.title)
    }

    @Test("flat access setter는 state의 top-level property를 갱신한다")
    @MainActor
    func flatAccessSetterUpdatesState() {
        let compound = FlatAccessCompound()

        compound.count = 41
        compound.title = "Manual"
        compound.isLoading = true

        #expect(compound.state.count == 41)
        #expect(compound.state.title == "Manual")
        #expect(compound.state.isLoading == true)
    }

    @Test("@ObservableState는 flat access read를 state property access로 기록한다")
    @MainActor
    func observableStateTracksAccesses() {
        let compound = FlatAccessCompound()
        compound.state._$observationRegistrar._$clearAccesses()

        _ = compound.count
        _ = compound.title

        let accesses = compound.state._$observationRegistrar._$accessedKeyPaths
        #expect(accesses.count == 2)
        #expect(accesses.contains { $0 == \FlatAccessCompound.State.count })
        #expect(accesses.contains { $0 == \FlatAccessCompound.State.title })
    }

    @Test("@ObservableState는 flat access setter를 state property mutation으로 기록한다")
    @MainActor
    func observableStateTracksMutationsFromFlatAccessSetter() {
        let compound = FlatAccessCompound()
        compound.state._$observationRegistrar._$clearMutations()

        compound.count = 7
        compound.isLoading = true

        let mutations = compound.state._$observationRegistrar._$mutatedKeyPaths
        #expect(mutations.contains(\FlatAccessCompound.State.count))
        #expect(mutations.contains(\FlatAccessCompound.State.isLoading))
    }

}

private struct FlatAccessBindingProbeView: View {
    @StateObject private var compound = FlatAccessCompound()

    var body: some View {
        Toggle("Loading", isOn: $compound.isLoading)
    }
}
