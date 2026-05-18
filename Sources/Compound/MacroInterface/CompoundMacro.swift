@attached(member, names: named(_compoundRuntime))
@attached(extension, conformances: CompoundType)
public macro Compound() = #externalMacro(
    module: "CompoundMacros",
    type: "CompoundMacro"
)
