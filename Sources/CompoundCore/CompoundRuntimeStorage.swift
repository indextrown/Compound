import Foundation

@MainActor
public final class CompoundRuntimeStorage {
    private var queuedOperations: [@MainActor () async -> Void] = []
    private var isRunning = false
    private var currentTask: Task<Void, Never>?

    public init() {}

    deinit {
        currentTask?.cancel()
        queuedOperations.removeAll()
        isRunning = false
    }

    public func enqueue(
        _ operation: @escaping @MainActor () async -> Void
    ) {
        queuedOperations.append(operation)
        startNextIfPossible()
    }

    public func cancelAll() {
        currentTask?.cancel()
        currentTask = nil
        queuedOperations.removeAll()
        isRunning = false
    }

    private func startNextIfPossible() {
        guard !isRunning, !queuedOperations.isEmpty else { return }

        isRunning = true
        let nextOperation = queuedOperations.removeFirst()

        currentTask = Task { @MainActor [weak self] in
            await nextOperation()
            self?.finishCurrentTask()
        }
    }

    private func finishCurrentTask() {
        currentTask = nil
        isRunning = false
        startNextIfPossible()
    }
}
