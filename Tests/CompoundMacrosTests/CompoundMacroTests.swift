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
            "CompoundKit": CompoundKitMacro.self,
        ]

        assertMacroExpansion(
            """
            @Compound
            final class CounterFeature {
            }
            """,
            expandedSource: """
            final class CounterFeature {

                @ObservationIgnored
                private let _$observationRegistrar = Observation.ObservationRegistrar()

                internal nonisolated func access<Member>(
                    keyPath: KeyPath<CounterFeature, Member>
                ) {
                    _$observationRegistrar.access(self, keyPath: keyPath)
                }

                internal nonisolated func withMutation<Member, MutationResult>(
                    keyPath: KeyPath<CounterFeature, Member>,
                    _ mutation: () throws -> MutationResult
                ) rethrows -> MutationResult {
                    try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
                }

                private nonisolated func shouldNotifyObservers<Member>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    true
                }

                private nonisolated func shouldNotifyObservers<Member: Equatable>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    lhs != rhs
                }

                private nonisolated func shouldNotifyObservers<Member: AnyObject>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    lhs !== rhs
                }

                private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    lhs != rhs
                }

                @ObservationIgnored
                @MainActor
                let _compoundRuntime = CompoundRuntimeStorage()
            }

            extension CounterFeature: CompoundType, Observation.Observable {
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
            "CompoundKit": CompoundKitMacro.self,
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

                @ObservationIgnored
                private let _$observationRegistrar = Observation.ObservationRegistrar()

                internal nonisolated func access<Member>(
                    keyPath: KeyPath<CounterFeature, Member>
                ) {
                    _$observationRegistrar.access(self, keyPath: keyPath)
                }

                internal nonisolated func withMutation<Member, MutationResult>(
                    keyPath: KeyPath<CounterFeature, Member>,
                    _ mutation: () throws -> MutationResult
                ) rethrows -> MutationResult {
                    try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
                }

                private nonisolated func shouldNotifyObservers<Member>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    true
                }

                private nonisolated func shouldNotifyObservers<Member: Equatable>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    lhs != rhs
                }

                private nonisolated func shouldNotifyObservers<Member: AnyObject>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    lhs !== rhs
                }

                private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    lhs != rhs
                }

                @ObservationIgnored
                @MainActor
                let _compoundRuntime = CompoundRuntimeStorage()
            }

            extension CounterFeature: CompoundType, Observation.Observable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testCompoundMacroTracksPlainStateProperty() throws {
        #if canImport(CompoundMacros)
        let testMacros: [String: Macro.Type] = [
            "Compound": CompoundMacro.self,
            "CompoundKit": CompoundKitMacro.self,
        ]

        assertMacroExpansion(
            """
            @Compound
            final class CounterFeature {
                struct State {}

                var state = State()
            }
            """,
            expandedSource: """
            final class CounterFeature {
                struct State {}
                @ObservationTracked

                var state = State()

                @ObservationIgnored
                private let _$observationRegistrar = Observation.ObservationRegistrar()

                internal nonisolated func access<Member>(
                    keyPath: KeyPath<CounterFeature, Member>
                ) {
                    _$observationRegistrar.access(self, keyPath: keyPath)
                }

                internal nonisolated func withMutation<Member, MutationResult>(
                    keyPath: KeyPath<CounterFeature, Member>,
                    _ mutation: () throws -> MutationResult
                ) rethrows -> MutationResult {
                    try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
                }

                private nonisolated func shouldNotifyObservers<Member>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    true
                }

                private nonisolated func shouldNotifyObservers<Member: Equatable>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    lhs != rhs
                }

                private nonisolated func shouldNotifyObservers<Member: AnyObject>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    lhs !== rhs
                }

                private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    lhs != rhs
                }

                @ObservationIgnored
                @MainActor
                let _compoundRuntime = CompoundRuntimeStorage()
            }

            extension CounterFeature: CompoundType, Observation.Observable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testCompoundMacroSkipsPublishedStateProperty() throws {
        #if canImport(CompoundMacros)
        let testMacros: [String: Macro.Type] = [
            "Compound": CompoundMacro.self,
            "CompoundKit": CompoundKitMacro.self,
        ]

        assertMacroExpansion(
            """
            @Compound
            final class CounterFeature {
                struct State {}

                @Published var state = State()
            }
            """,
            expandedSource: """
            final class CounterFeature {
                struct State {}

                @Published var state = State()

                @ObservationIgnored
                private let _$observationRegistrar = Observation.ObservationRegistrar()

                internal nonisolated func access<Member>(
                    keyPath: KeyPath<CounterFeature, Member>
                ) {
                    _$observationRegistrar.access(self, keyPath: keyPath)
                }

                internal nonisolated func withMutation<Member, MutationResult>(
                    keyPath: KeyPath<CounterFeature, Member>,
                    _ mutation: () throws -> MutationResult
                ) rethrows -> MutationResult {
                    try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
                }

                private nonisolated func shouldNotifyObservers<Member>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    true
                }

                private nonisolated func shouldNotifyObservers<Member: Equatable>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    lhs != rhs
                }

                private nonisolated func shouldNotifyObservers<Member: AnyObject>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    lhs !== rhs
                }

                private nonisolated func shouldNotifyObservers<Member: Equatable & AnyObject>(
                    _ lhs: Member,
                    _ rhs: Member
                ) -> Bool {
                    lhs != rhs
                }

                @ObservationIgnored
                @MainActor
                let _compoundRuntime = CompoundRuntimeStorage()
            }

            extension CounterFeature: CompoundType, Observation.Observable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testCompoundKitMacroAddsRuntimeStorageAndConformance() throws {
        #if canImport(CompoundMacros)
        let testMacros: [String: Macro.Type] = [
            "Compound": CompoundMacro.self,
            "CompoundKit": CompoundKitMacro.self,
        ]

        assertMacroExpansion(
            """
            @CompoundKit
            final class CounterFeature {
                @Published var state = State()
            }
            """,
            expandedSource: """
            final class CounterFeature {
                @Published var state = State()

                func publisher<Value: Equatable>(
                    _ keyPath: KeyPath<State, Value>
                ) -> AnyPublisher<Value, Never> {
                    $state
                        .map(keyPath)
                        .removeDuplicates()
                        .eraseToAnyPublisher()
                }

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
