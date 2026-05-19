import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private extension DeclModifierListSyntax {
    func privatePrefixed() -> DeclModifierListSyntax {
        let privateModifier = DeclModifierSyntax(
            name: .keyword(.private, trailingTrivia: .space)
        )
        let filtered = filter { modifier in
            switch modifier.name.tokenKind {
            case .keyword(.fileprivate),
                 .keyword(.private),
                 .keyword(.internal),
                 .keyword(.public),
                 .keyword(.package):
                return false
            default:
                return true
            }
        }
        return DeclModifierListSyntax(Array([privateModifier] + filtered))
    }

    var witnessAccessModifier: String? {
        for modifier in self {
            switch modifier.name.tokenKind {
            case .keyword(.public): return "public"
            case .keyword(.package): return "package"
            default: continue
            }
        }
        return nil
    }
}

private extension TokenSyntax {
    func prefixedWithUnderscore() -> TokenSyntax {
        switch tokenKind {
        case .identifier(let identifier):
            return TokenSyntax(
                .identifier("_" + identifier),
                leadingTrivia: leadingTrivia,
                trailingTrivia: trailingTrivia,
                presence: presence
            )
        default:
            return self
        }
    }
}

private extension PatternBindingListSyntax {
    func prefixedWithUnderscore() -> PatternBindingListSyntax {
        var bindings = Array(self)
        for index in bindings.indices {
            let binding = bindings[index]
            guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
            bindings[index] = PatternBindingSyntax(
                leadingTrivia: binding.leadingTrivia,
                pattern: IdentifierPatternSyntax(
                    leadingTrivia: identifierPattern.leadingTrivia,
                    identifier: identifierPattern.identifier.prefixedWithUnderscore(),
                    trailingTrivia: identifierPattern.trailingTrivia
                ),
                typeAnnotation: binding.typeAnnotation,
                initializer: binding.initializer,
                accessorBlock: binding.accessorBlock,
                trailingComma: binding.trailingComma,
                trailingTrivia: binding.trailingTrivia
            )
        }
        return PatternBindingListSyntax(bindings)
    }
}

private extension VariableDeclSyntax {
    func clonedAsBackingStorage(addingAttribute attribute: AttributeSyntax) -> VariableDeclSyntax {
        let newAttributes = attributes + [.attribute(attribute)]
        return VariableDeclSyntax(
            leadingTrivia: leadingTrivia,
            attributes: newAttributes,
            modifiers: modifiers.privatePrefixed(),
            bindingSpecifier: TokenSyntax(
                bindingSpecifier.tokenKind,
                leadingTrivia: .space,
                trailingTrivia: .space,
                presence: .present
            ),
            bindings: bindings.prefixedWithUnderscore(),
            trailingTrivia: trailingTrivia
        )
    }

    func hasAttribute(named name: String) -> Bool {
        attributes.contains { element in
            guard case .attribute(let attr) = element else { return false }
            return attr.attributeName.trimmedDescription == name
        }
    }
}

/// `State`를 flat access / observation 확장의 대상으로 표시하는 매크로입니다.
///
/// 현재 단계에서 이 매크로는:
/// - `ObservableState` 채택
/// - registrar 저장소 추가
/// - top-level stored property에 추적 accessor 부착
///
/// 까지 맡습니다.
public struct ObservableStateMacro {
    static let trackedMacroName = "ObservableStateTracked"
    static let ignoredMacroName = "ObservableStateIgnored"

    static var ignoredAttribute: AttributeSyntax {
        AttributeSyntax(
            leadingTrivia: .space,
            atSign: .atSignToken(),
            attributeName: IdentifierTypeSyntax(name: .identifier(ignoredMacroName)),
            trailingTrivia: .space
        )
    }

    static func isStoredVar(_ decl: VariableDeclSyntax) -> Bool {
        guard decl.bindingSpecifier.tokenKind == .keyword(.var) else { return false }
        guard let binding = decl.bindings.first else { return false }

        if
            let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
            pattern.identifier.text.hasPrefix("_")
        {
            return false
        }

        if let accessorBlock = binding.accessorBlock {
            switch accessorBlock.accessors {
            case .getter:
                return false
            case .accessors(let list):
                let hasGetOrSet = list.contains { accessor in
                    let kind = accessor.accessorSpecifier.tokenKind
                    return kind == .keyword(.get) || kind == .keyword(.set)
                        || kind == .keyword(.willSet) || kind == .keyword(.didSet)
                }
                if hasGetOrSet { return false }
            }
        }

        return true
    }

    static func propertyName(_ binding: PatternBindingSyntax) -> String? {
        binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
    }
}

extension ObservableStateMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let witnessModifier = declaration.modifiers.witnessAccessModifier.map { "\($0) " } ?? ""

        return [
            "\(raw: witnessModifier)var _$observationRegistrar = ObservableStateRegistrar()",
            """
            private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
                true
            }
            """,
            """
            private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
                lhs != rhs
            }
            """
        ]
    }
}

extension ObservableStateMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let observableStateExtension: DeclSyntax = """
        extension \(type): ObservableState {
        }
        """

        let nativeObservationExtension: DeclSyntax = """
        @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
        extension \(type): Observation.Observable {
        }
        """

        return [observableStateExtension, nativeObservationExtension].compactMap {
            $0.as(ExtensionDeclSyntax.self)
        }
    }
}

extension ObservableStateMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard
            let varDecl = member.as(VariableDeclSyntax.self),
            isStoredVar(varDecl)
        else {
            return []
        }

        if varDecl.hasAttribute(named: ignoredMacroName)
            || varDecl.hasAttribute(named: trackedMacroName)
        {
            return []
        }

        return ["@ObservableStateTracked"]
    }
}

public struct ObservableStateTrackedMacro {}

extension ObservableStateTrackedMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard
            let varDecl = declaration.as(VariableDeclSyntax.self),
            ObservableStateMacro.isStoredVar(varDecl),
            let binding = varDecl.bindings.first,
            let name = ObservableStateMacro.propertyName(binding)
        else {
            return []
        }

        if varDecl.hasAttribute(named: ObservableStateMacro.ignoredMacroName) {
            return []
        }

        let backingName = "_\(name)"

        let initAccessor: AccessorDeclSyntax =
        """
        @storageRestrictions(initializes: \(raw: backingName))
        init(initialValue) {
            \(raw: backingName) = initialValue
        }
        """

        let getAccessor: AccessorDeclSyntax =
        """
        get {
            _$observationRegistrar.access(self, keyPath: \\Self.\(raw: name))
            return \(raw: backingName)
        }
        """

        let setAccessor: AccessorDeclSyntax =
        """
        set {
            _$observationRegistrar._$mutate(self, keyPath: \\Self.\(raw: name), &\(raw: backingName), newValue, shouldNotifyObservers)
        }
        """

        let modifyAccessor: AccessorDeclSyntax =
        """
        _modify {
            _$observationRegistrar.willModify(self, keyPath: \\Self.\(raw: name), &\(raw: backingName))
            defer {
                _$observationRegistrar.didModify(self, keyPath: \\Self.\(raw: name), &\(raw: backingName))
            }
            yield &\(raw: backingName)
        }
        """

        return [initAccessor, getAccessor, setAccessor, modifyAccessor]
    }
}

extension ObservableStateTrackedMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard
            let varDecl = declaration.as(VariableDeclSyntax.self),
            ObservableStateMacro.isStoredVar(varDecl)
        else {
            return []
        }

        if varDecl.hasAttribute(named: ObservableStateMacro.ignoredMacroName) {
            return []
        }

        let storage = DeclSyntax(varDecl.clonedAsBackingStorage(addingAttribute: ObservableStateMacro.ignoredAttribute))
        return [storage]
    }
}

public struct ObservableStateIgnoredMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        []
    }
}
