/// UIKit/Combine용 Compound 타입에 필요한 런타임 멤버를 합성합니다.
///
/// 현재 `@CompoundKit`은 다음 역할을 맡습니다.
/// - `CompoundType` 채택
/// - action queue를 위한 `_compoundRuntime` 저장소 합성
/// - UIKit/Combine 경로에서 `@Published state` 선언을 유지
@attached(member, names: named(_compoundRuntime))
@attached(extension, conformances: CompoundType)
public macro CompoundKit() = #externalMacro(
    module: "CompoundMacros",
    type: "CompoundKitMacro"
)
