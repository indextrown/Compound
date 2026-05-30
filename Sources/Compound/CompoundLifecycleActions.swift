import SwiftUI

internal struct CompoundLifecycleNoID: Equatable {}

internal struct CompoundLifecycleActionGate<ID: Equatable> {
    private var hasSent = false

    mutating func shouldSend(once: Bool) -> Bool {
        guard !once || !hasSent else { return false }

        hasSent = true
        return true
    }

    mutating func shouldSend(id: ID, once: Bool) -> Bool {
        shouldSend(once: once)
    }
}

private struct CompoundTaskModifier<C: CompoundType>: ViewModifier {
    let compound: C
    let action: C.Action
    let once: Bool

    @State private var gate = CompoundLifecycleActionGate<CompoundLifecycleNoID>()

    func body(content: Content) -> some View {
        content.task { @MainActor in
            sendIfNeeded()
        }
    }

    @MainActor
    private func sendIfNeeded() {
        guard gate.shouldSend(once: once) else { return }
        compound.send(action)
    }
}

private struct CompoundTaskIDModifier<C: CompoundType, ID: Equatable>: ViewModifier {
    let compound: C
    let action: C.Action
    let id: ID
    let once: Bool

    @State private var gate = CompoundLifecycleActionGate<ID>()

    func body(content: Content) -> some View {
        content.task(id: id) { @MainActor in
            sendIfNeeded()
        }
    }

    @MainActor
    private func sendIfNeeded() {
        guard gate.shouldSend(id: id, once: once) else { return }
        compound.send(action)
    }
}

private struct CompoundOnAppearModifier<C: CompoundType>: ViewModifier {
    let compound: C
    let action: C.Action
    let once: Bool

    @State private var gate = CompoundLifecycleActionGate<CompoundLifecycleNoID>()

    func body(content: Content) -> some View {
        content.onAppear {
            Task { @MainActor in
                sendIfNeeded()
            }
        }
    }

    @MainActor
    private func sendIfNeeded() {
        guard gate.shouldSend(once: once) else { return }
        compound.send(action)
    }
}

public extension View {
    /// Sends a lifecycle action once when SwiftUI starts the view's task.
    ///
    /// Use this for initial loading. The Compound initializer stays side-effect free,
    /// while loading still flows through `Action -> Reaction -> State`.
    func compoundOnLoad<C: CompoundType>(
        _ compound: C,
        _ action: C.Action,
        once: Bool = true
    ) -> some View {
        modifier(CompoundTaskModifier(compound: compound, action: action, once: once))
    }

    /// Sends an action from SwiftUI `onAppear`.
    ///
    /// Set `once` to `false` when every appearance should trigger the action again.
    func compoundOnAppear<C: CompoundType>(
        _ compound: C,
        _ action: C.Action,
        once: Bool = true
    ) -> some View {
        modifier(CompoundOnAppearModifier(compound: compound, action: action, once: once))
    }

    /// Sends an action from SwiftUI `.task`.
    ///
    /// This is useful for lifecycle work that belongs to SwiftUI's async task model.
    func compoundTask<C: CompoundType>(
        _ compound: C,
        action: C.Action,
        once: Bool = true
    ) -> some View {
        modifier(CompoundTaskModifier(compound: compound, action: action, once: once))
    }

    /// Sends an action from SwiftUI `.task(id:)`.
    ///
    /// With the default `once: false`, SwiftUI starts the task again when `id` changes.
    /// Set `once` to `true` when only the first task should send the action.
    func compoundTask<C: CompoundType, ID: Equatable>(
        _ compound: C,
        action: C.Action,
        id: ID,
        once: Bool = false
    ) -> some View {
        modifier(CompoundTaskIDModifier(compound: compound, action: action, id: id, once: once))
    }
}
