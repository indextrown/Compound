import Foundation
#if canImport(Observation)
import Observation
#endif

/// `ObservableState`의 property access / mutation을 기록하는 registrar입니다.
///
/// 역할은 두 갈래입니다.
/// - 모든 OS에서 어떤 key path가 바뀌었는지 기록합니다.
/// - iOS 17+ / macOS 14+에서는 native Observation에도 같은 access / mutation을 전달합니다.
///
/// 이 registrar는 struct 안에 들어가지만, 실제 저장소는 reference-semantic box에 둡니다.
/// 그래서 `reduce` 과정에서 `State`가 복사되어도 같은 observation identity를 유지할 수 있습니다.
public struct ObservableStateRegistrar: @unchecked Sendable {
    private final class Storage: @unchecked Sendable {
        var accessedKeyPaths: [AnyKeyPath] = []
        var mutatedKeyPaths: Set<AnyKeyPath> = []
        let nativeBox = NativeObservationRegistrarBox()
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
        storage.nativeBox.access(subject, keyPath: keyPath)
    }

    public func _$mutate<Subject: ObservableState, Member, Value>(
        _ subject: Subject,
        keyPath: KeyPath<Subject, Member>,
        _ value: inout Value,
        _ newValue: Value,
        _ shouldNotifyObservers: (Value, Value) -> Bool
    ) {
        let changed = shouldNotifyObservers(value, newValue)

        guard changed else {
            value = newValue
            return
        }

        storage.mutatedKeyPaths.insert(keyPath)
        storage.nativeBox.willSet(subject, keyPath: keyPath)
        value = newValue
        storage.nativeBox.didSet(subject, keyPath: keyPath)
    }

    public func willModify<Subject: ObservableState, Member>(
        _ subject: Subject,
        keyPath: KeyPath<Subject, Member>,
        _ member: inout Member
    ) {
        storage.nativeBox.willSet(subject, keyPath: keyPath)
    }

    public func didModify<Subject: ObservableState, Member>(
        _ subject: Subject,
        keyPath: KeyPath<Subject, Member>,
        _ member: inout Member
    ) {
        storage.mutatedKeyPaths.insert(keyPath)
        storage.nativeBox.didSet(subject, keyPath: keyPath)
    }
}

extension ObservableStateRegistrar: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool { true }
}

private struct NativeObservationRegistrarBox: @unchecked Sendable {
#if canImport(Observation)
    private let registrar: (any Sendable)?

    init() {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
            registrar = ObservationRegistrar()
        } else {
            registrar = nil
        }
    }

    func access<Subject: ObservableState, Member>(
        _ subject: Subject,
        keyPath: KeyPath<Subject, Member>
    ) {
        if
            #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *),
            let registrar = registrar as? ObservationRegistrar,
            let observable = subject as? any Observation.Observable
        {
            func open<S: Observation.Observable>(_ opened: S) {
                registrar.access(
                    opened,
                    keyPath: unsafeDowncast(keyPath, to: KeyPath<S, Member>.self)
                )
            }

            open(observable)
        }
    }

    func willSet<Subject: ObservableState, Member>(
        _ subject: Subject,
        keyPath: KeyPath<Subject, Member>
    ) {
        if
            #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *),
            let registrar = registrar as? ObservationRegistrar,
            let observable = subject as? any Observation.Observable
        {
            func open<S: Observation.Observable>(_ opened: S) {
                registrar.willSet(
                    opened,
                    keyPath: unsafeDowncast(keyPath, to: KeyPath<S, Member>.self)
                )
            }

            open(observable)
        }
    }

    func didSet<Subject: ObservableState, Member>(
        _ subject: Subject,
        keyPath: KeyPath<Subject, Member>
    ) {
        if
            #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *),
            let registrar = registrar as? ObservationRegistrar,
            let observable = subject as? any Observation.Observable
        {
            func open<S: Observation.Observable>(_ opened: S) {
                registrar.didSet(
                    opened,
                    keyPath: unsafeDowncast(keyPath, to: KeyPath<S, Member>.self)
                )
            }

            open(observable)
        }
    }
#else
    init() {}

    func access<Subject: ObservableState, Member>(
        _ subject: Subject,
        keyPath: KeyPath<Subject, Member>
    ) {}

    func willSet<Subject: ObservableState, Member>(
        _ subject: Subject,
        keyPath: KeyPath<Subject, Member>
    ) {}

    func didSet<Subject: ObservableState, Member>(
        _ subject: Subject,
        keyPath: KeyPath<Subject, Member>
    ) {}
#endif
}
