import Combine
import Foundation
#if canImport(Observation)
import Observation
#endif
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

@ObservableState
private struct ObservableStateProbeState: Equatable {
    var count: Int = 0
    var title: String = ""
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

@Compound
private final class CollidingFlatAccessCompound {
    enum Action: Sendable {
        case noop
    }

    enum Reaction: Sendable {
        case noop
    }

    @ObservableState
    struct State: Equatable {
        var count: Int = 0
        var title: String = "State Title"
    }

    @MainActor
    @Published var state = State()

    // 본체에 같은 이름의 멤버가 있으면 macro generated flat access보다
    // 사용자가 직접 선언한 멤버를 우선합니다.
    @MainActor
    var count: Int { 999 }

    @MainActor
    init() {}

    func react(action: Action) -> AsyncStream<Reaction> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    @MainActor
    func reduce(state: State, reaction: Reaction) -> State {
        state
    }
}

@Compound
private final class ObservationProbeCompound {
    enum Action: Sendable {
        case incrementCount
        case setTitle(String)
    }

    enum Reaction: Sendable {
        case incrementCount
        case setTitle(String)
    }

    @ObservableState
    struct State: Equatable {
        var count: Int = 0
        var title: String = ""
    }

    @MainActor
    @Published var state = State()

    @MainActor
    init() {}

    func react(action: Action) -> AsyncStream<Reaction> {
        switch action {
        case .incrementCount:
            .just(.incrementCount)
        case .setTitle(let title):
            .just(.setTitle(title))
        }
    }

    @MainActor
    func reduce(state: State, reaction: Reaction) -> State {
        var newState = state

        switch reaction {
        case .incrementCount:
            newState.count += 1
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

    @Test("$compound.isLoading 경로는 SwiftUI binding으로 읽고 쓸 수 있다")
    @MainActor
    func flatAccessBindingWorksWithObservedObjectProjection() {
        let compound = FlatAccessCompound()
        let wrapper = ObservedObject(wrappedValue: compound)
        let binding = wrapper.projectedValue.isLoading

        #expect(binding.wrappedValue == false)

        binding.wrappedValue = true

        #expect(compound.isLoading == true)
        #expect(compound.state.isLoading == true)
    }

    @Test("compound 본체에 같은 이름의 멤버가 있으면 macro generated flat access를 덮어쓰지 않는다")
    @MainActor
    func flatAccessRespectsExistingCompoundMembers() {
        let compound = CollidingFlatAccessCompound()

        #expect(compound.count == 999)
        #expect(compound.state.count == 0)
        #expect(compound.title == "State Title")
    }

#if canImport(Observation)
    @Test("native Observation은 ObservableState의 matching property mutation만 invalidation한다")
    @MainActor
    func nativeObservationTracksObservableStatePerProperty() async throws {
        guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) else { return }

        var state = ObservableStateProbeState()
        final class Flag: @unchecked Sendable { var value = false }
        let titleInvalidated = Flag()

        withObservationTracking {
            _ = state.title
        } onChange: {
            titleInvalidated.value = true
        }

        state.count = 1

        try await Task.sleep(nanoseconds: 20_000_000)
        #expect(titleInvalidated.value == false)
    }

    @Test("compound.count reader는 count mutation에만 invalidation된다")
    @MainActor
    func nativeObservationTracksFlatAccessPerProperty() async throws {
        guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) else { return }

        let compound = ObservationProbeCompound()
        final class Flag: @unchecked Sendable { var value = false }
        let titleInvalidated = Flag()

        withObservationTracking {
            _ = compound.title
        } onChange: {
            titleInvalidated.value = true
        }

        compound.send(.incrementCount)
        try await Task.sleep(nanoseconds: 20_000_000)

        #expect(titleInvalidated.value == false)
    }

    @Test("compound.count reader는 count mutation이 오면 invalidation된다")
    @MainActor
    func nativeObservationInvalidatesMatchingFlatAccessReader() async throws {
        guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) else { return }

        let compound = ObservationProbeCompound()
        final class Flag: @unchecked Sendable { var value = false }
        let countInvalidated = Flag()

        withObservationTracking {
            _ = compound.count
        } onChange: {
            countInvalidated.value = true
        }

        compound.send(.incrementCount)
        try await Task.sleep(nanoseconds: 20_000_000)

        #expect(countInvalidated.value == true)
    }
#endif

}

private struct FlatAccessBindingProbeView: View {
    @StateObject private var compound = FlatAccessCompound()

    var body: some View {
        Toggle("Loading", isOn: $compound.isLoading)
    }
}
