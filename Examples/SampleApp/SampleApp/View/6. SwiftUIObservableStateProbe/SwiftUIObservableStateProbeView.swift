//
//  SwiftUIObservableStateProbeView.swift
//  SampleApp
//
//  Created by 김동현 on 5/19/26.
//

import SwiftUI
import Compound

struct SwiftUIObservableStateProbeView: View {
    @StateObject private var compound = SwiftUIObservableStateProbeCompound()

    var body: some View {
        let _ = Self._printChanges()

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("ObservableState Probe")
                    .font(.title2.weight(.semibold))

                Text("기존 `compound.state.xxx` 경로와 새 `compound.xxx` 경로를 같은 화면에서 비교합니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("지금 단계에서는 field access / mutation 기록까지 확인할 수 있습니다. invalidation 범위 축소는 다음 단계에서 연결합니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

//                WholeStateCard(state: compound.state)

                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Legacy State Path")
                        .font(.headline)

                    Text("기존 방식입니다. `compound.state.xxx`로 읽습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    SliceTextRow(
                        title: "count",
                        value: "\(compound.state.count)",
                        tint: .blue
                    )

                    SliceTextRow(
                        title: "message",
                        value: compound.state.message,
                        tint: .green
                    )

                    SliceTextRow(
                        title: "isHighlighted",
                        value: compound.state.isHighlighted ? "true" : "false",
                        tint: .orange
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("2. Flat Access Path")
                        .font(.headline)

                    Text("새 방식입니다. `compound.count`, `compound.message`, `compound.isHighlighted`로 읽습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    SliceTextRow(
                        title: "count",
                        value: "\(compound.count)",
                        tint: .blue
                    )

                    SliceTextRow(
                        title: "message",
                        value: compound.message,
                        tint: .green
                    )

                    SliceTextRow(
                        title: "isHighlighted",
                        value: compound.isHighlighted ? "true" : "false",
                        tint: .orange
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("3. ObservableState Trace")
                        .font(.headline)

                    Text("현재 단계에서 registrar가 어떤 field access / mutation을 기록하는지 보여줍니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TraceCard(
                        title: "Accessed",
                        values: accessNames
                    )

                    TraceCard(
                        title: "Mutated",
                        values: mutationNames
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Button("Increase Count") {
                        compound.send(.increaseCountButtonTapped)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Change Message") {
                        compound.send(.changeMessageButtonTapped)
                    }
                    .buttonStyle(.bordered)

                    Button("Toggle Highlight") {
                        compound.send(.toggleHighlightButtonTapped)
                    }
                    .buttonStyle(.bordered)

                    Button("Reset") {
                        compound.send(.resetButtonTapped)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("ObservableState Probe")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var accessNames: [String] {
        compound.state._$observationRegistrar._$accessedKeyPaths.compactMap { keyPath in
            Self.name(for: keyPath)
        }
    }

    private var mutationNames: [String] {
        compound.state._$observationRegistrar._$mutatedKeyPaths.compactMap { keyPath in
            Self.name(for: keyPath)
        }
        .sorted()
    }

    private static func name(for keyPath: AnyKeyPath) -> String? {
        if keyPath == \SwiftUIObservableStateProbeCompound.State.count {
            return "count"
        }
        if keyPath == \SwiftUIObservableStateProbeCompound.State.message {
            return "message"
        }
        if keyPath == \SwiftUIObservableStateProbeCompound.State.isHighlighted {
            return "isHighlighted"
        }
        return nil
    }
}

private struct WholeStateCard: View {
    let state: SwiftUIObservableStateProbeCompound.State

    var body: some View {
        let _ = Self._printChanges()

        return VStack(alignment: .leading, spacing: 8) {
            Text("Whole State Snapshot")
                .font(.headline)

            Text("count: \(state.count)")
            Text("message: \(state.message)")
            Text("isHighlighted: \(state.isHighlighted ? "true" : "false")")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(state.isHighlighted ? Color.yellow.opacity(0.25) : Color.secondary.opacity(0.08))
        )
    }
}

private struct SliceTextRow: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        let _ = Self._printChanges()
        let backgroundColor = Self.renderColor(tint: tint)

        return Text("\(title): \(value)")
            .font(.body.monospaced())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
            )
    }
}

private struct TraceCard: View {
    let title: String
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(values.isEmpty ? "[]" : values.joined(separator: ", "))
                .font(.body.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}

private extension SliceTextRow {
    static func renderColor(tint: Color) -> Color {
        tint.opacity(Double.random(in: 0.18...0.4))
    }
}
