//
//  SwiftUIObservableStateProbeView.swift
//  SampleApp
//
//  Created by 김동현 on 5/19/26.
//

import Compound
import SwiftUI

struct SwiftUIObservableStateProbeView: View {
    @State private var compound = SwiftUIObservableStateProbeCompound()

    var body: some View {
        let _ = Self._printChanges()

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("ObservableState Probe")
                    .font(.title2.weight(.semibold))

                Text("이 예제는 `@ObservableState`와 flat access가 native Observation에 연결됐을 때, 실제로 재평가 범위가 어떻게 달라지는지 보는 용도입니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("5번 예제가 기존 `@Published state` 모델이라면, 여기서는 `@State + compound.count` 경로로 field-level invalidation을 확인합니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Split Child Views")
                        .font(.headline)

                    Text("각 child view가 자기 field만 직접 읽습니다. count만 바뀌면 count row만 다시 도는지 보면 됩니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    CountAccessRow(compound: compound)
                    MessageAccessRow(compound: compound)
                    HighlightAccessRow(compound: compound)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("2. Inline Parent Body")
                        .font(.headline)

                    Text("부모 body가 field를 전부 읽고 직접 그립니다. 하나만 바뀌어도 이 구역은 같이 다시 계산되기 쉽습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    inlineRow(
                        title: "count",
                        value: "\(compound.count)",
                        tint: .blue
                    )

                    inlineRow(
                        title: "message",
                        value: compound.message,
                        tint: .green
                    )

                    inlineRow(
                        title: "isHighlighted",
                        value: compound.isHighlighted ? "true" : "false",
                        tint: .orange
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("3. ObservableState Trace")
                        .font(.headline)

                    Text("현재 render 동안 어떤 field access / mutation이 기록되는지 같이 봅니다.")
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

    @ViewBuilder
    private func inlineRow(title: String, value: String, tint: Color) -> some View {
        let backgroundColor = Self.renderColor(tint: tint)

        Text("\(title): \(value)")
            .font(.body.monospaced())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
            )
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

    private static func renderColor(tint: Color) -> Color {
        tint.opacity(Double.random(in: 0.18...0.4))
    }
}

private struct CountAccessRow: View {
    let compound: SwiftUIObservableStateProbeCompound

    var body: some View {
        let _ = Self._printChanges()
        let backgroundColor = Self.renderColor(tint: .blue)

        return Text("count: \(compound.count)")
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

private struct MessageAccessRow: View {
    let compound: SwiftUIObservableStateProbeCompound

    var body: some View {
        let _ = Self._printChanges()
        let backgroundColor = Self.renderColor(tint: .green)

        return Text("message: \(compound.message)")
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

private struct HighlightAccessRow: View {
    let compound: SwiftUIObservableStateProbeCompound

    var body: some View {
        let _ = Self._printChanges()
        let backgroundColor = Self.renderColor(tint: .orange)

        return Text("isHighlighted: \(compound.isHighlighted ? "true" : "false")")
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

private extension CountAccessRow {
    static func renderColor(tint: Color) -> Color {
        tint.opacity(Double.random(in: 0.18...0.4))
    }
}

private extension MessageAccessRow {
    static func renderColor(tint: Color) -> Color {
        tint.opacity(Double.random(in: 0.18...0.4))
    }
}

private extension HighlightAccessRow {
    static func renderColor(tint: Color) -> Color {
        tint.opacity(Double.random(in: 0.18...0.4))
    }
}
