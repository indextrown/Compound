//
//  UIViewController+ToSwiftUI.swift
//  SampleApp
//
//  Created by 김동현 on 5/16/26.
//

import SwiftUI
import UIKit

struct UIViewControllerRepresentation<ViewController: UIViewController>: UIViewControllerRepresentable {
    private let makeViewController: (_ context: Context) -> ViewController
    private let updateViewController: (_ viewController: ViewController, _ context: Context) -> Void

    init(
        makeViewController: @escaping (_ context: Context) -> ViewController,
        updateViewController: @escaping (_ viewController: ViewController, _ context: Context) -> Void = { _, _ in }
    ) {
        self.makeViewController = makeViewController
        self.updateViewController = updateViewController
    }

    func makeUIViewController(context: Context) -> ViewController {
        makeViewController(context)
    }

    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        updateViewController(uiViewController, context)
    }
}
