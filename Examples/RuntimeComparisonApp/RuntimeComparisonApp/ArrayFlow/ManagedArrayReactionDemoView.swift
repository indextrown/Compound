//
//  ManagedArrayReactionDemoView.swift
//  RuntimeComparisonApp
//
//  Created by Codex on 5/21/26.
//

import Combine
import SwiftUI

struct ManagedArrayReactionDemoView: View {
    @StateObject private var feature = ManagedArrayReactionFeature()

    var body: some View {
        DemoScreen(
            title: "Array + Manual Loading",
            summary: "배열 방식은 유지하고, loading만 send 단계에서 직접 관리합니다.",
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
                    Text("배열은 마지막에 받고, 로딩 UI만 먼저 켭니다.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Array Fix")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
final class ManagedArrayReactionFeature: ObservableObject {
    struct State: Equatable {
        var isRunning = false
        var isLoading = false
        var items: [DemoItem] = []
        var lastUpdated: Date?
        var note = "loading은 send에서 먼저 켭니다."
        var timeline = ["Idle"]
    }

    enum Action {
        case reloadButtonTapped
    }

    enum Mutation {
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

        // Array 방식은 유지하되, 로딩 UI는 send 단계에서 직접 관리합니다.
        state.isLoading = true
        append("manual state change: isLoading = true")

        let mutations = await react(action: action)
        append("react finished and returned \(mutations.count) mutations")

        for mutation in mutations {
            reduce(mutation)
        }

        state.isLoading = false
        append("manual state change: isLoading = false")
        state.isRunning = false
    }

    private func react(action: Action) async -> [Mutation] {
        switch action {
        case .reloadButtonTapped:
            append("react started: awaiting service.fetchItems()")

            do {
                let items = try await service.fetchItems(for: .managedArray)
                append("fetch completed: returning [Mutation]")

                return [
                    .setItems(items),
                    .setLastUpdated(Date()),
                    .setNote("중간 로딩은 직접 관리했고, 결과만 배열로 받았습니다."),
                ]
            } catch {
                return [
                    .setNote("fetch failed: \(error.localizedDescription)"),
                ]
            }
        }
    }

    private func reduce(_ mutation: Mutation) {
        append("reduce(\(mutation.label))")

        switch mutation {
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

private extension ManagedArrayReactionFeature.Mutation {
    var label: String {
        switch self {
        case .setItems(let items):
            return ".setItems(count: \(items.count))"
        case .setLastUpdated:
            return ".setLastUpdated(Date)"
        case .setNote:
            return ".setNote(String)"
        }
    }
}
