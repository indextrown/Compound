import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(CompoundMacros)
import CompoundMacros
#endif

final class CompoundMacroTests: XCTestCase {
    func testCompoundMacroAddsRuntimeStorageAndConformance() throws {
        #if canImport(CompoundMacros)
        let testMacros: [String: Macro.Type] = [
            "Compound": CompoundMacro.self,
        ]

        assertMacroExpansion(
            """
            @Compound
            final class CounterFeature {
            }
            """,
            expandedSource: """
            final class CounterFeature {

                @MainActor
                let _compoundRuntime = CompoundRuntimeStorage()
            }

            extension CounterFeature: CompoundType {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testCompoundMacroAppendsMembersAfterExistingDeclarations() throws {
        #if canImport(CompoundMacros)
        let testMacros: [String: Macro.Type] = [
            "Compound": CompoundMacro.self,
        ]

        assertMacroExpansion(
            """
            @Compound
            final class CounterFeature {
                enum Action {
                    case increase
                }

                var count = 0
            }
            """,
            expandedSource: """
            final class CounterFeature {
                enum Action {
                    case increase
                }

                var count = 0

                @MainActor
                let _compoundRuntime = CompoundRuntimeStorage()
            }

            extension CounterFeature: CompoundType {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
