//
//  ArrayReactionDemoView.swift
//  RuntimeComparisonApp
//
//  Created by Codex on 5/21/26.
//

import Combine
import SwiftUI

struct ArrayReactionDemoView: View {
    @StateObject private var feature = ArrayReactionFeature()

    var body: some View {
        DemoScreen(
            title: "Array-Based Reaction",
            summary: "react(action:)가 [Mutation]을 한 번에 반환하는 방식입니다. 비동기 작업이 끝난 뒤에야 mutation 배열이 도착하므로 중간 loading 상태를 바로 보여주기 어렵습니다.",
            implementationSignature: "react(action:) async -> [Mutation]",
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
                    Text("이 탭은 fetch가 끝난 다음에야 `[.setLoading(true), .setItems(...), .setLoading(false)]`를 적용합니다. 그래서 spinner가 너무 늦거나 거의 보이지 않을 수 있습니다.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("[Mutation]")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
final class ArrayReactionFeature: ObservableObject {
    struct State: Equatable {
        var isRunning = false
        var isLoading = false
        var items: [DemoItem] = []
        var lastUpdated: Date?
        var note = "Run the demo to see how [Mutation] arrives only after the async work ends."
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

        let mutations = await react(action: action)
        append("react finished and returned \(mutations.count) mutations at once")

        for mutation in mutations {
            reduce(mutation)
        }

        append("all mutations reduced in a single post-fetch pass")
        state.isRunning = false
    }

    private func react(action: Action) async -> [Mutation] {
        switch action {
        case .reloadButtonTapped:
            append("react started: awaiting service.fetchItems()")

            do {
                let items = try await service.fetchItems(for: .array)
                append("fetch completed: only now can [Mutation] be returned")

                return [
                    .setLoading(true),
                    .setNote("loading=true also arrives after fetch completion, so the mid-flight state is not observable in real time."),
                    .setItems(items),
                    .setLastUpdated(Date()),
                    .setLoading(false),
                ]
            } catch {
                return [
                    .setNote("fetch failed: \(error.localizedDescription)"),
                    .setLoading(false),
                ]
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

private extension ArrayReactionFeature.Mutation {
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
