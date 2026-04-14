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

enum UserNotificationContent {
    case plain(String)
    case markdown(String)
    case liveMarkdown((Date) -> String)
}

struct UserNotificationItem: Identifiable {
    let id = UUID()
    let content: UserNotificationContent
    let severity: UserNotificationSeverity
    let autoHideDuration: TimeInterval?
}

@MainActor
final class UserNotifications: ObservableObject {
    @Published private(set) var current: UserNotificationItem?

    private var dismissTask: Task<Void, Never>?

    @discardableResult
    func show(message: String, severity: UserNotificationSeverity = .info) -> UUID {
        show(
            item: UserNotificationItem(
                content: .plain(message),
                severity: severity,
                autoHideDuration: severity.autoHideDuration
            )
        )
    }

    @discardableResult
    func show(markdownMessage: String, severity: UserNotificationSeverity = .info) -> UUID {
        show(
            item: UserNotificationItem(
                content: .markdown(markdownMessage),
                severity: severity,
                autoHideDuration: severity.autoHideDuration
            )
        )
    }

    @discardableResult
    func showLiveMarkdown(
        severity: UserNotificationSeverity = .info,
        autoHideDuration: TimeInterval? = nil,
        messageBuilder: @escaping (Date) -> String
    ) -> UUID {
        show(
            item: UserNotificationItem(
                content: .liveMarkdown(messageBuilder),
                severity: severity,
                autoHideDuration: autoHideDuration ?? severity.autoHideDuration
            )
        )
    }

    func dismiss(id: UUID) {
        guard current?.id == id else { return }
        dismiss()
    }

    @discardableResult
    private func show(item: UserNotificationItem) -> UUID {
        dismissTask?.cancel()

        withAnimation(.easeInOut(duration: 0.2)) {
            current = item
        }

        guard let autoHideDuration = item.autoHideDuration else {
            return item.id
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(autoHideDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dismiss(id: item.id)
        }

        return item.id
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            current = nil
        }
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

            notificationMessageView(for: notification)

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
        .tint(Color.white)
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

    @ViewBuilder
    private func notificationMessageView(for notification: UserNotificationItem) -> some View {
        switch notification.content {
        case let .plain(message):
            Text(message)
                .font(AppFont.textStyle(.subheadline, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)

        case let .markdown(message):
            Text(markdownAttributedString(from: message))
                .font(AppFont.textStyle(.subheadline, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)

        case let .liveMarkdown(messageBuilder):
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(markdownAttributedString(from: messageBuilder(context.date)))
                    .font(AppFont.textStyle(.subheadline, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private func markdownAttributedString(from markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }
}
