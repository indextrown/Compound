import Foundation

/// `ObservableState`의 property access / mutation을 기록하는 registrar입니다.
///
/// 지금 단계에서는 SwiftUI invalidation까지 직접 연결하지 않고,
/// 우선 어떤 key path가 읽혔고 어떤 key path가 바뀌었는지 추적하는 역할만 맡습니다.
public struct ObservableStateRegistrar: @unchecked Sendable {
    private final class Storage: @unchecked Sendable {
        var accessedKeyPaths: [AnyKeyPath] = []
        var mutatedKeyPaths: Set<AnyKeyPath> = []
    }

    private let storage: Storage

    public init() {
        storage = Storage()
    }

    public var _$accessedKeyPaths: [AnyKeyPath] {
        storage.accessedKeyPaths
    }

    public var _$mutatedKeyPaths: Set<AnyKeyPath> {
        storage.mutatedKeyPaths
    }

    public func _$clearAccesses() {
        storage.accessedKeyPaths.removeAll()
    }

    public func _$clearMutations() {
        storage.mutatedKeyPaths.removeAll()
    }

    public func access<Subject: ObservableState, Member>(
        _ subject: Subject,
        keyPath: KeyPath<Subject, Member>
    ) {
        storage.accessedKeyPaths.append(keyPath)
    }

    public func _$mutate<Subject: ObservableState, Member, Value>(
        _ subject: Subject,
        keyPath: KeyPath<Subject, Member>,
        _ value: inout Value,
        _ newValue: Value,
        _ shouldNotifyObservers: (Value, Value) -> Bool
    ) {
        let changed = shouldNotifyObservers(value, newValue)
        value = newValue

        guard changed else { return }
        storage.mutatedKeyPaths.insert(keyPath)
    }

    public func willModify<Subject: ObservableState, Member>(
        _ subject: Subject,
        keyPath: KeyPath<Subject, Member>,
        _ member: inout Member
    ) {
        // `_modify` 진입 시점에서는 아직 값을 바꾸지 않습니다.
    }

    public func didModify<Subject: ObservableState, Member>(
        _ subject: Subject,
        keyPath: KeyPath<Subject, Member>,
        _ member: inout Member
    ) {
        storage.mutatedKeyPaths.insert(keyPath)
    }
}

extension ObservableStateRegistrar: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { true }
}
