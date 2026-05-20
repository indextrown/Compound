import SwiftUI

public extension View {
    /// `@Trigger` 프로퍼티의 새 발생을 SwiftUI에서 편하게 소비합니다.
    ///
    /// 내부 update count 비교는 숨기고, 새 trigger가 발생했을 때만 현재 값을 전달합니다.
    func trigger<Compound: CompoundType & Observation.Observable, Value>(
        of compound: Compound,
        _ keyPath: KeyPath<Compound.State, Trigger<Value>>,
        perform action: @escaping (Value) -> Void
    ) -> some View {
        onChange(of: compound.state[keyPath: keyPath].valueUpdatedCount) { _, _ in
            action(compound.state[keyPath: keyPath].value)
        }
    }
}
