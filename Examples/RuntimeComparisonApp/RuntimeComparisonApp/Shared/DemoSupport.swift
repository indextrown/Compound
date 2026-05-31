//
//  DemoSupport.swift
//  RuntimeComparisonApp
//
//  Created by Codex on 5/21/26.
//

import SwiftUI

struct DemoItem: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let subtitle: String
}

enum DemoMode: String, Sendable {
    case array = "[Mutation]"
    case managedArray = "Array Fix"
    case asyncStream = "AsyncStream"
}

struct DemoService: Sendable {
    func fetchItems(for mode: DemoMode) async throws -> [DemoItem] {
        try await Task.sleep(for: .seconds(1.2))

        return [
            DemoItem(id: 1, title: "\(mode.rawValue) First Step", subtitle: "load start -> network wait -> state update"),
            DemoItem(id: 2, title: "\(mode.rawValue) Second Step", subtitle: "mid-flight loading visibility comparison"),
            DemoItem(id: 3, title: "\(mode.rawValue) Third Step", subtitle: "timeline order is shown below"),
        ]
    }
}

func formattedClockTime(_ date: Date?) -> String {
    guard let date else {
        return "Not yet"
    }

    return date.formatted(date: .omitted, time: .standard)
}

struct DemoScreen<ScopedContent: View>: View {
    let title: String
    let summary: String
    let implementationSignature: String
    let isRunning: Bool
    let isLoading: Bool
    let itemCount: Int
    let lastUpdated: Date?
    let note: String
    let events: [String]
    let items: [DemoItem]
    let runAction: () -> Void
    @ViewBuilder let scopedContent: ScopedContent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DemoCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(title)
                            .font(.title2.bold())
                        Text(summary)
                            .foregroundStyle(.secondary)

                        Label(implementationSignature, systemImage: "curlybraces")
                            .font(.footnote.monospaced())
                            .foregroundStyle(.blue)
                    }
                }

                Button(action: runAction) {
                    HStack {
                        Image(systemName: isRunning ? "hourglass" : "play.fill")
                        Text(isRunning ? "Running..." : "Run Refresh Demo")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)

                DemoCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("State Snapshot")
                                .font(.headline)
                            Spacer()

                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }

                        DemoKeyValueRow(key: "isLoading", value: isLoading ? "true" : "false")
                        DemoKeyValueRow(key: "items", value: "\(itemCount)")
                        DemoKeyValueRow(key: "lastUpdated", value: formattedClockTime(lastUpdated))

                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                scopedContent

                DemoCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Items")
                            .font(.headline)

                        if items.isEmpty {
                            Text("No items yet. Run the demo to populate this section.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(items) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(item.subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                if item.id != items.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                DemoCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Timeline")
                            .font(.headline)

                        ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1).")
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text(event)
                                    .font(.footnote.monospaced())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

struct DemoCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

struct DemoKeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack {
            Text(key)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.footnote.monospaced())
        }
    }
}
