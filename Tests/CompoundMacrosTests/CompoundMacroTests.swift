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
            "ObservableState": ObservableStateMacro.self,
            "ObservableStateTracked": ObservableStateTrackedMacro.self,
            "ObservableStateIgnored": ObservableStateIgnoredMacro.self,
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
            "ObservableState": ObservableStateMacro.self,
            "ObservableStateTracked": ObservableStateTrackedMacro.self,
            "ObservableStateIgnored": ObservableStateIgnoredMacro.self,
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

    func testObservableStateMacroAddsObservableStateConformance() throws {
        #if canImport(CompoundMacros)
        let testMacros: [String: Macro.Type] = [
            "ObservableState": ObservableStateMacro.self,
            "ObservableStateTracked": ObservableStateTrackedMacro.self,
            "ObservableStateIgnored": ObservableStateIgnoredMacro.self,
        ]

        assertMacroExpansion(
            """
            @ObservableState
            struct State: Equatable {
                var count = 0
            }
            """,
            expandedSource: """
            struct State: Equatable {
                var count {
                    @storageRestrictions(initializes: _count)
                    init(initialValue) {
                        _count = initialValue
                    }
                    get {
                        _$observationRegistrar.access(self, keyPath: \\Self.count)
                        return _count
                    }
                    set {
                        _$observationRegistrar._$mutate(self, keyPath: \\Self.count, &_count, newValue, shouldNotifyObservers)
                    }
                    _modify {
                        _$observationRegistrar.willModify(self, keyPath: \\Self.count, &_count)
                        defer {
                            _$observationRegistrar.didModify(self, keyPath: \\Self.count, &_count)
                        }
                        yield &_count
                    }
                }

                private  var _count  = 0

                var _$observationRegistrar = ObservableStateRegistrar()

                private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
                    true
                }

                private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
                    lhs != rhs
                }
            }

            extension State: ObservableState {
            }

            @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
            extension State: Observation.Observable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testCompoundMacroKeepsWholeStateAccessPath() throws {
        #if canImport(CompoundMacros)
        let testMacros: [String: Macro.Type] = [
            "Compound": CompoundMacro.self,
            "ObservableState": ObservableStateMacro.self,
            "ObservableStateTracked": ObservableStateTrackedMacro.self,
            "ObservableStateIgnored": ObservableStateIgnoredMacro.self,
        ]

        assertMacroExpansion(
            """
            @Compound
            final class CounterFeature {
                @ObservableState
                struct State: Equatable {
                    var count: Int = 0
                }

                @Published var state = State()
            }
            """,
            expandedSource: """
            final class CounterFeature {
                struct State: Equatable {
                    var count: Int {
                        @storageRestrictions(initializes: _count)
                        init(initialValue) {
                            _count = initialValue
                        }
                        get {
                            _$observationRegistrar.access(self, keyPath: \\Self.count)
                            return _count
                        }
                        set {
                            _$observationRegistrar._$mutate(self, keyPath: \\Self.count, &_count, newValue, shouldNotifyObservers)
                        }
                        _modify {
                            _$observationRegistrar.willModify(self, keyPath: \\Self.count, &_count)
                            defer {
                                _$observationRegistrar.didModify(self, keyPath: \\Self.count, &_count)
                            }
                            yield &_count
                        }
                    }

                    private  var _count: Int = 0

                    var _$observationRegistrar = ObservableStateRegistrar()

                    private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
                        true
                    }

                    private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
                        lhs != rhs
                    }
                }

                @Published var state = State()

                @MainActor
                let _compoundRuntime = CompoundRuntimeStorage()

                @MainActor
                var count: Int {
                    get {
                        // 첫 단계에서는 `state`를 그대로 forwarding하는 read path를 만듭니다.
                        // 추후 observation runtime을 붙일 때 이 경로를 tracked access로 확장합니다.
                        state.count
                    }
                    set {
                        var newState = state
                        newState.count = newValue
                        state = newState
                    }
                }
            }

            extension CounterFeature.State: ObservableState {
            }

            @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
            extension CounterFeature.State: Observation.Observable {
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

    func testCompoundMacroKeepsLegacyStateWhenObservableStateIsNotApplied() throws {
        #if canImport(CompoundMacros)
        let testMacros: [String: Macro.Type] = [
            "Compound": CompoundMacro.self,
            "ObservableState": ObservableStateMacro.self,
            "ObservableStateTracked": ObservableStateTrackedMacro.self,
            "ObservableStateIgnored": ObservableStateIgnoredMacro.self,
        ]

        assertMacroExpansion(
            """
            @Compound
            final class CounterFeature {
                struct State: Equatable {
                    var count = 0
                }

                @Published var state = State()
            }
            """,
            expandedSource: """
            final class CounterFeature {
                struct State: Equatable {
                    var count = 0
                }

                @Published var state = State()

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

    func testCompoundMacroWarnsWhenObservableStatePropertyOmitsTypeAnnotation() throws {
        #if canImport(CompoundMacros)
        let testMacros: [String: Macro.Type] = [
            "Compound": CompoundMacro.self,
            "ObservableState": ObservableStateMacro.self,
            "ObservableStateTracked": ObservableStateTrackedMacro.self,
            "ObservableStateIgnored": ObservableStateIgnoredMacro.self,
        ]

        assertMacroExpansion(
            """
            @Compound
            final class CounterFeature {
                @ObservableState
                struct State: Equatable {
                    var count = 0
                }

                @Published var state = State()
            }
            """,
            expandedSource: """
            final class CounterFeature {
                struct State: Equatable {
                    var count {
                        @storageRestrictions(initializes: _count)
                        init(initialValue) {
                            _count = initialValue
                        }
                        get {
                            _$observationRegistrar.access(self, keyPath: \\Self.count)
                            return _count
                        }
                        set {
                            _$observationRegistrar._$mutate(self, keyPath: \\Self.count, &_count, newValue, shouldNotifyObservers)
                        }
                        _modify {
                            _$observationRegistrar.willModify(self, keyPath: \\Self.count, &_count)
                            defer {
                                _$observationRegistrar.didModify(self, keyPath: \\Self.count, &_count)
                            }
                            yield &_count
                        }
                    }

                    private  var _count  = 0

                    var _$observationRegistrar = ObservableStateRegistrar()

                    private nonisolated func shouldNotifyObservers<Member>(_ lhs: Member, _ rhs: Member) -> Bool {
                        true
                    }

                    private nonisolated func shouldNotifyObservers<Member: Equatable>(_ lhs: Member, _ rhs: Member) -> Bool {
                        lhs != rhs
                    }
                }

                @Published var state = State()

                @MainActor
                let _compoundRuntime = CompoundRuntimeStorage()
            }

            extension CounterFeature.State: ObservableState {
            }

            @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
            extension CounterFeature.State: Observation.Observable {
            }

            extension CounterFeature: CompoundType {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "`@ObservableState` property 'count' needs an explicit type annotation to generate flat access on the compound",
                    line: 5,
                    column: 9,
                    severity: .warning
                )
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
