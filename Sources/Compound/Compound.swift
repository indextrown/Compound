// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@MainActor
private enum CompoundActionRuntime {
    struct Entry {
        let token: UUID
        let task: Task<Void, Never>
    }

    static var entries: [ObjectIdentifier: Entry] = [:]
}

/// ReactorKit과 Swift Concurrency에서 영감을 받은 경량 단방향 상태 컨테이너입니다.
///
/// ``Compound``는 현재 ``State``를 직접 소유하고, 뷰 계층으로부터 ``Action``을 받으며,
/// ``mutate(action:)``에서 하나 이상의 ``Mutation``을 만들고,
/// ``reduce(state:mutation:)``를 통해 새로운 상태로 전이합니다.
@MainActor
public protocol Compound: AnyObject, ObservableObject {
    associatedtype Action: Sendable
    associatedtype Mutation: Sendable
    associatedtype State: Equatable & Sendable
    
    /// UI 계층이 관찰하는 현재 상태입니다.
    var state: State { get set }

    /// 현재 상태를 읽기 전용으로 드러내는 별칭입니다.
    ///
    /// ReactorKit의 `currentState`와 비슷한 사용감을 위한 이름이며,
    /// 구현체에서 현재 상태를 읽을 때 더 의도가 잘 드러나도록 돕습니다.
    /// 라이브러리 내부의 실제 source of truth는 여전히 ``state``입니다.
    var currentState: State { get }

    /// 주어진 action에 대한 mutation sequence를 만듭니다.
    ///
    /// 이 메서드는 side effect 경계입니다.
    /// 동기 action은 하나의 mutation을 즉시 내보내는 stream을 반환할 수 있고,
    /// 비동기 action은 로딩 시작, 성공, 실패처럼 시간에 따라 여러 mutation을 순서대로 내보낼 수 있습니다.
    func mutate(action: Action) -> AsyncStream<Mutation>

    /// mutation을 현재 상태에 적용해 다음 상태를 만듭니다.
    ///
    /// 이 메서드는 상태 전이 경계입니다.
    /// 여기서는 side effect를 피하고, 입력이 같으면 항상 같은 결과를 돌려주는
    /// 예측 가능하고 테스트 가능한 구현을 유지하는 편이 좋습니다.
    func reduce(state: State, mutation: Mutation) -> State
}

public extension Compound {
    /// 현재 상태를 그대로 반환합니다.
    var currentState: State { state }
}

public extension Compound where State: Equatable {
    /// action을 단방향 상태 흐름으로 보냅니다.
    ///
    /// 같은 인스턴스에 들어오는 action은 순차적으로 처리됩니다.
    /// 즉, 하나의 action이 만드는 mutation sequence가 모두 상태에 반영된 뒤 다음 action이 처리됩니다.
    /// 또한 reduce 결과가 이전 상태와 다를 때만 상태를 다시 대입합니다.
    func send(_ action: Action) {
        let objectID = ObjectIdentifier(self)
        let previousTask = CompoundActionRuntime.entries[objectID]?.task
        let token = UUID()

        let currentTask = Task { @MainActor in
            await previousTask?.value
            guard !Task.isCancelled else { return }

            for await mutation in mutate(action: action) {
                let oldState = state
                let newState = reduce(state: oldState, mutation: mutation)
                guard newState != oldState else { continue }
                state = newState
            }

            if CompoundActionRuntime.entries[objectID]?.token == token {
                CompoundActionRuntime.entries[objectID] = nil
            }
        }

        CompoundActionRuntime.entries[objectID] = .init(token: token, task: currentTask)
    }
}
