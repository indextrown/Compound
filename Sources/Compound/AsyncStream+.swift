import Foundation

public extension AsyncStream where Element: Sendable {
    /// 요소 하나를 즉시 방출하고 바로 종료하는 stream을 만듭니다.
    static func just(_ element: Element) -> AsyncStream<Element> {
        AsyncStream { continuation in
            continuation.yield(element)
            continuation.finish()
        }
    }
}

public extension AsyncStream where Element: Sendable {
    /// 여러 stream을 입력 순서대로 이어 붙입니다.
    ///
    /// 앞선 stream이 종료된 뒤에만 다음 stream이 시작됩니다.
    /// 상태 전이 순서를 예측 가능하게 유지해야 할 때 기본으로 선호하는 조합 방식입니다.
    static func concat(
        _ streams: AsyncStream<Element>...
    ) -> AsyncStream<Element> {
        AsyncStream { continuation in
            let task = Task {
                for stream in streams {
                    for await element in stream {
                        continuation.yield(element)
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

public extension AsyncStream where Element: Sendable {
    /// 여러 stream을 동시에 실행해, 도착하는 순서대로 값을 방출합니다.
    ///
    /// 입력 순서는 보장되지 않으며, 실제 방출 순서는 각 stream의 완료 시점에 따라 달라집니다.
    /// `merge`는 강력하지만 `concat`보다 상태 전이 순서를 추적하기 훨씬 어려울 수 있으므로
    /// 기본 조합 도구라기보다 고급 도구로 취급하는 편이 좋습니다.
    static func merge(
        _ streams: AsyncStream<Element>...
    ) -> AsyncStream<Element> {
        AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    for stream in streams {
                        group.addTask {
                            for await element in stream {
                                continuation.yield(element)
                            }
                        }
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
