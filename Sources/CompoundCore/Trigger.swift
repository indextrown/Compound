import Foundation

/// 한 번 발생하고 소비되는 UI 신호를 표현하는 식별 가능한 값입니다.
///
/// 같은 `value`라도 `id`가 다르면 서로 다른 trigger 발생으로 취급합니다.
public struct TriggerValue<Value: Equatable>: Equatable {
    public let id: UUID
    public let value: Value

    public init(
        id: UUID = UUID(),
        value: Value
    ) {
        self.id = id
        self.value = value
    }
}

/// one-shot UI 신호를 `State` 안에서 명시적으로 표현하기 위한 property wrapper입니다.
///
/// `wrappedValue`에 같은 값을 다시 대입하더라도 새로운 `TriggerValue`를 만들기 때문에
/// 상태 동등성 비교에서 별도의 trigger 발생으로 구분됩니다.
@propertyWrapper
public struct Trigger<Value: Equatable>: Equatable {
    private var storage: TriggerValue<Value>

    public init(wrappedValue: Value) {
        storage = TriggerValue(value: wrappedValue)
    }

    public var wrappedValue: Value {
        get { storage.value }
        set { storage = TriggerValue(value: newValue) }
    }

    /// `$property`로 현재 trigger 발생 식별자와 값을 함께 읽을 수 있습니다.
    public var projectedValue: TriggerValue<Value> {
        storage
    }

    public var id: UUID {
        storage.id
    }

    public var value: Value {
        storage.value
    }
}
