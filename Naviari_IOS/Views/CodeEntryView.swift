import SwiftUI

struct CodeEntryView: View {
    let titleKey: String
    let messageKey: String
    let verifyButtonKey: String
    let cancelButtonKey: String
    let accentColor: Color
    let onVerify: (String) async throws -> String
    let onSuccess: (String) -> Void
    let onCancel: () -> Void

    @State private var prefix = ""
    @State private var suffix = ""
    @State private var isValidating = false
    @State private var error: String?
    @State private var attempts = 0

    private let maxAttempts = 5
    private let inputFont = AppFont.fixed(21)

    init(
        titleKey: String,
        messageKey: String,
        verifyButtonKey: String,
        cancelButtonKey: String,
        accentColor: Color = AppUI.brandPrimary,
        onVerify: @escaping (String) async throws -> String,
        onSuccess: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.titleKey = titleKey
        self.messageKey = messageKey
        self.verifyButtonKey = verifyButtonKey
        self.cancelButtonKey = cancelButtonKey
        self.accentColor = accentColor
        self.onVerify = onVerify
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(LocalizedStringKey(messageKey))
                    .font(AppFont.textStyle(.subheadline))
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("participate_code_prefix", text: $prefix)
                        .font(inputFont)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("code_entry_prefix_field")
                    Text("-")
                        .font(AppFont.textStyle(.title2))
                        .foregroundStyle(.secondary)
                    TextField("participate_code_suffix", text: $suffix)
                        .font(inputFont)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("code_entry_suffix_field")
                }

                Text(error ?? " ")
                    .foregroundStyle(Theme.Colors.error)
                    .font(AppFont.textStyle(.footnote))
                    .opacity(error == nil ? 0 : 1)
                    .accessibilityIdentifier("code_entry_error_label")

                Text(attemptsLabelText)
                    .font(AppFont.textStyle(.footnote))
                    .foregroundStyle(hasAttemptsRemaining ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.Colors.error))
                    .opacity(attempts > 0 ? 1 : 0)
                    .accessibilityIdentifier("code_entry_attempts_label")

                Button {
                    Task { await verifyCode() }
                } label: {
                    if isValidating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(LocalizedStringKey(verifyButtonKey))
                            .font(AppUI.buttonFont)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .disabled(isValidating || !hasAttemptsRemaining || code == nil)
                .accessibilityIdentifier("code_entry_verify_button")

                Button(LocalizedStringKey(cancelButtonKey)) {
                    onCancel()
                }
                .font(AppUI.buttonFont)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("code_entry_cancel_button")

                Spacer()
            }
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("code_entry_modal")
            .navigationTitle(Text(LocalizedStringKey(titleKey)))
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
    }

    private var code: String? {
        let trimmedPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSuffix = suffix.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedPrefix.isEmpty, !trimmedSuffix.isEmpty else {
            return nil
        }

        return "\(trimmedPrefix)-\(trimmedSuffix)"
    }

    private var attemptsRemaining: Int {
        max(0, maxAttempts - attempts)
    }

    private var hasAttemptsRemaining: Bool {
        attemptsRemaining > 0
    }

    private var attemptsLabelText: String {
        if hasAttemptsRemaining {
            return String(
                format: NSLocalizedString("participate_code_attempts_remaining", comment: ""),
                attemptsRemaining
            )
        }

        return NSLocalizedString("participate_code_attempts_exhausted", comment: "")
    }

    private func verifyCode() async {
        guard hasAttemptsRemaining else { return }
        guard !isValidating else { return }
        guard let code else { return }

        isValidating = true
        defer { isValidating = false }

        do {
            let token = try await onVerify(code)
            prefix = ""
            suffix = ""
            error = nil
            onSuccess(token)
        } catch {
            attempts += 1
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    CodeEntryView(
        titleKey: "participate_code_modal_title",
        messageKey: "participate_code_modal_message",
        verifyButtonKey: "participate_code_verify_button",
        cancelButtonKey: "back_button",
        onVerify: { _ in "preview-token" },
        onSuccess: { _ in },
        onCancel: {}
    )
}