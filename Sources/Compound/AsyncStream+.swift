//
//  AsyncStream+.swift
//  Compound
//
//  Created by 김동현 on 5/16/26.
//

import Foundation

/// `AsyncStream.run` 내부에서 값을 방출하기 위해 사용되는 타입입니다.
///
/// 사용자가 직접 생성해서 쓰기보다는, `.run { send in ... }` 클로저의
/// 파라미터로 전달받아 사용하는 것을 의도합니다.
///
/// 예:
///
/// ```swift
/// .run { send in
///     await send(.setLoading(true))
///     await send(.setMessage("완료"))
/// }
/// ```
public struct Sender<Element: Sendable>: Sendable {
    private let yield: @Sendable (Element) async -> Void

    public init(
        _ yield: @escaping @Sendable (Element) async -> Void
    ) {
        self.yield = yield
    }

    /// 값을 stream 밖으로 방출합니다.
    ///
    /// `callAsFunction`을 사용하기 때문에 아래처럼 함수처럼 호출할 수 있습니다.
    ///
    /// ```swift
    /// await send(.setLoading(true))
    /// ```
    public func callAsFunction(_ element: Element) async {
        await yield(element)
    }
}

public extension AsyncStream where Element: Sendable {
    /// 요소 하나를 즉시 방출하고 바로 종료하는 stream을 만듭니다.
    ///
    /// 단일 Reaction을 반환할 때 가장 간단하게 사용할 수 있습니다.
    ///
    /// 예:
    ///
    /// ```swift
    /// return .just(.increase)
    /// ```
    ///
    /// 방출 순서:
    ///
    /// ```text
    /// element 방출
    /// 종료
    /// ```
    static func just(_ element: Element) -> AsyncStream<Element> {
        AsyncStream { continuation in
            continuation.yield(element)
            continuation.finish()
        }
    }

    /// 비동기 작업 안에서 여러 요소를 원하는 타이밍에 방출할 수 있는 stream을 만듭니다.
    ///
    /// `AsyncStream`의 `continuation`, `finish`, `onTermination`, `Task` 처리를
    /// 매번 직접 작성하지 않기 위한 헬퍼입니다.
    ///
    /// 예:
    ///
    /// ```swift
    /// return .run { send in
    ///     try await Task.sleep(for: .milliseconds(800))
    ///     await send(.setRefreshCount(1))
    ///     await send(.setStatusMessage("완료"))
    /// }
    /// ```
    ///
    /// 내부적으로는 다음 작업을 처리합니다.
    ///
    /// - `AsyncStream` 생성
    /// - 비동기 `Task` 생성
    /// - `send(...)` 호출 시 `continuation.yield(...)` 실행
    /// - 작업 완료 시 `continuation.finish()` 실행
    /// - stream 종료 시 task cancel 처리
    static func run(
        _ operation: @escaping @Sendable (_ send: Sender<Element>) async throws -> Void
    ) -> AsyncStream<Element> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    let sender = Sender<Element> { element in
                        continuation.yield(element)
                    }

                    try await operation(sender)
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// 일정 시간 뒤 요소 하나를 방출하고 종료하는 stream을 만듭니다.
    ///
    /// 단순히 “조금 기다렸다가 값 하나를 방출”하는 경우 `run`보다 간결하게 사용할 수 있습니다.
    ///
    /// 예:
    ///
    /// ```swift
    /// return .delay(.milliseconds(800), then: .setLoading(false))
    /// ```
    ///
    /// 방출 순서:
    ///
    /// ```text
    /// duration만큼 대기
    /// element 방출
    /// 종료
    /// ```
    static func delay(
        _ duration: Duration,
        then element: Element
    ) -> AsyncStream<Element> {
        .run { send in
            try await Task.sleep(for: duration)
            await send(element)
        }
    }

    /// 여러 stream을 입력 순서대로 이어 붙입니다.
    ///
    /// 앞선 stream이 종료된 뒤에만 다음 stream이 시작됩니다.
    /// 상태 전이 순서를 예측 가능하게 유지해야 할 때 기본으로 선호하는 조합 방식입니다.
    ///
    /// 예:
    ///
    /// ```swift
    /// return .concat(
    ///     .just(.setLoading(true)),
    ///     .run { send in
    ///         try await Task.sleep(for: .milliseconds(800))
    ///         await send(.setStatusMessage("완료"))
    ///     },
    ///     .just(.setLoading(false))
    /// )
    /// ```
    ///
    /// 방출 순서:
    ///
    /// ```text
    /// 첫 번째 stream 시작
    /// 첫 번째 stream 종료
    /// 두 번째 stream 시작
    /// 두 번째 stream 종료
    /// ...
    /// 전체 종료
    /// ```
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

    /// 여러 stream을 동시에 실행해, 도착하는 순서대로 값을 방출합니다.
    ///
    /// 입력 순서는 보장되지 않으며, 실제 방출 순서는 각 stream의 완료 시점에 따라 달라집니다.
    /// `merge`는 강력하지만 `concat`보다 상태 전이 순서를 추적하기 어려울 수 있으므로
    /// 기본 조합 도구라기보다 고급 도구로 취급하는 편이 좋습니다.
    ///
    /// 예:
    ///
    /// ```swift
    /// return .merge(
    ///     fetchUserStream(),
    ///     fetchPostsStream(),
    ///     fetchNoticeStream()
    /// )
    /// ```
    ///
    /// 방출 순서:
    ///
    /// ```text
    /// 모든 stream 동시 시작
    /// 먼저 값이 도착한 stream부터 방출
    /// 모든 stream 종료 후 전체 종료
    /// ```
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
