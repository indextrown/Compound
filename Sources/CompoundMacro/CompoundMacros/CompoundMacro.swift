import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CompoundMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {
    /// `state`가 plain stored property로 선언된 경우에만 `@ObservationTracked`를 붙입니다.
    ///
    /// SwiftUI 기본 경로는 `var state = State()`를 Observation으로 추적하는 방향입니다.
    /// 반대로 `@Published var state`처럼 UIKit/legacy 경로는 이 단계에서 건드리지 않습니다.
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let variable = member.as(VariableDeclSyntax.self),
              variable.bindingSpecifier.tokenKind == .keyword(.var),
              variable.bindings.count == 1,
              let binding = variable.bindings.first,
              binding.accessorBlock == nil,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
              !containsPublishedAttribute(variable.attributes),
              pattern.identifier.text == "state" else {
            return []
        }

        return ["@ObservationTracked"]
    }

    /// `@Observable` 매크로가 합성하는 형태와 비슷한 Observation 멤버를 직접 추가합니다.
    ///
    /// 이렇게 하면 `@Compound`가 붙은 타입을 SwiftUI에서 `@State`로 소유하면서도
    /// `state` 접근을 Observation 경로로 연결할 수 있습니다.
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let typeName = declaredTypeName(for: declaration)

        return [
            """
            @ObservationIgnored
            private let _$observationRegistrar = Observation.ObservationRegistrar()
            """,
            DeclSyntax(stringLiteral: """
            internal nonisolated func access<Member>(
                keyPath: KeyPath<\(typeName), Member>
            ) {
                _$observationRegistrar.access(self, keyPath: keyPath)
            }
            """),
            DeclSyntax(stringLiteral: """
            internal nonisolated func withMutation<Member, MutationResult>(
                keyPath: KeyPath<\(typeName), Member>,
                _ mutation: () throws -> MutationResult
            ) rethrows -> MutationResult {
                try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
            }
            """),
            """
            private nonisolated func shouldNotifyObservers<Member>(
                _ lhs: Member,
                _ rhs: Member
            ) -> Bool {
                true
            }
            """,
            """
            private nonisolated func shouldNotifyObservers<Member: Equatable>(
                _ lhs: Member,
                _ rhs: Member
            ) -> Bool {
                lhs != rhs
            }
            """,
            """
            private nonisolated func shouldNotifyObservers<Member: AnyObject>(
                _ lhs: Member,
                _ rhs: Member
            ) -> Bool {
                lhs !== rhs
            }
            """,
            """
            private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(
                _ lhs: Member,
                _ rhs: Member
            ) -> Bool {
                lhs != rhs
            }
            """,
            """
            @ObservationIgnored
            @MainActor
            let _compoundRuntime = CompoundRuntimeStorage()
            """
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let extensionDecl: DeclSyntax = """
            extension \(type): CompoundType, Observation.Observable {
            }
            """
        
        guard let extensionDecl = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }
        
        return [extensionDecl]
    }

    /// 생성 메서드 시그니처에서 `Self` 대신 concrete type 이름을 사용합니다.
    ///
    /// 매크로가 합성한 멤버 안에서는 `KeyPath<Self, ...>`가 허용되지 않는 위치가 있어
    /// 실제 선언 타입 이름을 직접 넣는 편이 안전합니다.
    private static func declaredTypeName(for declaration: some DeclGroupSyntax) -> String {
        if let classDecl = declaration.as(ClassDeclSyntax.self) {
            return classDecl.name.text
        }

        if let structDecl = declaration.as(StructDeclSyntax.self) {
            return structDecl.name.text
        }

        if let actorDecl = declaration.as(ActorDeclSyntax.self) {
            return actorDecl.name.text
        }

        return "Self"
    }

    /// `@Published var state`는 UIKit/Combine 경로로 유지해야 하므로 ObservationTracked 대상에서 제외합니다.
    private static func containsPublishedAttribute(_ attributes: AttributeListSyntax) -> Bool {
        attributes.contains { element in
            guard let attribute = element.as(AttributeSyntax.self),
                  let identifier = attribute.attributeName.as(IdentifierTypeSyntax.self) else {
                return false
            }

            return identifier.name.text == "Published"
        }
    }
}

@main
struct CompoundMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CompoundMacro.self,
        CompoundKitMacro.self,
    ]
}
