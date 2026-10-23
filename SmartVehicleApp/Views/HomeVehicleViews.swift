import Charts
import PhotosUI
import SwiftUI
import UIKit

extension Vehicle {
    fileprivate var hasToyotaRaizeArtwork: Bool {
        model.localizedCaseInsensitiveContains("raize")
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var selectedTab: Int
    @State private var showNotifications = false
    @State private var showSwitcher = false
    @State private var showFuel = false
    @State private var showExpense = false
    @State private var showMaintenance = false
    @State private var showScanner = false
    @State private var showVehicleDetails = false
    var vehicle: Vehicle? { store.selectedVehicle }
    private var viewModel: DashboardViewModel {
        DashboardViewModel(
            vehicle: vehicle, maintenance: store.maintenance,
            fuelRecords: store.fuelRecords, expenses: store.expenses,
            documents: store.documents, now: Date())
    }
    private var attentionDocuments: [VehicleDocument] { viewModel.attentionDocuments }
    private var serviceNeedsAttention: Bool { viewModel.serviceNeedsAttention }
    private var recentActivity: [DashboardActivity] {
        let services = store.selectedVehicleRecords.map {
            DashboardActivity(
                id: $0.id, date: $0.date, title: $0.type,
                subtitle: "\($0.date.shortDate) · \($0.mileage.formatted()) km",
                amount: money($0.cost), symbol: "wrench.fill", tint: .orange)
        }
        let fuel = store.selectedFuelRecords.map {
            DashboardActivity(
                id: $0.id, date: $0.date, title: "Fuel refill",
                subtitle: "\($0.date.shortDate) · \($0.liters.formatted()) L",
                amount: money($0.total), symbol: "fuelpump.fill", tint: .appAccent)
        }
        let expenses = store.selectedExpenses.map {
            DashboardActivity(
                id: $0.id, date: $0.date, title: $0.title,
                subtitle: "\($0.date.shortDate) · \($0.category)",
                amount: money($0.amount), symbol: "creditcard.fill", tint: .purple)
        }
        return (services + fuel + expenses).sorted { $0.date > $1.date }
    }
    private var relatedCommunityPosts: [CommunityPost] {
        guard let vehicle else { return [] }
        return Array(
            CommunityFeedViewModel.visiblePosts(
                store.posts, category: "All posts", vehicleQuery: vehicle.title,
                authorFilter: .otherDrivers, currentUserID: store.currentUserID
            ).prefix(2))
    }
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dashboard").font(.title2.weight(.bold))
                        Text(
                            "Welcome back, \(store.userName.split(separator: " ").first ?? "there")."
                        )
                        .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button {
                        showNotifications = true
                    } label: {
                        Image(systemName: "bell")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(Color.appElevated, in: Circle())
                            .overlay(alignment: .topTrailing) {
                                if store.unreadNotificationCount > 0 {
                                    Text(store.unreadNotificationCount > 99
                                         ? "99+" : "\(store.unreadNotificationCount)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .frame(minWidth: 18, minHeight: 18)
                                        .background(.red, in: Capsule())
                                        .offset(x: 3, y: -3)
                                } else if serviceNeedsAttention || !attentionDocuments.isEmpty {
                                    Circle().fill(Color.red).frame(width: 8, height: 8)
                                        .padding(8)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Notifications")
                    .accessibilityValue("\(store.unreadNotificationCount) unread notifications")
                    Button {
                        selectedTab = 4
                    } label: {
                        ProfileAvatar(size: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Profile")
                }
                .padding(.horizontal, 16).padding(.top, 4)

                Button {
                    showSwitcher = true
                } label: {
                    HStack(spacing: 9) {
                        Circle().fill(Color.appSuccess).frame(width: 10, height: 10)
                            .shadow(color: Color.appSuccess.opacity(0.5), radius: 6)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(vehicle?.title ?? "Choose a vehicle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(
                                vehicle.map { "\($0.registration) · Active vehicle" }
                                    ?? "Add your first vehicle"
                            )
                            .font(.caption)
                            .foregroundStyle(Color.appAccent)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).frame(minHeight: 50)
                    .background(Color.appElevated, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .accessibilityLabel("Choose active vehicle")

                if let vehicle {
                    GarageHeroCard(
                        vehicle: vehicle,
                        onDetails: { showVehicleDetails = true }
                    )
                    .padding(.horizontal, 16)

                } else {
                    EmptyStateView(
                        symbol: "car.side", title: "Your garage starts here",
                        message:
                            "Add your vehicle to keep services, expenses and documents in one place.",
                        action: "Add a vehicle", onAction: { selectedTab = 1 })
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Quick actions")
                            .font(.headline).foregroundStyle(.primary)
                        Spacer()
                        Button("View all") { selectedTab = 2 }
                            .font(.subheadline.weight(.semibold))
                    }
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible()),
                            count:
                                horizontalSizeClass == .regular
                                && !dynamicTypeSize.isAccessibilitySize ? 4 : 2),
                        spacing: 10
                    ) {
                        QuickAction(symbol: "fuelpump.fill", label: "Add fuel", tint: .appAccent) {
                            showFuel = true
                        }
                        QuickAction(
                            symbol: "wrench.and.screwdriver.fill", label: "Maintenance",
                            tint: .appSuccess
                        ) {
                            showMaintenance = true
                        }
                        QuickAction(symbol: "creditcard.fill", label: "Add expense", tint: .purple) {
                            showExpense = true
                        }
                        QuickAction(symbol: "doc.viewfinder", label: "Scan document", tint: .mint) {
                            showScanner = true
                        }
                    }
                }
                .padding(.horizontal, 16)

                if !recentActivity.isEmpty {
                    NavigationLink {
                        AnalyticsView()
                    } label: {
                        DashboardAnalyticsCard(
                            activities: recentActivity
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .accessibilityHint("Opens full vehicle analytics")
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Needs your attention", systemImage: "bell.badge.fill")
                            .font(.appCardTitle)
                            .foregroundStyle(Color.appInk)
                        Spacer()
                        Button("See all") { selectedTab = 1 }.font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                    SurfaceCard {
                        VStack(spacing: 10) {
                            if serviceNeedsAttention, let vehicle {
                                NavigationLink {
                                    MaintenanceListView()
                                } label: {
                                    attentionRow(
                                        "Service due soon",
                                        "\(vehicle.distanceToService.formatted()) km remaining",
                                        tint: .red
                                    )
                                }
                            }
                            ForEach(Array(attentionDocuments.prefix(3))) { doc in
                                NavigationLink {
                                    DocumentDetailView(document: doc)
                                } label: {
                                    attentionRow(
                                        doc.type,
                                        doc.expiryDate < Date()
                                            ? "Expired \(doc.expiryDate.shortDate)"
                                            : "Expires \(doc.expiryDate.shortDate)",
                                        tint: doc.expiryDate < Date() ? .red : .appAccent
                                    )
                                }
                            }
                            if store.unreadNotificationCount > 0 {
                                Button {
                                    showNotifications = true
                                } label: {
                                    attentionRow(
                                        "Your updates",
                                        "\(store.unreadNotificationCount) unread \(store.unreadNotificationCount == 1 ? "notification" : "notifications")",
                                        tint: .purple
                                    )
                                }
                            }
                            if !serviceNeedsAttention && attentionDocuments.isEmpty
                                && store.unreadNotificationCount == 0
                            {
                                Label("All up to date", systemImage: "checkmark.seal.fill")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.appSuccess)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionHeading(title: "Recent activity")
                        Spacer()
                        Button("View all") { selectedTab = 2 }.font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                    SurfaceCard(padding: 14) {
                        VStack(spacing: 11) {
                            ForEach(Array(recentActivity.prefix(4))) { record in
                                RecordRow(
                                    symbol: record.symbol, tint: record.tint,
                                    title: record.title,
                                    subtitle: record.subtitle,
                                    amount: record.amount)
                            }
                            if recentActivity.isEmpty {
                                Text("No activity yet. Your records will appear here.")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                if let vehicle, !relatedCommunityPosts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SectionHeading(title: "For your \(vehicle.model)")
                            Spacer()
                            NavigationLink("View all") {
                                CommunityView(initialVehicleQuery: vehicle.title)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appAccent)
                        }
                        SurfaceCard(padding: 14) {
                            VStack(spacing: 0) {
                                ForEach(Array(relatedCommunityPosts.enumerated()), id: \.element.id) {
                                    index, post in
                                    NavigationLink {
                                        PostDetailView(post: post)
                                    } label: {
                                        relatedCommunityPostRow(post)
                                    }
                                    if index < relatedCommunityPosts.count - 1 {
                                        Divider().padding(.vertical, 11)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }
                Spacer(minLength: 18)
            }
            .padding(.top, 8)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appCanvas.ignoresSafeArea())
        .appNavigationBar(isRoot: true)
        .navigationDestination(isPresented: $showVehicleDetails) {
            if let vehicle { VehicleDetailView(vehicle: vehicle) }
        }
        .sheet(isPresented: $showSwitcher) {
            VehicleSwitcherSheet().presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNotifications) {
            NavigationStack {
                NotificationCenterView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showNotifications = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showFuel) { NavigationStack { AddFuelView() } }
        .sheet(isPresented: $showMaintenance) { NavigationStack { AddMaintenanceView() } }
        .sheet(isPresented: $showExpense) { NavigationStack { AddExpenseView() } }
        .fullScreenCover(isPresented: $showScanner) {
            NavigationStack { DocumentScannerFlow(startWithCamera: true) }
        }
    }
    private func attentionRow(_ title: String, _ subtitle: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Circle().fill(tint).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.appElevated, in: RoundedRectangle(cornerRadius: 8))
    }
    private func relatedCommunityPostRow(_ post: CommunityPost) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text(post.initials)
                .font(.caption.bold()).foregroundStyle(Color.appAccent)
                .frame(width: 36, height: 36).background(Color.appMint, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(post.author).font(.subheadline.weight(.semibold))
                    Spacer()
                    StatusBadge(text: post.category)
                }
                Text(post.text).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                HStack(spacing: 12) {
                    Label("\(post.likes)", systemImage: "heart")
                    Label("\(post.comments)", systemImage: "bubble.left")
                    Text(post.displayTime)
                }
                .font(.caption2).foregroundStyle(.tertiary)
            }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .contentShape(Rectangle())
    }

}

private struct DashboardActivity: Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let subtitle: String
    let amount: String
    let symbol: String
    let tint: Color
}

private struct DashboardSpendPoint: Identifiable {
    let month: Date
    let amount: Double
    let recordCount: Int

    var id: Date { month }
}

private struct DashboardAnalyticsCard: View {
    let activities: [DashboardActivity]

    private var latest: DashboardActivity? {
        activities.max { $0.date < $1.date }
    }

    private var monthlySpending: [DashboardSpendPoint] {
        let calendar = Calendar.current
        let currentMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()

        return (0..<6).reversed().compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: currentMonth),
                let interval = calendar.dateInterval(of: .month, for: month)
            else { return nil }

            let records = activities.filter { interval.contains($0.date) }
            return DashboardSpendPoint(
                month: month,
                amount: records.reduce(0) { $0 + numericAmount($1.amount) },
                recordCount: records.count
            )
        }
    }

    private var recentSpending: Double {
        monthlySpending.reduce(0) { $0 + $1.amount }
    }

    private var hasSpendingData: Bool { monthlySpending.contains { $0.amount > 0 } }

    private var spendingInsight: String {
        guard let current = monthlySpending.last else { return "Add an activity to see your trend." }
        guard current.amount > 0 else {
            return "No spending recorded in \(current.month.formatted(.dateTime.month(.wide)))."
        }
        guard monthlySpending.count > 1 else {
            return "\(current.recordCount) record\(current.recordCount == 1 ? "" : "s") this month."
        }

        let previous = monthlySpending[monthlySpending.count - 2]
        guard previous.amount > 0 else {
            return "\(current.recordCount) record\(current.recordCount == 1 ? "" : "s") this month."
        }

        let difference = current.amount - previous.amount
        let direction = difference >= 0 ? "up" : "down"
        return "\(direction.capitalized) \(compactMoney(abs(difference))) from last month."
    }

    var body: some View {
        SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Spending overview", systemImage: "chart.xyaxis.line")
                            .font(.appCardTitle)
                            .foregroundStyle(Color.appInk)
                        Text("Last 6 months · Tap for full analytics")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(compactMoney(recentSpending))
                            .font(.subheadline.bold()).monospacedDigit()
                        Text("TOTAL SPEND")
                            .font(.caption2.weight(.bold)).tracking(0.5)
                            .foregroundStyle(.secondary)
                    }
                }

                if hasSpendingData {
                    Chart(monthlySpending) { point in
                        AreaMark(
                            x: .value("Month", point.month),
                            y: .value("Spend", point.amount)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.appAccent.opacity(0.28), .clear],
                                startPoint: .top, endPoint: .bottom))
                        LineMark(
                            x: .value("Month", point.month),
                            y: .value("Spend", point.amount)
                        )
                        .foregroundStyle(Color.appAccent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        PointMark(
                            x: .value("Month", point.month),
                            y: .value("Spend", point.amount)
                        )
                        .foregroundStyle(Color.appAccent)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisGridLine().foregroundStyle(.clear)
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                                .font(.caption2)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(compactMoney(amount)).font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 150)
                } else {
                    ContentUnavailableView(
                        "No spending in the last 6 months",
                        systemImage: "chart.line.downtrend.xyaxis",
                        description: Text("Add fuel, maintenance, or expenses to start your trend."))
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                }

                Label(spendingInsight, systemImage: "calendar")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                if let latest {
                    HStack(spacing: 10) {
                        Image(systemName: latest.symbol)
                            .foregroundStyle(latest.tint)
                            .frame(width: 34, height: 34)
                            .background(latest.tint.opacity(0.11), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Latest: \(latest.title)")
                                .font(.caption.weight(.semibold)).lineLimit(1)
                            Text(latest.subtitle)
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Text(latest.amount).font(.caption.weight(.bold)).monospacedDigit()
                    }
                }
            }
        }
    }

    private func numericAmount(_ value: String) -> Double {
        Double(value.filter { $0.isNumber || $0 == "." }) ?? 0
    }
}

struct GarageHeroCard: View {
    @EnvironmentObject private var store: AppStore
    let vehicle: Vehicle
    var onDetails: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.15, blue: 0.29),
                        Color(red: 0.04, green: 0.07, blue: 0.12),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                if let photo = store.vehiclePhotos[vehicle.id] {
                    GeometryReader { geometry in
                        Image(uiImage: photo).resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .accessibilityHidden(true)
                } else if vehicle.hasToyotaRaizeArtwork {
                    Image("ToyotaRaize").resizable().scaledToFit()
                        .padding(.horizontal, 8).padding(.top, 10)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: vehicle.image).resizable().scaledToFit()
                        .foregroundStyle(Color.appAccent).padding(34)
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 28, y: 10)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 196)
            .overlay(alignment: .topLeading) {
                Label("ACTIVE VEHICLE", systemImage: "checkmark.shield.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white).padding(8)
                    .background(.black.opacity(0.65), in: Capsule())
                    .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                Text(vehicle.registration)
                    .font(.caption.monospaced())
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.65), in: Capsule())
                    .padding(12)
            }
            VStack(alignment: .leading, spacing: 14) {
                vehicleTitle
                odometer
                HStack(spacing: 8) {
                    Image(systemName: "wrench.fill")
                        .foregroundStyle(
                            vehicle.distanceToService == 0 ? Color.orange : Color.appAccent)
                    Text("Next service").foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(
                        vehicle.distanceToService == 0
                            ? "Due now" : "\(vehicle.distanceToService.formatted()) km away"
                    )
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                Button(action: onDetails) {
                    Label("View vehicle details", systemImage: "car.side.fill")
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Color.appCanvas)
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(18)
        }
        .background(Color.appCard).clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 16, y: 7)
        .buttonStyle(.plain)
    }

    private var vehicleTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(vehicle.title).font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("\(vehicle.year) · \(vehicle.fuel)")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var odometer: some View {
        HStack(spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.appAccent)
                .frame(width: 48, height: 48)
                .background(Color.appAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Current odometer")
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(vehicle.mileage.formatted()) km")
                    .font(.title2.weight(.bold)).monospacedDigit()
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .padding(.horizontal, 12)
        .background(Color.appElevated, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct QuickAction: View {
    let symbol: String
    let label: String
    let tint: Color
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint).frame(width: 40, height: 40)
                    .background(tint.opacity(0.1), in: Circle())
                Text(label).font(.caption.weight(.medium)).foregroundStyle(.primary)
                    .lineLimit(2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 80).padding(.vertical, 6)
            .background(Color.appElevated, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct VehicleSwitcherSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false
    var body: some View {
        NavigationStack {
            List {
                ForEach(store.vehicles) { vehicle in
                    Button {
                        store.selectedVehicleID = vehicle.id
                        store.persist()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Group {
                                if let photo = store.vehiclePhotos[vehicle.id] {
                                    Image(uiImage: photo).resizable().scaledToFill()
                                        .frame(width: 40, height: 40).clipped()
                                } else if vehicle.hasToyotaRaizeArtwork {
                                    Image("ToyotaRaize").resizable().scaledToFit()
                                        .padding(2)
                                } else {
                                    Image(systemName: vehicle.image)
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            .frame(width: 40, height: 40)
                            .background(Color.appMint, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(vehicle.title).foregroundStyle(.primary)
                                    .font(.subheadline.bold())
                                Text("\(vehicle.year) · \(vehicle.registration)").font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if vehicle.id == store.selectedVehicle?.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Choose vehicle")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add vehicle")
                }
            }
            .sheet(isPresented: $showAdd) { NavigationStack { AddVehicleView() } }
        }
    }
}

private enum GarageFilter: String, CaseIterable, Identifiable {
    case all = "All vehicles"
    case active = "Active"
    case due = "Service due"
    case electric = "Electric"
    var id: String { rawValue }
}

private func garageServiceDue(_ vehicle: Vehicle) -> Bool {
    let threshold = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    return vehicle.distanceToService <= 1_000 || vehicle.nextServiceDate <= threshold
}

struct VehicleListView: View {
    var isNavigationRoot = false
    @EnvironmentObject private var store: AppStore
    @State private var showAdd = false
    @State private var query = ""
    @State private var filter: GarageFilter = .all

    private var visibleVehicles: [Vehicle] {
        store.vehicles.filter { vehicle in
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .active: matchesFilter = vehicle.id == store.selectedVehicle?.id
            case .due: matchesFilter = garageServiceDue(vehicle)
            case .electric:
                matchesFilter = vehicle.fuel.localizedCaseInsensitiveContains("electric")
            }
            let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
            return matchesFilter
                && (text.isEmpty
                    || vehicle.title.localizedStandardContains(text)
                    || vehicle.registration.localizedStandardContains(text)
                    || vehicle.vin.localizedStandardContains(text))
        }
    }

    private var dueCount: Int { store.vehicles.filter(garageServiceDue).count }
    private var fleetMileage: Int { store.vehicles.reduce(0) { $0 + $1.mileage } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("My Garage").font(.largeTitle.weight(.bold))
                        Text(
                            "\(store.vehicles.count) vehicle\(store.vehicles.count == 1 ? "" : "s") in your garage"
                        )
                        .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button {
                        showAdd = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appCanvas)
                            .padding(.horizontal, 16).frame(minHeight: 44)
                            .background(Color.appAccent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add vehicle")
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search make, model, VIN, or plate", text: $query)
                        .font(.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.leading, 13).padding(.trailing, 4).frame(minHeight: 50)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(GarageFilter.allCases) { item in
                            Button {
                                filter = item
                            } label: {
                                Text(item.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(
                                        filter == item ? Color.appCanvas : Color.appMuted
                                    )
                                    .padding(.horizontal, 14).frame(minHeight: 44)
                                    .background(
                                        filter == item
                                            ? Color.appAccent
                                            : Color.appElevated,
                                        in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(filter == item ? .isSelected : [])
                        }
                    }
                }

                if store.vehicles.isEmpty {
                    EmptyStateView(
                        symbol: "car.side", title: "Your garage starts here",
                        message: "Add a vehicle to track mileage, services, and documents.",
                        action: "Add vehicle", onAction: { showAdd = true })
                } else if visibleVehicles.isEmpty {
                    EmptyStateView(
                        symbol: "magnifyingglass", title: "No vehicles found",
                        message: "Try another search or choose a different filter.")
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(visibleVehicles) { vehicle in
                            VehicleCard(
                                vehicle: vehicle,
                                isSelected: vehicle.id == store.selectedVehicle?.id,
                                onSelect: {
                                    store.selectedVehicleID = vehicle.id
                                    store.persist()
                                })
                        }
                    }
                }

                if !store.vehicles.isEmpty {
                    garageSummary
                }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 32)
            .frame(maxWidth: 920)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appCanvas.ignoresSafeArea()).appNavigationBar(isRoot: isNavigationRoot)
        .sheet(isPresented: $showAdd) { NavigationStack { AddVehicleView() } }
    }

    private var garageSummary: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill").foregroundStyle(Color.appAccent)
                Text("Garage summary").font(.appSectionTitle)
                Spacer()
                Text("\(store.vehicles.count) total")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                garageMetric("Vehicles", "\(store.vehicles.count)", "in your garage")
                garageMetric("Fleet mileage", "\(fleetMileage.formatted()) km", "recorded")
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { filter = .due }
                } label: {
                    garageMetric("Service due", "\(dueCount)", "tap to show due vehicles")
                }
                .buttonStyle(.plain)
                .disabled(dueCount == 0)
                .accessibilityHint("Filters the garage to vehicles that need service")
            }
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill").foregroundStyle(Color.appAccent)
                    .frame(width: 30, height: 30)
                    .background(Color.appAccent.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maintenance schedule").font(.caption.weight(.semibold))
                    Text(
                        "\(store.vehicles.count - dueCount) of \(store.vehicles.count) vehicles on schedule"
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(
                    "\(Int(Double(store.vehicles.count - dueCount) / Double(store.vehicles.count) * 100))%"
                )
                .font(.caption.weight(.semibold)).foregroundStyle(Color.appAccent)
            }
            .padding(11).background(Color.appElevated, in: RoundedRectangle(cornerRadius: 9))
            ProgressView(
                value: Double(store.vehicles.count - dueCount),
                total: Double(store.vehicles.count)
            )
            .tint(.appAccent)
        }
        .padding(16)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
    }

    private func garageMetric(_ title: String, _ value: String, _ detail: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(value).font(.headline).monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12).background(Color.appElevated, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct VehicleCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let vehicle: Vehicle
    var isSelected = false
    var onSelect: () -> Void = {}

    private var serviceDue: Bool { garageServiceDue(vehicle) }
    private var serviceMessage: String {
        if vehicle.nextServiceDate < Date() {
            return "Service overdue · \(vehicle.nextServiceDate.shortDate)"
        }
        if vehicle.distanceToService == 0 {
            return "Service mileage reached · \(vehicle.mileage.formatted()) km"
        }
        return serviceDue
            ? "Service coming up · \(vehicle.nextServiceDate.shortDate)"
            : "Next service · \(vehicle.nextServiceDate.shortDate)"
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.15, blue: 0.29),
                        Color(red: 0.04, green: 0.07, blue: 0.12),
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .frame(width: 250, height: 250).offset(x: 95, y: 65)
                Circle()
                    .fill(Color(red: 0.10, green: 0.42, blue: 1).opacity(0.2))
                    .frame(width: 180, height: 180).blur(radius: 45)
                if let photo = store.vehiclePhotos[vehicle.id] {
                    GeometryReader { geometry in
                        Image(uiImage: photo).resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .accessibilityHidden(true)
                } else if vehicle.hasToyotaRaizeArtwork {
                    Image("ToyotaRaize").resizable().scaledToFit()
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: vehicle.image)
                        .font(.system(size: 104, weight: .ultraLight))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .shadow(color: .blue.opacity(0.5), radius: 28, y: 8)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 176).clipped()
            .overlay(alignment: .topLeading) {
                Text(isSelected ? "ACTIVE VEHICLE" : "IN GARAGE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.appSuccess : .white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.black.opacity(0.65), in: Capsule())
                    .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                if serviceDue {
                    Label("SERVICE DUE", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.black.opacity(0.65), in: Capsule())
                        .padding(12)
                }
            }
            .overlay(alignment: .bottomLeading) {
                Text(vehicle.registration.uppercased())
                    .font(.caption.monospaced().weight(.semibold))
                    .tracking(0.5).foregroundStyle(.white)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 5))
                    .padding(12)
            }

            VStack(alignment: .leading, spacing: 12) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        cardTitle
                        cardMileage
                    }
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        cardTitle
                        Spacer(minLength: 0)
                        cardMileage
                    }
                }

                let metricLayout =
                    dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 8))
                metricLayout {
                    vehicleMetric(
                        "CURRENT MILEAGE", "\(vehicle.mileage.formatted()) km",
                        symbol: "gauge.with.dots.needle.67percent")
                    vehicleMetric(
                        "NEXT SERVICE", vehicle.nextServiceDate.shortDate,
                        symbol: "wrench.fill")
                }

                if serviceDue {
                    NavigationLink {
                        MaintenanceListView(vehicleID: vehicle.id)
                    } label: {
                        HStack {
                            Label(serviceMessage, systemImage: "clock.badge.exclamationmark")
                            Spacer(minLength: 8)
                            Text("Review").font(.caption.weight(.semibold))
                            Image(systemName: "chevron.right").font(.caption2.bold())
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).frame(minHeight: 44)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                } else {
                    Label(serviceMessage, systemImage: "calendar")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.appAccent)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 10)
                        .background(Color.appElevated, in: RoundedRectangle(cornerRadius: 8))
                }

                let actionLayout =
                    dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 8))
                actionLayout {
                    NavigationLink {
                        VehicleDetailView(vehicle: vehicle)
                    } label: {
                        Label("View details", systemImage: "car.side.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(Color.appCanvas)
                            .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 12))
                    }
                    if isSelected {
                        NavigationLink {
                            DocumentsView(vehicleID: vehicle.id)
                        } label: {
                            Label("Documents", systemImage: "doc.text")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(Color.appAccent)
                                .background(
                                    Color.appElevated,
                                    in: RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Button(action: onSelect) {
                            Label("Set active", systemImage: "checkmark.circle")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(Color.appAccent)
                                .background(
                                    Color.appElevated,
                                    in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var cardTitle: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(vehicle.title).font(.title3.weight(.semibold)).lineLimit(2)
            Text("\(vehicle.year) · \(vehicle.fuel) · \(vehicle.color)")
                .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
        }
    }

    private var cardMileage: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 3) {
            Text(vehicle.mileage.formatted()).font(.headline).monospacedDigit()
            Text("km recorded").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func vehicleMetric(_ title: String, _ value: String, symbol: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).foregroundStyle(Color.appAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.medium))
                    .foregroundStyle(.secondary).lineLimit(2)
                Text(value).font(.subheadline.weight(.semibold))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity).padding(9)
        .background(Color.appElevated, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct VehicleDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var vehicle: Vehicle
    @State private var showEdit = false
    @State private var showDeleteConfirmation = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUpdatingPhoto = false
    @State private var photoError: String?
    @State private var showPhotoActions = false
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    var body: some View {
        let hasVehiclePhoto = store.vehiclePhotos[vehicle.id] != nil
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SurfaceCard(padding: 22) {
                    VStack(spacing: 14) {
                        Button {
                            showPhotoActions = true
                        } label: {
                            Group {
                                if let photo = store.vehiclePhotos[vehicle.id] {
                                    GeometryReader { geometry in
                                        Image(uiImage: photo).resizable().scaledToFill()
                                            .frame(
                                                width: geometry.size.width,
                                                height: geometry.size.height
                                            )
                                            .clipped()
                                    }
                                } else if vehicle.hasToyotaRaizeArtwork {
                                    Image("ToyotaRaize").resizable().scaledToFit()
                                        .padding(.horizontal, 8)
                                } else {
                                    Image(systemName: vehicle.image)
                                        .font(.system(size: 75, weight: .light))
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 145)
                            .background(
                                hasVehiclePhoto || vehicle.hasToyotaRaizeArtwork
                                    ? Color(red: 0.07, green: 0.12, blue: 0.21) : Color.appMint,
                                in: RoundedRectangle(cornerRadius: 20)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(Color.appAccent, in: Circle())
                                    .padding(10)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isUpdatingPhoto)
                        .accessibilityLabel(
                            hasVehiclePhoto ? "Change vehicle photo" : "Add vehicle photo")
                        if isUpdatingPhoto { ProgressView("Saving photo…") }
                        if let photoError {
                            Text(photoError).font(.caption).foregroundStyle(.red)
                        }
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(vehicle.title).font(.title2.bold())
                                Text("\(vehicle.year) · \(vehicle.color)").font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if vehicle.id == store.selectedVehicle?.id {
                                StatusBadge(text: "Active")
                            }
                        }
                        VStack(spacing: 8) {
                            vehicleStat(
                                "Mileage", "\(vehicle.mileage.formatted()) km",
                                "gauge.with.dots.needle.67percent")
                            vehicleStat("Fuel", vehicle.fuel, "fuelpump.fill")
                            vehicleStat(
                                "Next service", "\(vehicle.distanceToService.formatted()) km",
                                "wrench.fill")
                        }
                    }
                }
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "Registration")
                        detailLine("Registration number", vehicle.registration)
                        detailLine("VIN", vehicle.vin)
                        detailLine("Year", "\(vehicle.year)")
                    }
                }
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "Specifications")
                        detailLine("Engine", vehicle.engine)
                        detailLine("Transmission", vehicle.transmission)
                        detailLine("Color", vehicle.color)
                    }
                }
                NavigationLink {
                    DocumentsView(vehicleID: vehicle.id)
                } label: {
                    HStack {
                        Image(systemName: "doc.text.fill").foregroundStyle(Color.appAccent)
                        Text("Vehicle documents").foregroundStyle(.primary)
                        Spacer()
                        Text("\(store.documents.filter { $0.vehicleID == vehicle.id }.count)")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(16).background(Color.appCard, in: RoundedRectangle(cornerRadius: 17))
                }
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete vehicle", systemImage: "trash")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(20)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appCanvas.ignoresSafeArea()).navigationTitle("Vehicle details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEdit = true } } }
        .sheet(isPresented: $showEdit) {
            NavigationStack { EditVehicleView(vehicle: vehicle) { updated in vehicle = updated } }
        }
        .alert("Delete this vehicle?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteVehicle(vehicle)
                dismiss()
            }
        } message: {
            Text(
                "This permanently removes the vehicle and its maintenance, fuel, expense, and document records."
            )
        }
        .confirmationDialog("Vehicle photo", isPresented: $showPhotoActions) {
            Button("Choose from Library") { showPhotoLibrary = true }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            if hasVehiclePhoto {
                Button("Remove Photo", role: .destructive) {
                    do {
                        try store.removeVehiclePhoto(vehicleID: vehicle.id)
                        photoError = nil
                    } catch { photoError = error.localizedDescription }
                }
            }
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $selectedPhoto, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPhotoPicker { data in
                showCamera = false
                if let data { Task { await savePhoto(data) } }
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                isUpdatingPhoto = true
                defer { isUpdatingPhoto = false }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw PhotoProcessing.Error.invalidImage
                    }
                    await savePhoto(data)
                } catch { photoError = error.localizedDescription }
                selectedPhoto = nil
            }
        }
    }

    private func savePhoto(_ data: Data) async {
        isUpdatingPhoto = true
        defer { isUpdatingPhoto = false }
        do {
            try await store.setVehiclePhoto(data, vehicleID: vehicle.id)
            photoError = nil
        } catch { photoError = error.localizedDescription }
    }
}

struct AddVehicleView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var make = ""
    @State private var model = ""
    @State private var year = String(Calendar.current.component(.year, from: Date()))
    @State private var registration = ""
    @State private var mileage = ""
    @State private var vin = ""
    @State private var fuel = "Petrol"
    @State private var lastServiceDate = Date()
    @State private var serviceMileageInterval = 5_000
    @State private var serviceMonthInterval = 6
    @State private var error: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingPhoto: Data?
    @State private var photoPreview: UIImage?
    @State private var isLoadingPhoto = false
    @State private var showPhotoActions = false
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    @FocusState private var focusedField: AddVehicleField?

    private enum AddVehicleField: Hashable {
        case make, model, year, registration, mileage, vin
    }

    private var trimmedMake: String {
        make.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var vehicleName: String {
        let name = [trimmedMake, trimmedModel].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "Your new vehicle" : name
    }

    private var isDuplicateVehicle: Bool {
        store.hasDuplicateVehicle(registration: registration, vin: vin)
    }

    private var isFormValid: Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        guard let yearValue = Int(year), (1886...(currentYear + 1)).contains(yearValue),
            let mileageValue = Int(mileage), mileageValue >= 0
        else { return false }
        return !isDuplicateVehicle && !trimmedMake.isEmpty && !trimmedModel.isEmpty
            && !registration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var calculatedNextServiceMileage: Int {
        (Int(mileage) ?? 0) + serviceMileageInterval
    }

    private var calculatedNextServiceDate: Date {
        Calendar.current.date(
            byAdding: .month, value: serviceMonthInterval, to: lastServiceDate) ?? lastServiceDate
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("NEW VEHICLE", systemImage: "sparkles")
                        .font(.caption2.weight(.bold)).tracking(1.1)
                        .foregroundStyle(Color.appAccent)
                    Text("Add a vehicle to your garage")
                        .font(.title2.weight(.bold))
                    Text("Enter the basic details below. You can add more specifications later.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                Button {
                    showPhotoActions = true
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        if let photoPreview {
                            Image(uiImage: photoPreview).resizable().scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: 210).clipped()
                        } else {
                            LinearGradient(
                                colors: [Color.appAccent.opacity(0.24), Color.appMint],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            .frame(height: 210)
                            .overlay {
                                Image(systemName: "car.side.fill")
                                    .font(.system(size: 76, weight: .ultraLight))
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                        LinearGradient(
                            colors: [.clear, .black.opacity(photoPreview == nil ? 0.18 : 0.68)],
                            startPoint: .center, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 5) {
                            Label(
                                photoPreview == nil ? "Add a vehicle photo" : "Change photo",
                                systemImage: "camera.fill"
                            )
                            .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                            Text(photoPreview == nil ? "Camera or photo library" : vehicleName)
                                .font(.caption).foregroundStyle(.white.opacity(0.82))
                        }
                        .padding(16)
                    }
                    .frame(maxWidth: .infinity).frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoadingPhoto)
                .accessibilityLabel(
                    pendingPhoto == nil ? "Add vehicle photo" : "Change vehicle photo")

                if isLoadingPhoto {
                    HStack(spacing: 10) {
                        ProgressView().tint(.appAccent)
                        Text("Preparing your photo…")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    formSectionTitle("Basic information", symbol: "car.side.fill")
                    Text("Fields marked with * are required.")
                        .font(.caption).foregroundStyle(.secondary)
                    vehicleField(
                        "Vehicle brand *", placeholder: "e.g. Toyota", text: $make,
                        symbol: "building.2", field: .make)
                    vehicleField(
                        "Vehicle model *", placeholder: "e.g. Corolla", text: $model,
                        symbol: "car.rear", field: .model)
                    HStack(spacing: 12) {
                        vehicleField(
                            "Year *", placeholder: "2026", text: $year,
                            symbol: "calendar", field: .year, keyboard: .numberPad)
                        vehicleField(
                            "Registration *", placeholder: "CAA-1234", text: $registration,
                            symbol: "rectangle.and.text.magnifyingglass", field: .registration,
                            capitalization: .characters)
                    }
                    if isDuplicateVehicle {
                        Label(
                            "This vehicle is already in your garage.",
                            systemImage: "exclamationmark.circle.fill"
                        )
                        .font(.caption.weight(.semibold)).foregroundStyle(.red)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(16)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 14) {
                    formSectionTitle("Driving details", symbol: "gauge.with.dots.needle.67percent")
                    vehicleField(
                        "Current mileage (km) *", placeholder: "e.g. 25000", text: $mileage,
                        symbol: "road.lanes", field: .mileage, keyboard: .numberPad)
                    Text("Fuel type").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(fuelOptions, id: \.name) { option in
                            Button {
                                withAnimation(.easeOut(duration: 0.18)) { fuel = option.name }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: option.symbol)
                                    Text(option.name).font(.subheadline.weight(.semibold))
                                    Spacer(minLength: 0)
                                    if fuel == option.name {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                }
                                .foregroundStyle(fuel == option.name ? Color.appCanvas : .primary)
                                .padding(.horizontal, 12).frame(minHeight: 48)
                                .background(
                                    fuel == option.name ? Color.appAccent : Color.appElevated,
                                    in: RoundedRectangle(cornerRadius: 13))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    vehicleField(
                        "VIN", placeholder: "Optional", text: $vin,
                        symbol: "number", field: .vin, capitalization: .characters)
                }
                .padding(16)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 14) {
                    formSectionTitle("Service schedule", symbol: "wrench.and.screwdriver.fill")
                    Text("We use these details to calculate your next service reminder.")
                        .font(.caption).foregroundStyle(.secondary)
                    DatePicker(
                        "Last service date", selection: $lastServiceDate, in: ...Date(),
                        displayedComponents: .date)
                    Divider()
                    Picker("Service every", selection: $serviceMileageInterval) {
                        ForEach([5_000, 7_500, 10_000, 15_000], id: \.self) { distance in
                            Text("\(distance.formatted()) km").tag(distance)
                        }
                    }
                    Picker("Time interval", selection: $serviceMonthInterval) {
                        Text("3 months").tag(3)
                        Text("6 months").tag(6)
                        Text("12 months").tag(12)
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "bell.badge.fill").foregroundStyle(Color.appAccent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Next service")
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(
                                "\(calculatedNextServiceDate.shortDate) or at \(calculatedNextServiceMileage.formatted()) km"
                            )
                            .font(.subheadline.weight(.semibold))
                        }
                    }
                    .padding(13).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(16)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 20))

                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline).foregroundStyle(.red)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 110)
            .frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .background(Color.appCanvas.ignoresSafeArea())
        .navigationTitle("Add vehicle").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                focusedField = nil
                save()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to my garage")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isLoadingPhoto || !isFormValid)
            .opacity(isLoadingPhoto || !isFormValid ? 0.5 : 1)
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
            .background(.bar)
        }
        .confirmationDialog("Vehicle photo", isPresented: $showPhotoActions) {
            Button("Choose from Library") { showPhotoLibrary = true }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            if pendingPhoto != nil {
                Button("Remove Photo", role: .destructive) {
                    pendingPhoto = nil
                    photoPreview = nil
                    selectedPhoto = nil
                }
            }
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $selectedPhoto, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPhotoPicker { data in
                showCamera = false
                if let data { Task { await preparePhoto(data) } }
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                isLoadingPhoto = true
                defer { isLoadingPhoto = false }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw PhotoProcessing.Error.invalidImage
                    }
                    await preparePhoto(data)
                } catch {
                    self.error = error.localizedDescription
                }
                selectedPhoto = nil
            }
        }
    }

    private var fuelOptions: [(name: String, symbol: String)] {
        [
            ("Petrol", "fuelpump.fill"), ("Diesel", "drop.fill"),
            ("Hybrid", "leaf.fill"), ("Electric", "bolt.fill"),
        ]
    }

    private func formSectionTitle(_ title: String, symbol: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol).foregroundStyle(Color.appAccent)
                .frame(width: 32, height: 32)
                .background(Color.appAccent.opacity(0.12), in: Circle())
            Text(title).font(.headline)
        }
    }

    private func vehicleField(
        _ title: String,
        placeholder: String,
        text: Binding<String>,
        symbol: String,
        field: AddVehicleField,
        keyboard: UIKeyboardType = .default,
        capitalization: TextInputAutocapitalization = .words
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 9) {
                Image(systemName: symbol).foregroundStyle(Color.appAccent).frame(width: 20)
                TextField(placeholder, text: text)
                    .focused($focusedField, equals: field)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12).frame(minHeight: 48)
            .background(Color.appElevated, in: RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(
                        focusedField == field ? Color.appAccent : Color.clear,
                        lineWidth: 1.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func preparePhoto(_ data: Data) async {
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        do {
            let jpeg = try await PhotoProcessing.prepare(data, maxPixelSize: 1200)
            pendingPhoto = jpeg
            photoPreview = UIImage(data: jpeg)
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func save() {
        let currentYear = Calendar.current.component(.year, from: Date())
        guard let yearValue = Int(year), (1886...(currentYear + 1)).contains(yearValue),
            let mileageValue = Int(mileage), mileageValue >= 0
        else {
            error = "Enter a valid year and mileage."
            return
        }
        guard !isDuplicateVehicle else {
            error = "This vehicle is already in your garage."
            return
        }
        let vehicle = Vehicle(
            make: trimmedMake, model: trimmedModel, year: yearValue,
            registration: registration.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            mileage: mileageValue, fuel: fuel, color: "Not specified", image: "car.side.fill",
            nextServiceMileage: mileageValue + serviceMileageInterval,
            nextServiceDate: calculatedNextServiceDate,
            vin: vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            engine: "Not specified", transmission: "Not specified",
            serviceMileageInterval: serviceMileageInterval,
            serviceMonthInterval: serviceMonthInterval)
        do {
            if let pendingPhoto {
                try store.setPreparedVehiclePhoto(pendingPhoto, vehicleID: vehicle.id)
            }
            if store.addVehicle(vehicle) {
                dismiss()
            } else {
                error = "This vehicle is already in your garage."
            }
        } catch { self.error = error.localizedDescription }
    }
}

struct EditVehicleView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var vehicle: Vehicle
    @State private var error: String?
    var onSave: (Vehicle) -> Void

    private var serviceMileageInterval: Binding<Int> {
        Binding(
            get: { vehicle.serviceMileageInterval ?? 5_000 },
            set: { vehicle.serviceMileageInterval = $0 })
    }

    private var serviceMonthInterval: Binding<Int> {
        Binding(
            get: { vehicle.serviceMonthInterval ?? 6 },
            set: { vehicle.serviceMonthInterval = $0 })
    }

    var body: some View {
        Form {
            Section("Vehicle") {
                TextField("Vehicle brand", text: $vehicle.make)
                TextField("Vehicle model", text: $vehicle.model)
                TextField("Year", value: $vehicle.year, format: .number).keyboardType(.numberPad)
                TextField("Registration", text: $vehicle.registration)
                TextField("VIN", text: $vehicle.vin)
            }
            Section("Mileage & service") {
                TextField("Current mileage", value: $vehicle.mileage, format: .number)
                    .keyboardType(.numberPad)
                TextField(
                    "Next service mileage", value: $vehicle.nextServiceMileage, format: .number
                )
                .keyboardType(.numberPad)
                DatePicker(
                    "Next service date", selection: $vehicle.nextServiceDate,
                    displayedComponents: .date)
                Picker("Service distance interval", selection: serviceMileageInterval) {
                    ForEach([5_000, 7_500, 10_000, 15_000], id: \.self) { distance in
                        Text("\(distance.formatted()) km").tag(distance)
                    }
                }
                Picker("Service time interval", selection: serviceMonthInterval) {
                    Text("3 months").tag(3)
                    Text("6 months").tag(6)
                    Text("12 months").tag(12)
                }
            }
            Section("Specifications") {
                TextField("Fuel", text: $vehicle.fuel)
                TextField("Color", text: $vehicle.color)
                TextField("Engine", text: $vehicle.engine)
                TextField("Transmission", text: $vehicle.transmission)
            }
            if let error { Text(error).foregroundStyle(.red) }
            Section {
                Button("Save changes") {
                    save()
                }
            }
        }
        .navigationTitle("Edit vehicle").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
        }
    }

    private func save() {
        let currentYear = Calendar.current.component(.year, from: Date())
        guard !vehicle.make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !vehicle.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !vehicle.registration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            (1886...(currentYear + 1)).contains(vehicle.year), vehicle.mileage >= 0
        else {
            error = "Enter valid vehicle details and mileage."
            return
        }
        let recordedMileage = store.highestRecordedMileage(vehicleID: vehicle.id)
        guard vehicle.mileage >= recordedMileage else {
            error = "Mileage cannot be below the recorded history of \(recordedMileage.formatted()) km."
            return
        }
        guard !store.hasDuplicateVehicle(
            registration: vehicle.registration, vin: vehicle.vin, excluding: vehicle.id)
        else {
            error = "Another vehicle already uses this registration or VIN."
            return
        }
        vehicle.make = vehicle.make.trimmingCharacters(in: .whitespacesAndNewlines)
        vehicle.model = vehicle.model.trimmingCharacters(in: .whitespacesAndNewlines)
        vehicle.registration = vehicle.registration.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        vehicle.vin = vehicle.vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        store.updateVehicle(vehicle)
        onSave(vehicle)
        dismiss()
    }
}

private func vehicleStat(_ title: String, _ value: String, _ symbol: String) -> some View {
    HStack(spacing: 12) {
        Image(systemName: symbol).foregroundStyle(Color.appAccent)
            .frame(width: 24)
        Text(title).font(.subheadline).foregroundStyle(.secondary)
        Spacer(minLength: 8)
        Text(value).font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.trailing)
    }
    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.horizontal, 12)
    .background(Color.appCanvas, in: RoundedRectangle(cornerRadius: 13))
}
private func detailLine(_ title: String, _ value: String) -> some View {
    HStack {
        Text(title).foregroundStyle(.secondary)
        Spacer()
        Text(value).fontWeight(.medium).multilineTextAlignment(.trailing)
    }
    .font(.subheadline)
}
func money(_ value: Double) -> String {
    value.formatted(.currency(code: "LKR").precision(.fractionLength(0)))
}
func compactMoney(_ value: Double) -> String {
    value >= 100_000
        ? "LKR \((value / 1000).formatted(.number.precision(.fractionLength(0))))k" : money(value)
}
