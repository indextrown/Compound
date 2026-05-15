//
//  File.swift
//  Compound
//
//  Created by 김동현 on 5/15/26.
//

import Foundation

public extension AsyncStream where Element: Sendable {
    static func just(_ element: Element) -> AsyncStream<Element> {
        AsyncStream { continuation in
            continuation.yield(element)
            continuation.finish()
        }
    }
}

public extension AsyncStream where Element: Sendable {
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
