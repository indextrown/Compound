@attached(member, names: named(_$observationRegistrar), named(shouldNotifyObservers))
@attached(memberAttribute)
@attached(extension, conformances: ObservableState)
public macro ObservableState() = #externalMacro(
    module: "CompoundMacros",
    type: "ObservableStateMacro"
)

@attached(accessor, names: named(init), named(get), named(set), named(_modify))
@attached(peer, names: prefixed(_))
public macro ObservableStateTracked() = #externalMacro(
    module: "CompoundMacros",
    type: "ObservableStateTrackedMacro"
)

@attached(accessor, names: named(willSet))
public macro ObservableStateIgnored() = #externalMacro(
    module: "CompoundMacros",
    type: "ObservableStateIgnoredMacro"
)
