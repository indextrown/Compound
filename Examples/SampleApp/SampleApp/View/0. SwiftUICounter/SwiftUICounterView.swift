//
//  SwiftUICounterView.swift
//  SampleApp
//
//  Created by 김동현 on 5/16/26.
//

import SwiftUI
import Compound

struct SwiftUICounterView: View {
    @StateObject private var compound = SwiftUICounterCompound()

    var body: some View {
        VStack(spacing: 20) {
            Text("Compound Counter")
                .font(.title2.weight(.semibold))

            Text("\(compound.state.count)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 12) {
                Button("Increase") {
                    compound.send(.increaseButtonTapped)
                }
                .buttonStyle(.borderedProminent)

                Button("Decrease") {
                    compound.send(.decreaseButtonTapped)
                }
                .buttonStyle(.bordered)

                Button("Reset") {
                    compound.send(.resetButtonTapped)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .navigationTitle("SwiftUI Counter")
        .navigationBarTitleDisplayMode(.inline)
    }
}
