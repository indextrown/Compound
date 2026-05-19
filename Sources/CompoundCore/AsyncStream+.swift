import Foundation

public extension AsyncStream where Element: Sendable {
    static func just(_ element: Element) -> AsyncStream<Element> {
        AsyncStream { continuation in
            continuation.yield(element)
            continuation.finish()
        }
    }

    static func run(
        _ work: @escaping @Sendable (_ send: @escaping @Sendable (Element) async -> Void) async -> Void
    ) -> AsyncStream<Element> {
        AsyncStream { continuation in
            let task = Task {
                await work { value in
                    continuation.yield(value)
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    static func delay(
        _ duration: Duration,
        then element: Element
    ) -> AsyncStream<Element> {
        .run { send in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            await send(element)
        }
    }

    static func concat(
        _ streams: AsyncStream<Element>...
    ) -> AsyncStream<Element> {
        concat(streams)
    }

    static func concat(
        _ streams: [AsyncStream<Element>]
    ) -> AsyncStream<Element> {
        AsyncStream { continuation in
            let task = Task {
                for stream in streams {
                    guard !Task.isCancelled else { return }

                    for await value in stream {
                        guard !Task.isCancelled else { return }
                        continuation.yield(value)
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    static func merge(
        _ streams: AsyncStream<Element>...
    ) -> AsyncStream<Element> {
        merge(streams)
    }

    static func merge(
        _ streams: [AsyncStream<Element>]
    ) -> AsyncStream<Element> {
        AsyncStream { continuation in
            let tasks = streams.map { stream in
                Task {
                    for await value in stream {
                        guard !Task.isCancelled else { return }
                        continuation.yield(value)
                    }
                }
            }

            let finishingTask = Task {
                for task in tasks {
                    await task.value
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                tasks.forEach { $0.cancel() }
                finishingTask.cancel()
            }
        }
    }
}
