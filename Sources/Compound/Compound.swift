import Foundation

/// 상태와 action 처리 로직을 함께 소유하는 단방향 상태 타입입니다.
///
/// ``CompoundType``은 현재 ``State``를 소유하고, 뷰 계층으로부터 ``Action``을 받으며,
/// ``react(action:)``에서 하나 이상의 ``Reaction``을 만들고,
/// ``reduce(state:reaction:)``를 통해 새로운 상태로 전이합니다.
public protocol CompoundType: AnyObject, ObservableObject {
    associatedtype Action: Sendable
    associatedtype Reaction: Sendable
    associatedtype State: Equatable

    /// UI 계층이 관찰하는 현재 상태입니다.
    @MainActor
    var state: State { get set }

    /// 현재 상태를 읽기 전용으로 드러내는 별칭입니다.
    ///
    /// 구현체에서 현재 상태를 읽을 때 더 의도가 잘 드러나도록 돕습니다.
    /// 라이브러리 내부의 실제 source of truth는 여전히 ``state``입니다.
    @MainActor
    var currentState: State { get }

    /// 현재 인스턴스의 action runtime storage입니다.
    ///
    /// 현재는 매크로 도입 전 단계이므로, 구현체가 이 저장소를 직접 소유해야 합니다.
    @MainActor
    var _compoundRuntime: CompoundRuntimeStorage { get }

    /// 주어진 action에 대한 reaction sequence를 만듭니다.
    ///
    /// 이 메서드는 side effect 경계입니다.
    /// 동기 action은 하나의 reaction을 즉시 내보내는 stream을 반환할 수 있고,
    /// 비동기 action은 로딩 시작, 성공, 실패처럼 시간에 따라 여러 reaction을 순서대로 내보낼 수 있습니다.
    func react(action: Action) -> AsyncStream<Reaction>

    /// reaction을 현재 상태에 적용해 다음 상태를 만듭니다.
    ///
    /// 이 메서드는 상태 전이 경계입니다.
    /// 여기서는 side effect를 피하고, 입력이 같으면 항상 같은 결과를 돌려주는
    /// 예측 가능하고 테스트 가능한 구현을 유지하는 편이 좋습니다.
    @MainActor
    func reduce(state: State, reaction: Reaction) -> State
}

public extension CompoundType {
    /// 현재 상태를 그대로 반환합니다.
    @MainActor
    var currentState: State { state }
}

public extension CompoundType where State: Equatable {
    /// action을 단방향 상태 흐름으로 보냅니다.
    ///
    /// 같은 인스턴스에 들어오는 action은 순차적으로 처리됩니다.
    /// 즉, 하나의 action이 만드는 reaction sequence가 모두 상태에 반영된 뒤 다음 action이 처리됩니다.
    /// 또한 reduce 결과가 이전 상태와 다를 때만 상태를 다시 대입합니다.
    @MainActor
    func send(_ action: Action) {
        _compoundRuntime.enqueue { [weak self] in
            guard let stream = self?.react(action: action) else { return }

            for await reaction in stream {
                guard !Task.isCancelled else { return }

                await MainActor.run { [weak self] in
                    guard let self else { return }

                    let oldState = state
                    let newState = reduce(state: oldState, reaction: reaction)
                    guard newState != oldState else { return }
                    state = newState
                }
            }
        }
    }

    /// 현재 인스턴스에서 실행 중이거나 순서를 기다리는 모든 action task를 취소합니다.
    ///
    /// 이 메서드는 state를 되돌리거나 초기화하지 않습니다.
    /// 오래 지속되는 stream을 중단하거나 화면 종료 시 남은 action sequence를 끊고 싶을 때 사용합니다.
    @MainActor
    func cancelAllActions() {
        _compoundRuntime.cancelAll()
    }
}
