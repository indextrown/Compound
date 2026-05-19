//
//  SwiftUICounterNoMacroView.swift
//  SampleApp
//
//  Created by 김동현 on 5/18/26.
//

import Compound
import SwiftUI

struct SwiftUICounterNoMacroView: View {
    @State private var compound = SwiftUICounterNoMacroCompound()

    var body: some View {
        VStack(spacing: 20) {
            Text("Compound Counter (No Macro)")
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
        .navigationTitle("SwiftUI Counter No Macro")
        .navigationBarTitleDisplayMode(.inline)
    }
}
