import Observation

/// SwiftUI용 Compound 타입에 필요한 Observation/Runtime 멤버를 합성합니다.
///
/// 현재 `@Compound`는 다음 역할을 맡습니다.
/// - `CompoundType` 채택
/// - Swift Observation registrar/accessor 합성
/// - action queue를 위한 `_compoundRuntime` 저장소 합성
/// - `state`가 plain stored property인 경우 Observation 추적 연결
@attached(
    member,
    names: named(_compoundRuntime),
    named(_$observationRegistrar),
    named(access),
    named(withMutation),
    named(shouldNotifyObservers),
    arbitrary
)
@attached(memberAttribute)
@attached(extension, conformances: CompoundType, Observation.Observable)
public macro Compound() = #externalMacro(
    module: "CompoundMacros",
    type: "CompoundMacro"
)
