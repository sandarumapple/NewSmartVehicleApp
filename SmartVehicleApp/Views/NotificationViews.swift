import SwiftUI
import UserNotifications

struct NotificationCenterView: View {
    @EnvironmentObject private var store: AppStore
    @State private var deliveredNotifications: [UNNotification] = []
    private var alerts: [AlertItem] {
        var list: [AlertItem] = []
        if let car = store.selectedVehicle, car.distanceToService <= 2500 {
            list.append(
                AlertItem(
                    title: "Service coming up",
                    message:
                        "Your next service is due in \(car.distanceToService.formatted()) km or on \(car.nextServiceDate.shortDate).",
                    symbol: "wrench.and.screwdriver.fill", tint: .orange, destination: .maintenance)
            )
        }
        for document in store.selectedDocuments where document.status != "Valid" {
            list.append(
                AlertItem(
                    title: document.status == "Expired"
                        ? "Document expired" : "Document expiring soon",
                    message: "\(document.type) · \(document.expiryDate.shortDate)",
                    symbol: document.status == "Expired"
                        ? "exclamationmark.triangle.fill" : "doc.badge.clock",
                    tint: document.status == "Expired" ? .red : .orange,
                    destination: .document(document)))
        }
        return list
    }
    var body: some View {
        List {
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
            if alerts.isEmpty && deliveredNotifications.isEmpty {
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
                deliveredNotifications = notifications.sorted { $0.date > $1.date }
            }
        }
    }
}

struct AlertItem: Identifiable {
    var id = UUID()
    var title: String
    var message: String
    var symbol: String
    var tint: Color
    var destination: AlertDestination
}
enum AlertDestination {
    case maintenance
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
            case .maintenance:
                NavigationLink("View maintenance") { MaintenanceListView() }
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

    var body: some View {
        Form {
            Section {
                Toggle("Allow notifications", isOn: $store.notificationsEnabled)
                    .onChange(of: store.notificationsEnabled) { _, enabled in
                        store.notificationPreferencesChanged()
                        if enabled { requestPermission() }
                    }
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
        store.requestNotificationPermission { _ in }
    }
}
