//
//  SwiftUIObservableMacroProbeView.swift
//  SampleApp
//
//  Created by 김동현 on 5/19/26.
//

import SwiftUI

#if canImport(Observation)
import Observation

@available(iOS 17.0, *)
struct SwiftUIObservableMacroProbeView: View {
    @State private var model = SwiftUIObservableMacroProbeModel()

    var body: some View {
        let _ = Self._printChanges()

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Vanilla @Observable Probe")
                    .font(.title2.weight(.semibold))

                Text("Compound 없이 Swift가 iOS 17부터 제공하는 `@Observable`만 사용한 예제입니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("6번 예제와 비교하면, 같은 field-level observation이 바닐라 SwiftUI에서는 어떻게 보이는지 바로 볼 수 있습니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Split Child Views")
                        .font(.headline)

                    Text("각 child view가 자기 field만 직접 읽습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VanillaCountRow(model: model)
                    VanillaMessageRow(model: model)
                    VanillaHighlightRow(model: model)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("2. Inline Parent Body")
                        .font(.headline)

                    Text("부모 body가 field를 전부 읽고 직접 그립니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    inlineRow(
                        title: "count",
                        value: "\(model.count)",
                        tint: .blue
                    )

                    inlineRow(
                        title: "message",
                        value: model.message,
                        tint: .green
                    )

                    inlineRow(
                        title: "isHighlighted",
                        value: model.isHighlighted ? "true" : "false",
                        tint: .orange
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Button("Increase Count") {
                        model.increaseCount()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Change Message") {
                        model.changeMessage()
                    }
                    .buttonStyle(.bordered)

                    Button("Toggle Highlight") {
                        model.toggleHighlight()
                    }
                    .buttonStyle(.bordered)

                    Button("Reset") {
                        model.reset()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("Vanilla @Observable")
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

    private static func renderColor(tint: Color) -> Color {
        tint.opacity(Double.random(in: 0.18...0.4))
    }
}

@available(iOS 17.0, *)
private struct VanillaCountRow: View {
    let model: SwiftUIObservableMacroProbeModel

    var body: some View {
        let _ = Self._printChanges()
        let backgroundColor = Self.renderColor(tint: .blue)

        return Text("count: \(model.count)")
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

@available(iOS 17.0, *)
private struct VanillaMessageRow: View {
    let model: SwiftUIObservableMacroProbeModel

    var body: some View {
        let _ = Self._printChanges()
        let backgroundColor = Self.renderColor(tint: .green)

        return Text("message: \(model.message)")
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

@available(iOS 17.0, *)
private struct VanillaHighlightRow: View {
    let model: SwiftUIObservableMacroProbeModel

    var body: some View {
        let _ = Self._printChanges()
        let backgroundColor = Self.renderColor(tint: .orange)

        return Text("isHighlighted: \(model.isHighlighted ? "true" : "false")")
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

@available(iOS 17.0, *)
private extension VanillaCountRow {
    static func renderColor(tint: Color) -> Color {
        tint.opacity(Double.random(in: 0.18...0.4))
    }
}

@available(iOS 17.0, *)
private extension VanillaMessageRow {
    static func renderColor(tint: Color) -> Color {
        tint.opacity(Double.random(in: 0.18...0.4))
    }
}

@available(iOS 17.0, *)
private extension VanillaHighlightRow {
    static func renderColor(tint: Color) -> Color {
        tint.opacity(Double.random(in: 0.18...0.4))
    }
}

#else

struct SwiftUIObservableMacroProbeView: View {
    var body: some View {
        Text("@Observable is unavailable on this platform.")
            .foregroundStyle(.secondary)
            .navigationTitle("Vanilla @Observable")
    }
}

#endif
