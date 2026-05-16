//
//  UIKitCounterViewController.swift
//  SampleApp
//
//  Created by 김동현 on 5/16/26.
//

import Combine
import Compound
import UIKit

final class UIKitCounterViewController: UIViewController {
    private let compound = UIKitCounterCompound()
    private var cancellables = Set<AnyCancellable>()

    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let increaseButton = UIButton(type: .system)
    private let decreaseButton = UIButton(type: .system)
    private let resetButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        configureUI()
        bindState()
    }

    private func configureUI() {
        titleLabel.text = "Compound Counter"
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textAlignment = .center

        let roundedDescriptor = UIFont.systemFont(ofSize: 48, weight: .bold)
            .fontDescriptor
            .withDesign(.rounded) ?? UIFont.systemFont(ofSize: 48, weight: .bold).fontDescriptor
        countLabel.textAlignment = .center
        countLabel.font = UIFont(descriptor: roundedDescriptor, size: 48)
        countLabel.text = "\(compound.state.count)"
        countLabel.adjustsFontForContentSizeCategory = true

        var prominentConfiguration = UIButton.Configuration.borderedProminent()
        prominentConfiguration.title = "Increase"
        prominentConfiguration.cornerStyle = .medium
        prominentConfiguration.buttonSize = .large
        increaseButton.configuration = prominentConfiguration
        increaseButton.addTarget(self, action: #selector(didTapIncrease), for: .touchUpInside)

        var borderedConfiguration = UIButton.Configuration.bordered()
        borderedConfiguration.title = "Decrease"
        borderedConfiguration.cornerStyle = .medium
        borderedConfiguration.buttonSize = .large
        decreaseButton.configuration = borderedConfiguration
        decreaseButton.addTarget(self, action: #selector(didTapDecrease), for: .touchUpInside)

        var resetConfiguration = UIButton.Configuration.bordered()
        resetConfiguration.title = "Reset"
        resetConfiguration.cornerStyle = .medium
        resetConfiguration.buttonSize = .large
        resetButton.configuration = resetConfiguration
        resetButton.addTarget(self, action: #selector(didTapReset), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [increaseButton, decreaseButton, resetButton])
        buttonStack.axis = .horizontal
        buttonStack.alignment = .fill
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 12

        let stack = UIStackView(arrangedSubviews: [titleLabel, countLabel, buttonStack])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func bindState() {
        compound.$state
            .map(\.count)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.countLabel.text = "\(count)"
            }
            .store(in: &cancellables)
    }

    @objc
    private func didTapIncrease() {
        compound.send(.increaseButtonTapped)
    }

    @objc
    private func didTapDecrease() {
        compound.send(.decreaseButtonTapped)
    }

    @objc
    private func didTapReset() {
        compound.send(.resetButtonTapped)
    }
}
