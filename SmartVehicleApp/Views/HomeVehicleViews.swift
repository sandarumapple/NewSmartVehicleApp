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
    @State private var showReports = false
    @State private var showWidgetHelp = false
    @State private var showDocuments = false
    @State private var showAnalytics = false
    @State private var showNearby = false
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
    private var thisMonthExpenses: Double { viewModel.thisMonthExpenses }
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
    private var nextReminder: Date? { viewModel.nextReminder }
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
                                if serviceNeedsAttention || !attentionDocuments.isEmpty {
                                    Circle().fill(Color.red).frame(width: 8, height: 8)
                                        .padding(8)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Notifications")
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
                        onDetails: { showVehicleDetails = true },
                        onDocuments: { showDocuments = true }
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
                        QuickAction(symbol: "fuelpump.fill", label: "Fuel", tint: .appAccent) {
                            showFuel = true
                        }
                        QuickAction(symbol: "doc.richtext", label: "Reports", tint: .blue) {
                            showReports = true
                        }
                        QuickAction(symbol: "wrench.fill", label: "Service", tint: .appSuccess) {
                            showMaintenance = true
                        }
                        QuickAction(symbol: "creditcard.fill", label: "Expense", tint: .purple) {
                            showExpense = true
                        }
                        QuickAction(symbol: "chart.xyaxis.line", label: "Analytics", tint: .orange)
                        {
                            showAnalytics = true
                        }
                        QuickAction(symbol: "doc.text.fill", label: "Documents", tint: .red) {
                            showDocuments = true
                        }
                        QuickAction(symbol: "doc.viewfinder", label: "Scan", tint: .mint) {
                            showScanner = true
                        }
                        QuickAction(symbol: "map.fill", label: "Nearby", tint: .yellow) {
                            showNearby = true
                        }
                    }
                }
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Needs your attention", systemImage: "bell.badge.fill")
                            .font(.system(size: 15, weight: .semibold))
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
                            if !serviceNeedsAttention && attentionDocuments.isEmpty {
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

                if let vehicle {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "Vehicle overview")
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10
                        ) {
                            NavigationLink {
                                MaintenanceListView()
                            } label: {
                                MetricTile(
                                    title: "Next service",
                                    value: "\(vehicle.distanceToService.formatted()) km",
                                    detail: vehicle.nextServiceDate.shortDate,
                                    symbol: "wrench.fill", tint: .orange)
                            }
                            NavigationLink {
                                FuelListView()
                            } label: {
                                MetricTile(
                                    title: "Fuel status",
                                    value: "\(store.selectedFuelRecords.count) refills",
                                    detail: vehicle.fuel, symbol: "fuelpump.fill", tint: .appSuccess
                                )
                            }
                            NavigationLink {
                                ExpenseListView()
                            } label: {
                                MetricTile(
                                    title: "This month",
                                    value: compactMoney(thisMonthExpenses),
                                    detail: "Recorded expenses", symbol: "creditcard.fill")
                            }
                            NavigationLink {
                                DocumentsView()
                            } label: {
                                MetricTile(
                                    title: "Documents",
                                    value: "\(store.selectedDocuments.count) saved",
                                    detail: "Your document vault", symbol: "doc.text.fill",
                                    tint: .purple)
                            }
                            NavigationLink {
                                MaintenanceListView()
                            } label: {
                                MetricTile(
                                    title: "Next reminder",
                                    value: nextReminder?.shortDate ?? "None",
                                    detail: "Upcoming event", symbol: "calendar.badge.clock",
                                    tint: .orange)
                            }
                            NavigationLink {
                                AnalyticsView()
                            } label: {
                                DashboardTrendTile(expenses: store.selectedExpenses)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }

                Button {
                    showWidgetHelp = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.appAccent)
                            .frame(width: 62, height: 62)
                            .background(Color.appMint, in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Your garage, at a glance")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text("Add the Smart Vehicle widget to your Home Screen")
                                .font(.caption).foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.caption).foregroundStyle(Color.appAccent)
                    }
                    .padding(16)
                    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
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
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading(title: "Nearby services")
                    NavigationLink {
                        NearbyMapView()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 31))
                                .foregroundStyle(Color.appAccent)
                                .frame(width: 64, height: 64)
                                .background(Color.appMint, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Explore your area")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text("Fuel stations, garages & vehicle care")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.caption).foregroundStyle(Color.appAccent)
                        }
                        .padding(16)
                        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
                    }
                    SectionHeading(title: "Marketplace")
                    NavigationLink {
                        MarketplaceView()
                    } label: {
                        dashboardLink(
                            store.marketplaceItems.first?.title
                                ?? "Discover vehicles & spare parts",
                            store.marketplaceItems.first?.price ?? "Browse the marketplace",
                            "bag.fill", .orange)
                    }
                    SectionHeading(title: "Owner community")
                    NavigationLink {
                        CommunityView()
                    } label: {
                        dashboardLink(
                            store.posts.first?.author ?? "Join the conversation",
                            store.posts.first?.text ?? "Stories and advice from fellow drivers",
                            "bubble.left.and.bubble.right.fill", .purple)
                    }
                    SectionHeading(title: "Vehicle reports")
                    Button {
                        showReports = true
                    } label: {
                        dashboardLink(
                            "Your vehicle dossier", "Maintenance, costs and ownership",
                            "doc.richtext", .appSuccess)
                    }
                }
                .buttonStyle(.plain).padding(.horizontal, 16)
                Spacer(minLength: 18)
            }
            .padding(.top, 8)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appCanvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showDocuments) { DocumentsView() }
        .navigationDestination(isPresented: $showAnalytics) { AnalyticsView() }
        .navigationDestination(isPresented: $showNearby) { NearbyMapView() }
        .navigationDestination(isPresented: $showVehicleDetails) {
            if let vehicle { VehicleDetailView(vehicle: vehicle) }
        }
        .sheet(isPresented: $showSwitcher) {
            VehicleSwitcherSheet().presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNotifications) { NavigationStack { NotificationCenterView() } }
        .sheet(isPresented: $showFuel) { NavigationStack { AddFuelView() } }
        .sheet(isPresented: $showMaintenance) { NavigationStack { AddMaintenanceView() } }
        .sheet(isPresented: $showExpense) { NavigationStack { AddExpenseView() } }
        .fullScreenCover(isPresented: $showScanner) {
            NavigationStack { DocumentScannerFlow(startWithCamera: true) }
        }
        .sheet(isPresented: $showReports) { NavigationStack { ReportSetupView() } }
        .alert("Add the Smart Vehicle widget", isPresented: $showWidgetHelp) {
            Button("Done", role: .cancel) {}
        } message: {
            Text(
                "Touch and hold your Home Screen, tap Edit, then Add Widget and search for Smart Vehicle."
            )
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
    private func dashboardLink(_ title: String, _ subtitle: String, _ symbol: String, _ tint: Color)
        -> some View
    {
        SurfaceCard {
            HStack(spacing: 12) {
                Image(systemName: symbol).foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
        }
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

private struct DashboardTrendTile: View {
    let expenses: [ExpenseRecord]

    private var months: [(date: Date, amount: Double)] {
        let calendar = Calendar.current
        let currentMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        return (0..<6).reversed()
            .compactMap { offset in
                guard let month = calendar.date(byAdding: .month, value: -offset, to: currentMonth)
                else { return nil }
                let amount =
                    expenses
                    .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
                    .reduce(0) { $0 + $1.amount }
                return (month, amount)
            }
    }

    var body: some View {
        SurfaceCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.orange)
                    .frame(width: 32, height: 32)
                    .background(Color.orange.opacity(0.11), in: Circle())
                Chart(months, id: \.date) { month in
                    LineMark(
                        x: .value("Month", month.date),
                        y: .value("Expenses", month.amount)
                    )
                    .foregroundStyle(Color.appAccent)
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 32)
                Text("Analytics").font(.caption.weight(.semibold))
                Text("6-month expense trend")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct GarageHeroCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let vehicle: Vehicle
    var onDetails: () -> Void
    var onDocuments: () -> Void
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
                let actionLayout =
                    dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 8))
                actionLayout {
                    Button(action: onDetails) {
                        Label("View vehicle", systemImage: "car.side.fill")
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(Color.appCanvas)
                    }
                    Button(action: onDocuments) {
                        Label("Documents", systemImage: "doc.text")
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.appElevated, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(Color.appAccent)
                    }
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
            Image(systemName: "gauge.with.dots.needle.67")
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
        .background(Color.appCanvas.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAdd) { NavigationStack { AddVehicleView() } }
    }

    private var garageSummary: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill").foregroundStyle(Color.appAccent)
                Text("Garage summary").font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("\(store.vehicles.count) total")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                garageMetric("Vehicles", "\(store.vehicles.count)", "in your garage")
                garageMetric("Fleet mileage", "\(fleetMileage.formatted()) km", "recorded")
                garageMetric("Service due", "\(dueCount)", "date or mileage")
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
                        symbol: "gauge.with.dots.needle.67")
                    vehicleMetric(
                        "NEXT SERVICE", vehicle.nextServiceDate.shortDate,
                        symbol: "wrench.fill")
                }

                Label(
                    serviceMessage,
                    systemImage: serviceDue ? "clock.badge.exclamationmark" : "calendar"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(serviceDue ? Color.orange : Color.appAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.appElevated, in: RoundedRectangle(cornerRadius: 8))

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
    @State var vehicle: Vehicle
    @State private var showEdit = false
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
                                "gauge.with.dots.needle.67")
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
    @State private var year = "2024"
    @State private var registration = ""
    @State private var mileage = ""
    @State private var vin = ""
    @State private var fuel = "Petrol"
    @State private var error: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingPhoto: Data?
    @State private var photoPreview: UIImage?
    @State private var isLoadingPhoto = false
    @State private var showPhotoActions = false
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    var body: some View {
        Form {
            Section("Vehicle identity") {
                TextField("Make", text: $make)
                TextField("Model", text: $model)
                TextField("Year", text: $year).keyboardType(.numberPad)
                TextField("Registration number", text: $registration)
                    .textInputAutocapitalization(.characters)
                TextField("VIN (optional)", text: $vin)
            }
            Section("Vehicle details") {
                TextField("Current mileage (km)", text: $mileage).keyboardType(.numberPad)
                Picker("Fuel type", selection: $fuel) {
                    ForEach(["Petrol", "Diesel", "Hybrid", "Electric"], id: \.self) { Text($0) }
                }
            }
            Section("Vehicle photo") {
                Button {
                    showPhotoActions = true
                } label: {
                    Group {
                        if let photoPreview {
                            GeometryReader { geometry in
                                Image(uiImage: photoPreview).resizable().scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            }
                        } else {
                            VStack(spacing: 9) {
                                Image(systemName: "camera.fill").font(.title2)
                                Text("Add vehicle photo").font(.subheadline.weight(.semibold))
                                Text("Tap to take or choose a photo")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundStyle(Color.appAccent)
                        }
                    }
                    .frame(maxWidth: .infinity).frame(height: 160)
                    .background(Color.appMint, in: RoundedRectangle(cornerRadius: 12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .bottomTrailing) {
                        if photoPreview != nil {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.appAccent, in: Circle())
                                .padding(10)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoadingPhoto)
                .accessibilityLabel(
                    pendingPhoto == nil ? "Add vehicle photo" : "Change vehicle photo")
                if isLoadingPhoto { ProgressView("Preparing photo…") }
            }
            if let error { Text(error).foregroundStyle(.red) }
            Section {
                Button("Save vehicle") { save() }
                    .disabled(
                        isLoadingPhoto || make.isEmpty || model.isEmpty || registration.isEmpty
                            || mileage.isEmpty)
            }
        }
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .navigationTitle("Add vehicle").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
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
        guard let yearValue = Int(year), let mileageValue = Int(mileage) else {
            error = "Enter a valid year and mileage."
            return
        }
        let vehicle = Vehicle(
            make: make, model: model, year: yearValue, registration: registration.uppercased(),
            mileage: mileageValue, fuel: fuel, color: "Not specified", image: "car.side.fill",
            nextServiceMileage: mileageValue + 5000,
            nextServiceDate: Calendar.current.date(byAdding: .month, value: 6, to: Date())!,
            vin: vin, engine: "Not specified", transmission: "Not specified")
        do {
            if let pendingPhoto {
                try store.setPreparedVehiclePhoto(pendingPhoto, vehicleID: vehicle.id)
            }
            store.addVehicle(vehicle)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct EditVehicleView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var vehicle: Vehicle
    var onSave: (Vehicle) -> Void
    var body: some View {
        Form {
            Section("Vehicle") {
                TextField("Make", text: $vehicle.make)
                TextField("Model", text: $vehicle.model)
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
            }
            Section("Specifications") {
                TextField("Fuel", text: $vehicle.fuel)
                TextField("Color", text: $vehicle.color)
                TextField("Engine", text: $vehicle.engine)
                TextField("Transmission", text: $vehicle.transmission)
            }
            Section {
                Button("Save changes") {
                    store.updateVehicle(vehicle)
                    onSave(vehicle)
                    dismiss()
                }
            }
        }
        .navigationTitle("Edit vehicle").navigationBarTitleDisplayMode(.inline)
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
