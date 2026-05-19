import Foundation

/// 상태와 action 처리 로직을 함께 소유하는 단방향 상태 타입입니다.
///
/// ``CompoundType``은 현재 ``State``를 소유하고, 뷰 계층으로부터 ``Action``을 받으며,
/// ``react(action:)``에서 하나 이상의 ``Reaction``을 만들고,
/// ``reduce(state:reaction:)``를 통해 새로운 상태로 전이합니다.
@MainActor
public protocol CompoundType: AnyObject {
    associatedtype Action: Sendable
    associatedtype Reaction: Sendable
    associatedtype State: Equatable

    var state: State { get set }

    var currentState: State { get }

    var _compoundRuntime: CompoundRuntimeStorage { get }

    func react(action: Action) -> AsyncStream<Reaction>

    func reduce(state: State, reaction: Reaction) -> State
}

public extension CompoundType {
    var currentState: State { state }
}

public extension CompoundType where State: Equatable {
    func send(_ action: Action) {
        _compoundRuntime.enqueue { [weak self] in
            guard let stream = self?.react(action: action) else { return }

            for await reaction in stream {
                guard !Task.isCancelled else { return }

                await MainActor.run { [weak self] in
                    guard let self else { return }

                    let oldState = self.state
                    let newState = self.reduce(state: oldState, reaction: reaction)
                    guard newState != oldState else { return }
                    self.state = newState
                }
            }
        }
    }

    func cancelAllActions() {
        _compoundRuntime.cancelAll()
    }
}
