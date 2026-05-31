//
//  AsyncStreamReactionDemoView.swift
//  RuntimeComparisonApp
//
//  Created by Codex on 5/21/26.
//

import Combine
import SwiftUI

struct AsyncStreamReactionDemoView: View {
    @StateObject private var feature = AsyncStreamReactionFeature()

    var body: some View {
        DemoScreen(
            title: "AsyncStream-Based Reaction",
            summary: "react(action:)가 AsyncStream<Mutation>을 반환하는 방식입니다. loading, result, completion을 시간 순서대로 나눠 보낼 수 있어서 UI가 중간 상태를 즉시 반영할 수 있습니다.",
            implementationSignature: "react(action:) -> AsyncStream<Mutation>",
            isRunning: feature.state.isRunning,
            isLoading: feature.state.isLoading,
            itemCount: feature.state.items.count,
            lastUpdated: feature.state.lastUpdated,
            note: feature.state.note,
            events: feature.state.timeline,
            items: feature.state.items
        ) {
            Task {
                await feature.send(.reloadButtonTapped)
            }
        } scopedContent: {
            DemoCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What to watch")
                        .font(.headline)
                    Text("이 탭은 stream이 시작되자마자 `.setLoading(true)`를 먼저 방출합니다. 네트워크 응답이 오기 전에도 UI가 즉시 중간 상태를 그릴 수 있습니다.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("AsyncStream")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
final class AsyncStreamReactionFeature: ObservableObject {
    struct State: Equatable {
        var isRunning = false
        var isLoading = false
        var items: [DemoItem] = []
        var lastUpdated: Date?
        var note = "Run the demo to see intermediate mutations arrive while async work is still in progress."
        var timeline = ["Idle"]
    }

    enum Action {
        case reloadButtonTapped
    }

    enum Mutation {
        case setLoading(Bool)
        case setItems([DemoItem])
        case setLastUpdated(Date)
        case setNote(String)
    }

    @Published private(set) var state = State()

    private let service = DemoService()

    func send(_ action: Action) async {
        guard !state.isRunning else {
            append("duplicate action ignored")
            return
        }

        state.isRunning = true
        state.timeline = []
        append("send(.reloadButtonTapped)")

        let stream = react(action: action)
        append("react returned AsyncStream immediately")

        for await mutation in stream {
            reduce(mutation)
        }

        append("stream finished after sequential mutation consumption")
        state.isRunning = false
    }

    private func react(action: Action) -> AsyncStream<Mutation> {
        switch action {
        case .reloadButtonTapped:
            return AsyncStream { continuation in
                continuation.yield(.setLoading(true))
                continuation.yield(.setNote("loading=true is emitted immediately, before the network request finishes."))

                let task = Task {
                    do {
                        let items = try await service.fetchItems(for: .asyncStream)
                        continuation.yield(.setItems(items))
                        continuation.yield(.setLastUpdated(Date()))
                        continuation.yield(.setNote("result mutations followed the earlier loading mutation in real time."))
                        continuation.yield(.setLoading(false))
                        continuation.finish()
                    } catch {
                        continuation.yield(.setNote("fetch failed: \(error.localizedDescription)"))
                        continuation.yield(.setLoading(false))
                        continuation.finish()
                    }
                }

                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }
    }

    private func reduce(_ mutation: Mutation) {
        append("reduce(\(mutation.label))")

        switch mutation {
        case .setLoading(let isLoading):
            state.isLoading = isLoading
        case .setItems(let items):
            state.items = items
        case .setLastUpdated(let date):
            state.lastUpdated = date
        case .setNote(let note):
            state.note = note
        }
    }

    private func append(_ message: String) {
        state.timeline.append("[\(formattedClockTime(Date()))] \(message)")
    }
}

private extension AsyncStreamReactionFeature.Mutation {
    var label: String {
        switch self {
        case .setLoading(let isLoading):
            return ".setLoading(\(isLoading))"
        case .setItems(let items):
            return ".setItems(count: \(items.count))"
        case .setLastUpdated:
            return ".setLastUpdated(Date)"
        case .setNote:
            return ".setNote(String)"
        }
    }
}
