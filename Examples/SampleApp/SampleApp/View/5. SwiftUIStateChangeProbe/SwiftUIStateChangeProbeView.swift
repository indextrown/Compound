//
//  SwiftUIStateChangeProbeView.swift
//  SampleApp
//
//  Created by 김동현 on 5/19/26.
//

import SwiftUI
import Compound

struct SwiftUIStateChangeProbeView: View {
    @State private var compound = SwiftUIStateChangeProbeCompound()

    var body: some View {
        let _ = Self._printChanges()
        let inlineCountBackground = Color.blue.opacity(Double.random(in: 0.18...0.4))
        let inlineMessageBackground = Color.green.opacity(Double.random(in: 0.18...0.4))
        let inlineHighlightBackground = Color.orange.opacity(Double.random(in: 0.18...0.4))

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("State Change Probe")
                    .font(.title2.weight(.semibold))

                Text("버튼으로 state의 일부 속성만 바꾸고, Xcode 콘솔의 `_printChanges()` 로그로 어떤 뷰가 다시 계산되는지 확인해보세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("각 카드 배경색은 body가 다시 계산될 때마다 바뀝니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                WholeStateCard(state: compound.state)

                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Child View Split")
                        .font(.headline)

                    Text("아래 3줄은 각각 별도 하위 뷰입니다.")
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
                    Text("2. Inline In Parent Body")
                        .font(.headline)

                    Text("아래 3줄은 하위 뷰로 분리하지 않고 부모 body 안에서 바로 그립니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("count: \(compound.state.count)")
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(inlineCountBackground)
                        )

                    Text("message: \(compound.state.message)")
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(inlineMessageBackground)
                        )

                    Text("isHighlighted: \(compound.state.isHighlighted ? "true" : "false")")
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(inlineHighlightBackground)
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
        .navigationTitle("State Change Probe")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WholeStateCard: View {
    let state: SwiftUIStateChangeProbeCompound.State

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

private extension SliceTextRow {
    static func renderColor(tint: Color) -> Color {
        tint.opacity(Double.random(in: 0.18...0.4))
    }
}
