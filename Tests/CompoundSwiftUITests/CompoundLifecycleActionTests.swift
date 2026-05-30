import Testing
import SwiftUI
@testable import Compound

private final class LifecycleActionCompound: CompoundType {
    enum Action: Sendable {
        case load
        case appear
        case refresh
    }

    enum Reaction: Sendable {
        case noop
    }

    struct State: Equatable {}

    @MainActor
    let _compoundRuntime = CompoundRuntimeStorage()

    @MainActor
    var state = State()

    @MainActor
    init() {}

    func react(action: Action) -> AsyncStream<Reaction> {
        .init { $0.finish() }
    }

    func reduce(state: State, reaction: Reaction) -> State {
        state
    }
}

@Suite("Compound SwiftUI lifecycle actions")
struct CompoundLifecycleActionTests {
    @Test("SwiftUI lifecycle modifiers는 Compound action을 받을 수 있다")
    @MainActor
    func modifiersAcceptCompoundActions() {
        let compound = LifecycleActionCompound()
        let view = EmptyView()
            .compoundOnLoad(compound, .load)
            .compoundOnAppear(compound, .appear, once: false)
            .compoundTask(compound, action: .load)
            .compoundTask(compound, action: .refresh, id: 1)

        _ = view
    }

    @Test("once가 true면 같은 view identity에서 한 번만 action을 보낸다")
    func onceTrueAllowsOnlyFirstSend() {
        var gate = CompoundLifecycleActionGate<CompoundLifecycleNoID>()
        let first = gate.shouldSend(once: true)
        let second = gate.shouldSend(once: true)
        let third = gate.shouldSend(once: true)

        #expect(first)
        #expect(!second)
        #expect(!third)
    }

    @Test("once가 false면 lifecycle 발생마다 action을 다시 보낸다")
    func onceFalseAllowsRepeatedSends() {
        var gate = CompoundLifecycleActionGate<CompoundLifecycleNoID>()
        let first = gate.shouldSend(once: false)
        let second = gate.shouldSend(once: false)
        let third = gate.shouldSend(once: false)

        #expect(first)
        #expect(second)
        #expect(third)
    }

    @Test("task id variant는 기본적으로 id 변경 task마다 action을 다시 보낸다")
    func taskIDAllowsRepeatedSendsByDefault() {
        var gate = CompoundLifecycleActionGate<Int>()
        let first = gate.shouldSend(id: 1, once: false)
        let second = gate.shouldSend(id: 2, once: false)
        let third = gate.shouldSend(id: 3, once: false)

        #expect(first)
        #expect(second)
        #expect(third)
    }

    @Test("task id variant도 once가 true면 첫 task에서만 action을 보낸다")
    func taskIDOnceTrueAllowsOnlyFirstSend() {
        var gate = CompoundLifecycleActionGate<Int>()
        let first = gate.shouldSend(id: 1, once: true)
        let second = gate.shouldSend(id: 2, once: true)
        let third = gate.shouldSend(id: 3, once: true)

        #expect(first)
        #expect(!second)
        #expect(!third)
    }
}
