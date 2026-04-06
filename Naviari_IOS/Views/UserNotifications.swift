import SwiftUI

enum UserNotificationSeverity: Equatable {
    case success
    case info
    case warning
    case error

    var autoHideDuration: TimeInterval? {
        switch self {
        case .success:
            return 3
        case .info:
            return 5
        case .warning:
            return 10
        case .error:
            return nil
        }
    }

    var iconName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .success:
            return Theme.Colors.statusGreen
        case .info:
            return Theme.Colors.brandPrimary
        case .warning:
            return Theme.Colors.statusYellow
        case .error:
            return Theme.Colors.statusRed
        }
    }
}

struct UserNotificationItem: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let severity: UserNotificationSeverity
}

@MainActor
final class UserNotifications: ObservableObject {
    @Published private(set) var current: UserNotificationItem?

    private var dismissTask: Task<Void, Never>?

    func show(message: String, severity: UserNotificationSeverity = .info) {
        dismissTask?.cancel()

        let item = UserNotificationItem(message: message, severity: severity)
        withAnimation(.easeInOut(duration: 0.2)) {
            current = item
        }

        guard let autoHideDuration = severity.autoHideDuration else {
            return
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(autoHideDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dismiss(id: item.id)
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            current = nil
        }
    }

    private func dismiss(id: UUID) {
        guard current?.id == id else { return }
        dismiss()
    }
}

struct UserNotificationsOverlay: View {
    @EnvironmentObject private var userNotifications: UserNotifications

    var body: some View {
        VStack(spacing: 0) {
            if let notification = userNotifications.current {
                banner(for: notification)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func banner(for notification: UserNotificationItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: notification.severity.iconName)
                .font(.system(size: 18, weight: .semibold))

            Text(notification.message)
                .font(AppFont.textStyle(.subheadline, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)

            Button(action: userNotifications.dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("user_notifications_close"))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: 560, alignment: .leading)
        .background(notification.severity.tintColor)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.materialCard, style: .continuous))
        .shadow(
            color: Color.black.opacity(Theme.Effects.floatingStatusShadowOpacity * 0.5),
            radius: Theme.Effects.floatingStatusShadowRadius,
            x: 0,
            y: Theme.Effects.floatingStatusShadowYOffset
        )
    }
}
