import Foundation

/// 같은 값이 다시 대입되어도 "새로운 발생"으로 구분되는 one-shot UI 신호 래퍼입니다.
///
/// `value`는 그대로 유지하면서 `valueUpdatedCount`만 증가시키기 때문에
/// 동일 값 재대입도 별도의 trigger 발생으로 해석할 수 있습니다.
@propertyWrapper
public struct Trigger<Value> {
    public var value: Value {
        didSet {
            riseValueUpdatedCount()
        }
    }

    public internal(set) var valueUpdatedCount = UInt.min

    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }

    public var wrappedValue: Value {
        get { value }
        set { value = newValue }
    }

    public var projectedValue: Self {
        self
    }

    private mutating func riseValueUpdatedCount() {
        valueUpdatedCount &+= 1
    }
}

extension Trigger: Equatable where Value: Equatable {}
