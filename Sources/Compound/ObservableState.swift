/// `State`의 property access / mutation을 추적하기 위한 프로토콜입니다.
///
/// `@ObservableState`가 붙은 타입은 이 프로토콜을 자동으로 채택합니다.
/// 현재 단계에서는:
/// - top-level stored property access 기록
/// - top-level stored property mutation 기록
///
/// 까지 지원합니다.
public protocol ObservableState {
    var _$observationRegistrar: ObservableStateRegistrar { get set }
}
