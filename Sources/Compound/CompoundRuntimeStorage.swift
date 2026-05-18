import Foundation

/// 같은 Compound 인스턴스에 들어오는 action을 순차 처리하기 위한 인스턴스별 runtime storage입니다.
@MainActor
public final class CompoundRuntimeStorage {
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var lastTask: Task<Void, Never>?

    public init() {}

    deinit {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        lastTask = nil
    }

    func enqueue(operation: @escaping () async -> Void) {
        let previousTask = lastTask
        let token = UUID()

        let task = Task { [weak self] in
            await previousTask?.value

            guard !Task.isCancelled else {
                await MainActor.run { [weak self] in
                    self?.removeTask(token: token)
                }
                return
            }

            await operation()

            await MainActor.run { [weak self] in
                self?.removeTask(token: token)
            }
        }

        tasks[token] = task
        lastTask = task
    }

    func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        lastTask = nil
    }

    private func removeTask(token: UUID) {
        tasks[token] = nil

        if tasks.isEmpty {
            lastTask = nil
        }
    }
}
