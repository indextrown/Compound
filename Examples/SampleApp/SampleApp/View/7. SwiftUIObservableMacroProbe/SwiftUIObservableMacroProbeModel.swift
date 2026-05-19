//
//  SwiftUIObservableMacroProbeModel.swift
//  SampleApp
//
//  Created by 김동현 on 5/19/26.
//

#if canImport(Observation)
import Observation

@available(iOS 17.0, *)
@Observable
final class SwiftUIObservableMacroProbeModel {
    var count: Int = 0
    var message: String = "Ready"
    var isHighlighted: Bool = false

    func increaseCount() {
        count += 1
    }

    func changeMessage() {
        message = message == "Ready" ? "Updated" : "Ready"
    }

    func toggleHighlight() {
        isHighlighted.toggle()
    }

    func reset() {
        count = 0
        message = "Ready"
        isHighlighted = false
    }
}
#endif
