import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CompoundKitMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        [
            """
            func publisher<Value: Equatable>(
                _ keyPath: KeyPath<State, Value>
            ) -> AnyPublisher<Value, Never> {
                $state
                    .map(keyPath)
                    .removeDuplicates()
                    .eraseToAnyPublisher()
            }
            """,
            """
            func trigger<Value>(
                _ keyPath: KeyPath<State, Trigger<Value>>
            ) -> AnyPublisher<Value, Never> {
                $state
                    .map(keyPath)
                    .removeDuplicates { lhs, rhs in
                        lhs.valueUpdatedCount == rhs.valueUpdatedCount
                    }
                    .map(\\.value)
                    .eraseToAnyPublisher()
            }
            """,
            """
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
            extension \(type): CompoundType {
            }
            """

        guard let extensionDecl = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionDecl]
    }
}
