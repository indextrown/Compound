@attached(member, names: arbitrary)
@attached(extension, conformances: CompoundType)
public macro Compound() = #externalMacro(
    module: "CompoundMacros",
    type: "CompoundMacro"
)
