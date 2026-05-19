import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private extension VariableDeclSyntax {
    /// `State`의 top-level stored `var`만 flat access 대상으로 봅니다.
    ///
    /// 현재 단계에서는:
    /// - stored instance property만 허용
    /// - `static` / `class` member 제외
    /// - computed property 제외
    ///
    /// 이후 tracking runtime을 붙이더라도 출발점은 이 조건을 만족하는
    /// `State`의 top-level property입니다.
    var isStoredInstanceVarForFlatAccess: Bool {
        guard bindingSpecifier.tokenKind == .keyword(.var) else { return false }
        guard let binding = bindings.first else { return false }
        if modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class) }) {
            return false
        }
        if let accessorBlock = binding.accessorBlock {
            switch accessorBlock.accessors {
            case .getter:
                return false
            case .accessors(let accessors):
                let hasGetterLikeAccessor = accessors.contains { accessor in
                    switch accessor.accessorSpecifier.tokenKind {
                    case .keyword(.get), .keyword(.set), .keyword(.willSet), .keyword(.didSet):
                        return true
                    default:
                        return false
                    }
                }
                if hasGetterLikeAccessor { return false }
            }
        }
        return binding.pattern.as(IdentifierPatternSyntax.self) != nil
    }

    var flatAccessPropertyName: String? {
        guard let binding = bindings.first else { return nil }
        return binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
    }

    var flatAccessPropertyTypeSource: String? {
        guard let binding = bindings.first else { return nil }
        return binding.typeAnnotation?.type.trimmedDescription
    }
}

private extension DeclGroupSyntax {
    func hasAttribute(named name: String) -> Bool {
        attributes.contains { element in
            guard case .attribute(let attribute) = element else { return false }
            return attribute.attributeName.trimmedDescription == name
        }
    }
}

private extension MemberBlockItemListSyntax {
    func containsTopLevelMember(named name: String) -> Bool {
        contains { item in
            if let variable = item.decl.as(VariableDeclSyntax.self) {
                return variable.bindings.contains { binding in
                    binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == name
                }
            }
            if let function = item.decl.as(FunctionDeclSyntax.self) {
                return function.name.text == name
            }
            return false
        }
    }
}

private struct MissingFlatAccessTypeAnnotationMessage: DiagnosticMessage {
    let propertyName: String

    var message: String {
        "`@ObservableState` property '\(propertyName)' needs an explicit type annotation to generate flat access on the compound"
    }

    var diagnosticID: MessageID {
        MessageID(domain: "CompoundMacro", id: "missing-flat-access-type-annotation")
    }

    var severity: DiagnosticSeverity {
        .warning
    }
}

public struct CompoundMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // `@Compound`는 항상 runtime storage를 붙입니다.
        // 여기에 더해 nested `State`가 있으면 top-level property를 읽어
        // `compound.count` 같은 flat getter도 함께 생성합니다.
        var members: [DeclSyntax] = [
            """
            @MainActor
            let _compoundRuntime = CompoundRuntimeStorage()
            """
        ]

        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            return members
        }

        guard
            let stateDecl = classDecl.memberBlock.members.first(where: { item in
                guard let structDecl = item.decl.as(StructDeclSyntax.self) else { return false }
                return structDecl.name.text == "State"
            })?.decl.as(StructDeclSyntax.self)
        else {
            return members
        }

        let isObservableState = stateDecl.hasAttribute(named: "ObservableState")

        // 현재는 `State`의 top-level stored property만 대상으로 삼습니다.
        // nested flatten이나 computed property forwarding은 아직 범위 밖입니다.
        for item in stateDecl.memberBlock.members {
            guard let variable = item.decl.as(VariableDeclSyntax.self) else { continue }
            guard variable.isStoredInstanceVarForFlatAccess else { continue }
            guard let name = variable.flatAccessPropertyName else { continue }
            guard let typeSource = variable.flatAccessPropertyTypeSource else {
                if isObservableState {
                    context.diagnose(
                        Diagnostic(
                            node: Syntax(variable),
                            message: MissingFlatAccessTypeAnnotationMessage(propertyName: name)
                        )
                    )
                }
                continue
            }
            guard !classDecl.memberBlock.members.containsTopLevelMember(named: name) else { continue }

            members.append(
                """
                @MainActor
                var \(raw: name): \(raw: typeSource) {
                    get {
                        // 첫 단계에서는 `state`를 그대로 forwarding하는 read path를 만듭니다.
                        // 추후 observation runtime을 붙일 때 이 경로를 tracked access로 확장합니다.
                        state.\(raw: name)
                    }
                    set {
                        var newState = state
                        newState.\(raw: name) = newValue
                        state = newState
                    }
                }
                """
            )
        }

        return members
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // `@Compound`가 붙은 타입은 기본적으로 `CompoundType`을 채택합니다.
        let extensionDecl: DeclSyntax = """
            extension \(type): CompoundType {
            }
            """
        
        guard let extensionDecl = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }
        
        return [extensionDecl]
    }
}

@main
struct CompoundMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CompoundMacro.self,
        ObservableStateMacro.self,
        ObservableStateTrackedMacro.self,
        ObservableStateIgnoredMacro.self,
    ]
}
