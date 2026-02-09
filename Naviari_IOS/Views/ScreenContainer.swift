//
//  ScreenContainer.swift
//  Naviari_IOS
//
//  Provides a reusable header with optional back button for stack screens.
//

import SwiftUI

struct ScreenContainer<Content: View>: View {
    var showBack: Bool
    var title: Text
    var trailing: AnyView?
    @ViewBuilder var content: () -> Content

    init(
        showBack: Bool,
        title: Text,
        trailing: AnyView? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showBack = showBack
        self.title = title
        self.trailing = trailing
        self.content = content
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    if showBack {
                        Button(action: { dismiss() }) {
                            Label("back_button", systemImage: "chevron.left")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    Spacer()
                    if let trailing {
                        trailing
                    }
                }

                title
                    .font(.headline)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationBarBackButtonHidden(true)
    }
}
