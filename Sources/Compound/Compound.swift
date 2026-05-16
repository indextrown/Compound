// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import ObjectiveC

@MainActor
private var compoundActionLifetimeTokenKey: UInt8 = 0

/// Compound 인스턴스가 해제될 때 런타임에 남은 action task를 정리하는 토큰입니다.
private final class CompoundActionLifetimeToken {
    private let objectID: ObjectIdentifier

    init(objectID: ObjectIdentifier) {
        self.objectID = objectID
    }

    deinit {
        Task { @MainActor [objectID] in
            CompoundActionRuntime.cancelAllActions(for: objectID)
        }
    }
}

/// 같은 Compound 인스턴스에 들어오는 action을 순차 처리하기 위한 내부 런타임 저장소입니다.
///
/// 각 인스턴스별로 현재 살아 있는 action task들과 마지막 task를 기억해 두었다가,
/// 다음 action이 들어오면 앞선 task가 끝난 뒤 이어서 실행되도록 연결합니다.
@MainActor
private enum CompoundActionRuntime {
    /// 특정 Compound 인스턴스에 연결된 action task 목록입니다.
    struct Entry {
        var tasks: [UUID: Task<Void, Never>] = [:]
        var lastTask: Task<Void, Never>?
    }

    /// Compound 인스턴스별 action task 목록을 보관합니다.
    static var entries: [ObjectIdentifier: Entry] = [:]

    /// Compound 인스턴스 해제 시 남은 action task를 정리할 토큰을 한 번만 연결합니다.
    static func installLifetimeTokenIfNeeded(
        for object: AnyObject,
        objectID: ObjectIdentifier
    ) {
        guard objc_getAssociatedObject(object, &compoundActionLifetimeTokenKey) == nil else {
            return
        }

        objc_setAssociatedObject(
            object,
            &compoundActionLifetimeTokenKey,
            CompoundActionLifetimeToken(objectID: objectID),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    /// 새 action task를 인스턴스의 순차 처리 체인에 등록합니다.
    static func append(
        task: Task<Void, Never>,
        token: UUID,
        for objectID: ObjectIdentifier
    ) {
        var entry = entries[objectID] ?? Entry()
        entry.tasks[token] = task
        entry.lastTask = task
        entries[objectID] = entry
    }

    /// 완료되었거나 취소된 action task를 런타임 저장소에서 제거합니다.
    static func removeTask(
        token: UUID,
        for objectID: ObjectIdentifier
    ) {
        guard var entry = entries[objectID] else { return }

        entry.tasks[token] = nil
        if entry.tasks.isEmpty {
            entries[objectID] = nil
        } else {
            entries[objectID] = entry
        }
    }

    /// 특정 Compound 인스턴스의 현재 실행 중이거나 대기 중인 action task를 모두 취소합니다.
    static func cancelAllActions(for objectID: ObjectIdentifier) {
        guard let entry = entries[objectID] else { return }

        for task in entry.tasks.values {
            task.cancel()
        }

        entries[objectID] = nil
    }
}

/// 상태와 action 처리 로직을 함께 소유하는 단방향 상태 타입입니다.
///
/// ``Compound``는 현재 ``State``를 소유하고, 뷰 계층으로부터 ``Action``을 받으며,
/// ``mutate(action:)``에서 하나 이상의 ``Mutation``을 만들고,
/// ``reduce(state:mutation:)``를 통해 새로운 상태로 전이합니다.
public protocol Compound: AnyObject, ObservableObject {
    associatedtype Action: Sendable
    associatedtype Mutation: Sendable
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

    /// 주어진 action에 대한 mutation sequence를 만듭니다.
    ///
    /// 이 메서드는 side effect 경계입니다.
    /// 동기 action은 하나의 mutation을 즉시 내보내는 stream을 반환할 수 있고,
    /// 비동기 action은 로딩 시작, 성공, 실패처럼 시간에 따라 여러 mutation을 순서대로 내보낼 수 있습니다.
    @MainActor
    func mutate(action: Action) -> AsyncStream<Mutation>

    /// mutation을 현재 상태에 적용해 다음 상태를 만듭니다.
    ///
    /// 이 메서드는 상태 전이 경계입니다.
    /// 여기서는 side effect를 피하고, 입력이 같으면 항상 같은 결과를 돌려주는
    /// 예측 가능하고 테스트 가능한 구현을 유지하는 편이 좋습니다.
    @MainActor
    func reduce(state: State, mutation: Mutation) -> State
}

public extension Compound {
    /// 현재 상태를 그대로 반환합니다.
    @MainActor
    var currentState: State { state }
}

public extension Compound where State: Equatable {
    /// action을 단방향 상태 흐름으로 보냅니다.
    ///
    /// 같은 인스턴스에 들어오는 action은 순차적으로 처리됩니다.
    /// 즉, 하나의 action이 만드는 mutation sequence가 모두 상태에 반영된 뒤 다음 action이 처리됩니다.
    /// 또한 reduce 결과가 이전 상태와 다를 때만 상태를 다시 대입합니다.
    @MainActor
    func send(_ action: Action) {
        let objectID = ObjectIdentifier(self)
        let previousTask = CompoundActionRuntime.entries[objectID]?.lastTask
        let token = UUID()

        CompoundActionRuntime.installLifetimeTokenIfNeeded(
            for: self,
            objectID: objectID
        )

        let currentTask = Task { @MainActor [weak self] in
            defer {
                CompoundActionRuntime.removeTask(token: token, for: objectID)
            }

            await previousTask?.value
            guard !Task.isCancelled else { return }
            guard let stream = self?.mutate(action: action) else { return }

            for await mutation in stream {
                guard !Task.isCancelled else { return }
                guard let self else { return }

                let oldState = state
                let newState = reduce(state: oldState, mutation: mutation)
                guard newState != oldState else { continue }
                state = newState
            }
        }

        CompoundActionRuntime.append(task: currentTask, token: token, for: objectID)
    }

    /// 현재 인스턴스에서 실행 중이거나 순서를 기다리는 모든 action task를 취소합니다.
    ///
    /// 이 메서드는 state를 되돌리거나 초기화하지 않습니다.
    /// 오래 지속되는 stream을 중단하거나 화면 종료 시 남은 action sequence를 끊고 싶을 때 사용합니다.
    @MainActor
    func cancelAllActions() {
        CompoundActionRuntime.cancelAllActions(for: ObjectIdentifier(self))
    }
}
