//
//  UIKitConcatViewController.swift
//  SampleApp
//
//  Created by 김동현 on 5/16/26.
//

import Combine
import Compound
import UIKit

final class UIKitConcatViewController: UIViewController {
    private let compound = UIKitConcatCompound()
    private var cancellables = Set<AnyCancellable>()

    private let titleLabel = UILabel()
    private let phaseLabel = UILabel()
    private let countLabel = UILabel()
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let refreshButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        configureUI()
        bindState()
        render(state: compound.state)
    }

    private func configureUI() {
        titleLabel.text = "Concat Refresh"
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textAlignment = .center

        phaseLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        phaseLabel.textAlignment = .center

        let roundedDescriptor = UIFont.systemFont(ofSize: 28, weight: .bold)
            .fontDescriptor
            .withDesign(.rounded) ?? UIFont.systemFont(ofSize: 28, weight: .bold).fontDescriptor
        countLabel.textAlignment = .center
        countLabel.font = UIFont(descriptor: roundedDescriptor, size: 28)
        countLabel.adjustsFontForContentSizeCategory = true

        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center

        activityIndicator.hidesWhenStopped = true

        var refreshConfiguration = UIButton.Configuration.borderedProminent()
        refreshConfiguration.title = "Refresh"
        refreshConfiguration.cornerStyle = .medium
        refreshConfiguration.buttonSize = .large
        refreshButton.configuration = refreshConfiguration
        refreshButton.addTarget(self, action: #selector(didTapRefresh), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            phaseLabel,
            countLabel,
            statusLabel,
            activityIndicator,
            refreshButton
        ])
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
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.render(state: state)
            }
            .store(in: &cancellables)
    }

    private func render(state: UIKitConcatCompound.State) {
        phaseLabel.text = state.isLoading ? "Loading..." : "Idle"
        phaseLabel.textColor = state.isLoading ? .systemOrange : .secondaryLabel
        countLabel.text = "Refresh Count: \(state.refreshCount)"
        statusLabel.text = state.statusMessage
        refreshButton.isEnabled = !state.isLoading

        if state.isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    @objc
    private func didTapRefresh() {
        compound.send(.refreshButtonTapped)
    }
}
