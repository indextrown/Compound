//
//  ListView.swift
//  SampleApp
//
//  Created by 김동현 on 5/16/26.
//

import SwiftUI

struct ListView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    SwiftUICounterView()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SwiftUI Counter")
                            .font(.headline)
                        Text("Compound state를 SwiftUI에서 직접 관찰합니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    UIViewControllerRepresentation { _ in
                        UIKitCounterViewController()
                    }
                    .ignoresSafeArea(edges: .bottom)
                        .navigationTitle("UIKit Counter")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("UIKit Counter")
                            .font(.headline)
                        Text("같은 Compound를 UIKit ViewController에서 Combine으로 구독합니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    SwiftUIConcatView()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SwiftUI Concat Refresh")
                            .font(.headline)
                        Text("setLoading(true) -> 결과 reaction -> setLoading(false)를 순차 반영합니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    UIViewControllerRepresentation { _ in
                        UIKitConcatViewController()
                    }
                    .ignoresSafeArea(edges: .bottom)
                        .navigationTitle("UIKit Concat Refresh")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("UIKit Concat Refresh")
                            .font(.headline)
                        Text("같은 concat reaction sequence를 UIKit ViewController에서 Combine으로 구독합니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    SwiftUICounterNoMacroView()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SwiftUI Counter No Macro")
                            .font(.headline)
                        Text("매크로 없이 CompoundType과 _compoundRuntime을 직접 선언하는 버전입니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                NavigationLink {
                    SwiftUIStateChangeProbeView()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SwiftUI State Change Probe")
                            .font(.headline)
                        Text("state 일부 속성만 바꿀 때 어떤 SwiftUI 뷰가 다시 계산되는지 콘솔 로그로 확인합니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Compound Examples")
        }
    }
}

#Preview {
    ListView()
}
