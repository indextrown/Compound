import Combine
import Foundation
import Testing
@testable import Compound

private actor TerminationProbe {
    private var isStarted = false
    private var isTerminated = false

    func markStarted() {
        isStarted = true
    }

    func markTerminated() {
        isTerminated = true
    }

    func started() -> Bool {
        isStarted
    }

    func terminated() -> Bool {
        isTerminated
    }
}

@MainActor
private final class CancellableActionCompound: Compound {
    enum Action: Sendable {
        case neverEnding
        case controlled
        case setValue(Int)
    }

    enum Mutation: Sendable {
        case setValue(Int)
    }

    struct State: Equatable {
        var value = 0
    }

    @Published var state = State()

    private let terminationProbe: TerminationProbe?
    private var controlledContinuation: AsyncStream<Mutation>.Continuation?

    init(terminationProbe: TerminationProbe? = nil) {
        self.terminationProbe = terminationProbe
    }

    func mutate(action: Action) -> AsyncStream<Mutation> {
        switch action {
        case .neverEnding:
            return AsyncStream { continuation in
                Task {
                    await terminationProbe?.markStarted()
                }

                continuation.onTermination = { [terminationProbe] _ in
                    Task {
                        await terminationProbe?.markTerminated()
                    }
                }
            }

        case .controlled:
            return AsyncStream { continuation in
                controlledContinuation = continuation
                continuation.yield(.setValue(1))

                continuation.onTermination = { [terminationProbe] _ in
                    Task {
                        await terminationProbe?.markTerminated()
                    }
                }
            }

        case .setValue(let value):
            return .just(.setValue(value))
        }
    }

    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state

        switch mutation {
        case .setValue(let value):
            newState.value = value
        }

        return newState
    }

    func yieldControlledValue(_ value: Int) {
        controlledContinuation?.yield(.setValue(value))
    }
}

@Suite("CompoundActionRuntime 취소 정책")
struct CompoundActionRuntimeCancellationTests {
    @Test("인스턴스가 해제되면 실행 중이던 action stream도 자동 정리된다")
    @MainActor
    func deinitCancelsRunningActionStream() async throws {
        let probe = TerminationProbe()
        var compound: CancellableActionCompound? = CancellableActionCompound(
            terminationProbe: probe
        )

        compound?.send(.neverEnding)

        try await waitUntil {
            await probe.started()
        }

        compound = nil

        try await waitUntil {
            await probe.terminated()
        }

        #expect(await probe.terminated())
    }

    @Test("cancelAllActions()는 실행 중인 action 뒤에 대기 중인 action을 취소한다")
    @MainActor
    func cancelAllActionsCancelsQueuedActions() async throws {
        let compound = CancellableActionCompound()

        compound.send(.neverEnding)
        compound.send(.setValue(1))
        compound.cancelAllActions()

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(compound.state.value == 0)
    }

    @Test("cancelAllActions() 이후 새로 보낸 action은 정상 처리된다")
    @MainActor
    func sendProcessesNewActionsAfterCancellation() async throws {
        let compound = CancellableActionCompound()

        compound.send(.neverEnding)
        compound.send(.setValue(1))
        compound.cancelAllActions()
        compound.send(.setValue(2))

        try await waitUntil {
            compound.state.value == 2
        }

        #expect(compound.state.value == 2)
    }

    @Test("cancelAllActions()는 실행 중이던 stream의 추가 mutation 반영을 중단한다")
    @MainActor
    func cancelAllActionsStopsApplyingAdditionalMutationsFromRunningStream() async throws {
        let compound = CancellableActionCompound()

        compound.send(.controlled)

        try await waitUntil {
            compound.state.value == 1
        }

        compound.cancelAllActions()
        compound.yieldControlledValue(2)

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(compound.state.value == 1)
    }

    @Test("cancelAllActions()는 실행 중이던 AsyncStream에 termination을 전파한다")
    @MainActor
    func cancelAllActionsPropagatesTerminationToRunningStream() async throws {
        let probe = TerminationProbe()
        let compound = CancellableActionCompound(terminationProbe: probe)

        compound.send(.neverEnding)

        try await waitUntil {
            await probe.started()
        }

        compound.cancelAllActions()

        try await waitUntil {
            await probe.terminated()
        }

        #expect(await probe.terminated())
    }

    @Test("cancelAllActions()는 현재 state를 초기화하거나 되돌리지 않는다")
    @MainActor
    func cancelAllActionsDoesNotResetState() async throws {
        let compound = CancellableActionCompound()

        compound.send(.setValue(3))

        try await waitUntil {
            compound.state.value == 3
        }

        compound.cancelAllActions()

        #expect(compound.state.value == 3)
    }

    @MainActor
    private func waitUntil(
        _ condition: () async -> Bool
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
