//
//  ParticipateView.swift
//  Naviari_IOS
//
//  Collects basic entrant info and participation code for a race start.
//

import SwiftUI

struct ParticipateView: View {
    let raceSummary: RaceSummary
    let start: RaceStart

    @State private var name = ""
    @State private var sailNumber = ""
    @State private var ratingValue = ""
    @State private var descriptionText = ""
    @State private var clubText = ""
    @State private var selectedColor = Color.blue
    @State private var codePrefix = ""
    @State private var codeSuffix = ""
    @State private var showParticipationInfo = false

    var body: some View {
        ScreenContainer(
            showBack: true,
            title: Text("participate_title"),
            trailing: AnyView(
                Button(action: { showParticipationInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            )
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(start.name ?? raceSummary.race.nameOrFallback)
                        .font(.headline)

                    inputField(titleKey: "participate_name_label", text: $name, placeholder: "participate_name_placeholder")

                    HStack(alignment: .top, spacing: 16) {
                        inputField(titleKey: "participate_sail_label", text: $sailNumber, placeholder: "participate_sail_placeholder")
                        decimalInputField(titleKey: "participate_rating_label", text: $ratingValue, placeholder: "participate_rating_placeholder")
                    }

                    HStack(alignment: .top, spacing: 16) {
                        inputField(titleKey: "participate_club_label", text: $clubText, placeholder: "participate_club_placeholder")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("participate_color_label")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            ColorPicker("participate_color_label", selection: $selectedColor)
                                .labelsHidden()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    inputField(titleKey: "participate_description_label", text: $descriptionText, placeholder: "participate_description_placeholder")

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("participate_code_label")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            TextField("participate_code_prefix", text: $codePrefix)
                                .textFieldStyle(.roundedBorder)
                            Text("-")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            TextField("participate_code_suffix", text: $codeSuffix)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    VStack(spacing: 12) {
                        Button(action: {}) {
                            Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.white)
                                .padding(32)
                                .background(Circle().fill(Color.accentColor))
                        }

                        Text("participate_cta_hint")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showParticipationInfo) {
            InfoHelpView(titleKey: "participate_info_title", bodyKey: "participate_info_body")
        }
    }

    private func inputField(titleKey: LocalizedStringKey, text: Binding<String>, placeholder: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(titleKey)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func decimalInputField(titleKey: LocalizedStringKey, text: Binding<String>, placeholder: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titleKey)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.none)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InfoHelpView: View {
    let titleKey: LocalizedStringKey
    let bodyKey: LocalizedStringKey
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(bodyKey)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(titleKey)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("close_button") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.4), .medium])
    }
}
