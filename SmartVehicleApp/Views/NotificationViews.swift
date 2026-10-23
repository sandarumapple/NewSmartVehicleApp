import SwiftUI
import UserNotifications

struct NotificationCenterView: View {
    @EnvironmentObject private var store: AppStore
    @State private var deliveredNotifications: [UNNotification] = []
    private var alerts: [AlertItem] {
        var list: [AlertItem] = []
        for car in store.vehicles where car.distanceToService <= 2500 {
            list.append(
                AlertItem(
                    id: "vehicle-\(car.id.uuidString)",
                    title: "Service coming up",
                    message:
                        "\(car.title) is due in \(car.distanceToService.formatted()) km or on \(car.nextServiceDate.shortDate).",
                    symbol: "wrench.and.screwdriver.fill", tint: .orange,
                    destination: .maintenance(car.id))
            )
        }
        for document in store.documents where document.status != "Valid" {
            list.append(
                AlertItem(
                    id: "document-\(document.id.uuidString)",
                    title: document.status == "Expired"
                        ? "Document expired" : "Document expiring soon",
                    message:
                        "\(document.registration) · \(document.type) · \(document.expiryDate.shortDate)",
                    symbol: document.status == "Expired"
                        ? "exclamationmark.triangle.fill" : "doc.badge.clock",
                    tint: document.status == "Expired" ? .red : .orange,
                    destination: .document(document)))
        }
        return list
    }
    var body: some View {
        List {
            if let error = store.communityNotificationError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            if !store.communityNotifications.isEmpty {
                Section("Community activity") {
                    ForEach(store.communityNotifications) { notification in
                        NavigationLink {
                            CommunityNotificationDestinationView(notification: notification)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(
                                    systemName: notification.type == "comment"
                                        ? "bubble.left.fill" : "heart.fill"
                                )
                                .foregroundStyle(notification.type == "comment" ? .blue : .red)
                                .frame(width: 38, height: 38)
                                .background(
                                    (notification.type == "comment" ? Color.blue : Color.red)
                                        .opacity(0.1),
                                    in: Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(notification.title).font(.subheadline.bold())
                                        if !notification.isRead {
                                            Circle().fill(Color.appAccent).frame(width: 7, height: 7)
                                        }
                                    }
                                    Text(notification.message)
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(notification.createdAt.formatted(.relative(presentation: .named)))
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            if !deliveredNotifications.isEmpty {
                Section("Recent notifications") {
                    ForEach(deliveredNotifications, id: \.request.identifier) { notification in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notification.request.content.title).font(.subheadline.bold())
                            Text(notification.request.content.body)
                                .font(.caption).foregroundStyle(.secondary)
                            Text(notification.date.shortDate)
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            if alerts.isEmpty && deliveredNotifications.isEmpty
                && store.communityNotifications.isEmpty
            {
                EmptyStateView(
                    symbol: "bell.slash", title: "You're all caught up",
                    message: "Important vehicle updates will appear here.")
            }
            if !alerts.isEmpty {
                Section("Vehicle alerts") {
                    ForEach(alerts) { alert in
                        NavigationLink {
                            AlertDetailView(alert: alert)
                        } label: {
                            HStack(spacing: 13) {
                                Image(systemName: alert.symbol).foregroundStyle(alert.tint)
                                    .frame(width: 42, height: 42)
                                    .background(
                                        alert.tint.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 13))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(alert.title).font(.subheadline.bold())
                                    Text(alert.message).font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            Section("Delivery") {
                Label("Local reminders", systemImage: "bell.badge").foregroundStyle(.secondary)
                Text(
                    "Maintenance, document, and vehicle dates schedule reminders on this device. Remote push messages are delivered separately through Firebase."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshDeliveredNotifications() }
        .refreshable { refreshDeliveredNotifications() }
    }

    private func refreshDeliveredNotifications() {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            DispatchQueue.main.async {
                deliveredNotifications = notifications.filter { notification in
                    let type = notification.request.content.userInfo["type"] as? String
                    return type != "like" && type != "comment"
                }
                .sorted { $0.date > $1.date }
            }
        }
    }
}

private struct CommunityNotificationDestinationView: View {
    @EnvironmentObject private var store: AppStore
    let notification: CommunityNotification

    var body: some View {
        Group {
            if let post = store.posts.first(where: { $0.id == notification.postID }) {
                PostDetailView(post: post)
            } else {
                EmptyStateView(
                    symbol: "text.bubble", title: "Post unavailable",
                    message: "This community post may have been removed.")
                .navigationTitle("Community activity")
            }
        }
        .onAppear { store.markCommunityNotificationRead(notification) }
    }
}

struct AlertItem: Identifiable {
    var id: String
    var title: String
    var message: String
    var symbol: String
    var tint: Color
    var destination: AlertDestination
}
enum AlertDestination {
    case maintenance(UUID)
    case document(VehicleDocument)
}
struct AlertDetailView: View {
    var alert: AlertItem
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: alert.symbol).font(.system(size: 30)).foregroundStyle(alert.tint)
                .frame(width: 78, height: 78).background(alert.tint.opacity(0.1), in: Circle())
            Text(alert.title).font(.title2.bold())
            Text(alert.message).multilineTextAlignment(.center).foregroundStyle(.secondary)
            switch alert.destination {
            case .maintenance(let vehicleID):
                NavigationLink("View maintenance") { MaintenanceListView(vehicleID: vehicleID) }
                    .buttonStyle(PrimaryButtonStyle()).padding(.top, 8)
            case .document(let document):
                NavigationLink("View document") { DocumentDetailView(document: document) }
                    .buttonStyle(PrimaryButtonStyle()).padding(.top, 8)
            }
        }
        .padding(28).navigationTitle("Alert").navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL

    private var permissionMessage: String {
        switch store.notificationPermissionState {
        case .notDetermined: "Permission has not been requested on this device."
        case .denied: "Notifications are blocked in iOS Settings."
        case .authorized: "Notifications are allowed on this device."
        case .provisional: "Notifications are delivered quietly on this device."
        case .ephemeral: "Temporary notification permission is active."
        }
    }

    private var remotePushMessage: String {
        if !store.isFirebaseConfigured {
            return "Remote push requires Firebase. Local reminders still work."
        }
        if !store.notificationsEnabled { return "Remote push is off in app settings." }
        if !store.notificationPermissionState.allowsAlerts {
            return "Allow notifications in iOS Settings to receive remote push."
        }
        return store.isPushRegistered
            ? "This device is registered for Firebase push messages."
            : "This device is waiting for APNs and Firebase registration."
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: {
                store.notificationsEnabled
                    && store.notificationPermissionState != .denied
            },
            set: { enabled in
                if !enabled {
                    store.notificationsEnabled = false
                    store.notificationPreferencesChanged()
                    return
                }
                if store.notificationPermissionState == .denied {
                    store.notificationsEnabled = false
                    store.notificationPreferencesChanged()
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                    return
                }
                store.notificationsEnabled = true
                store.notificationPreferencesChanged()
                requestPermission()
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("Allow notifications", isOn: notificationsBinding)
                    .accessibilityHint(
                        "Controls local reminders and Firebase push notifications for this account"
                    )
                Label(
                    notificationsBinding.wrappedValue ? "Notifications are active" : "Notifications are off",
                    systemImage: notificationsBinding.wrappedValue
                        ? "bell.badge.fill" : "bell.slash.fill"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(
                    notificationsBinding.wrappedValue ? Color.appSuccess : .secondary)
            } footer: {
                Text(
                    "This controls local reminders and remote push registration for this account."
                )
            }
            Section("Alert types") {
                Toggle("Maintenance reminders", isOn: $store.maintenanceNotifications)
                    .disabled(!store.notificationsEnabled)
                Toggle("Document expiry", isOn: $store.documentNotifications)
                    .disabled(!store.notificationsEnabled)
                Toggle("Important vehicle alerts", isOn: $store.vehicleNotifications)
                    .disabled(!store.notificationsEnabled)
            }
            Section("iOS permission") {
                Text(permissionMessage).font(.caption).foregroundStyle(.secondary)
                if store.notificationPermissionState == .denied {
                    Button("Open iOS Settings") {
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    }
                } else if store.notificationPermissionState == .notDetermined {
                    Button("Request permission") { requestPermission() }
                }
            }
            Section("Remote push") {
                Text(remotePushMessage)
                .font(.caption).foregroundStyle(.secondary)
                if let installationID = store.pushInstallationID {
                    Button {
                        UIPasteboard.general.string = installationID
                    } label: {
                        Label("Copy Firebase installation ID", systemImage: "doc.on.doc")
                    }
                }
                if let error = store.pushRegistrationError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
        .onAppear { store.refreshNotificationPermission() }
        .onChange(of: store.maintenanceNotifications) { _, _ in store.notificationPreferencesChanged() }
        .onChange(of: store.documentNotifications) { _, _ in store.notificationPreferencesChanged() }
        .onChange(of: store.vehicleNotifications) { _, _ in store.notificationPreferencesChanged() }
    }
    private func requestPermission() {
        store.requestNotificationPermission { state in
            if !state.allowsAlerts {
                store.notificationsEnabled = false
                store.notificationPreferencesChanged()
            }
        }
    }
}
