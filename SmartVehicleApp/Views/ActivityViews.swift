import Charts
import PhotosUI
import SwiftUI
import UIKit

struct ActivityHubView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection = "Overview"
    private let tabs = ["Overview", "Maintenance", "Fuel", "Expenses"]
    var body: some View {
        VStack(spacing: 0) {
            ScreenHeading(title: "Activity", subtitle: "Your vehicle, well looked after")
            Picker("Activity", selection: $selection) {
                ForEach(tabs, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented).padding(.horizontal, 20).padding(.bottom, 14)
            Group {
                switch selection {
                case "Maintenance": MaintenanceListView()
                case "Fuel": FuelListView()
                case "Expenses": ExpenseListView()
                default: ActivityOverviewView(onSelect: { selection = $0 })
                }
            }
        }
        .background(Color.appCanvas.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
    }
}

struct ActivityOverviewView: View {
    @EnvironmentObject private var store: AppStore
    var onSelect: (String) -> Void
    private var monthInterval: DateInterval? {
        Calendar.current.dateInterval(of: .month, for: Date())
    }
    private var thisMonthExpenses: Double {
        guard let monthInterval else { return 0 }
        let other = store.selectedExpenses
            .filter { monthInterval.contains($0.date) }
            .reduce(0) { $0 + $1.amount }
        let fuel = store.selectedFuelRecords
            .filter { monthInterval.contains($0.date) }
            .reduce(0) { $0 + $1.total }
        let maintenance = store.selectedVehicleRecords
            .filter { monthInterval.contains($0.date) }
            .reduce(0) { $0 + $1.cost }
        return other + fuel + maintenance
    }
    private var allTransactions: [ActivityDatedAmount] {
        store.selectedExpenses.map { ActivityDatedAmount(date: $0.date, amount: $0.amount) }
            + store.selectedFuelRecords.map { ActivityDatedAmount(date: $0.date, amount: $0.total) }
            + store.selectedVehicleRecords.map { ActivityDatedAmount(date: $0.date, amount: $0.cost) }
    }
    private var totalSpending: Double {
        allTransactions.reduce(0) { $0 + $1.amount }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ActivityMetricCard(
                        title: "THIS MONTH", value: compactMoney(thisMonthExpenses),
                        detail: "All activity", symbol: "calendar", tint: .blue)
                    ActivityMetricCard(
                        title: "TOTAL SPEND", value: compactMoney(totalSpending),
                        detail: "All recorded", symbol: "creditcard.fill", tint: .purple)
                    ActivityMetricCard(
                        title: "FILL-UPS", value: "\(store.selectedFuelRecords.count)",
                        detail: compactMoney(store.totalFuel), symbol: "fuelpump.fill", tint: .appAccent)
                    ActivityMetricCard(
                        title: "SERVICES", value: "\(store.selectedVehicleRecords.count)",
                        detail: "Maintenance records", symbol: "wrench.and.screwdriver.fill",
                        tint: .orange)
                }
                .padding(.horizontal, 20)
                ActivitySpendTrendChart(
                    title: "Overall spending trend",
                    subtitle: "Fuel, maintenance and other expenses",
                    points: activityMonthlySpending(allTransactions),
                    tint: .blue
                )
                .padding(.horizontal, 20)
                HStack(spacing: 11) {
                    Button {
                        onSelect("Maintenance")
                    } label: {
                        hubAction("Maintenance", "wrench.and.screwdriver.fill", .orange)
                    }
                    Button {
                        onSelect("Fuel")
                    } label: {
                        hubAction("Fuel records", "fuelpump.fill", .appAccent)
                    }
                    Button {
                        onSelect("Expenses")
                    } label: {
                        hubAction("Expenses", "creditcard.fill", .blue)
                    }
                }
                .buttonStyle(.plain).padding(.horizontal, 20)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionHeading(title: "Recent activity")
                        Spacer()
                        Button("View all") { onSelect("Maintenance") }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Color.appAccent)
                    }
                    SurfaceCard(padding: 14) {
                        VStack(spacing: 11) {
                            ForEach(store.selectedVehicleRecords.prefix(3)) { record in
                                NavigationLink {
                                    MaintenanceDetailView(record: record)
                                } label: {
                                    RecordRow(
                                        symbol: "wrench.and.screwdriver.fill", tint: .orange,
                                        title: record.type,
                                        subtitle:
                                            "\(record.date.shortDate) · \(record.mileage.formatted()) km",
                                        amount: money(record.cost))
                                }
                                .buttonStyle(.plain)
                            }
                            ForEach(store.selectedFuelRecords.prefix(2)) { record in
                                NavigationLink {
                                    FuelDetailView(record: record)
                                } label: {
                                    RecordRow(
                                        symbol: "fuelpump.fill", tint: .appAccent,
                                        title: "Fuel · \(record.station)",
                                        subtitle:
                                            "\(record.date.shortDate) · \(record.liters.formatted()) L",
                                        amount: money(record.total))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading(title: "Spending by category")
                    ExpenseBreakdownChart().padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 12)
        }
    }
}

private func hubAction(_ title: String, _ symbol: String, _ tint: Color) -> some View {
    VStack(spacing: 10) {
        Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(tint)
            .frame(width: 44, height: 44)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        Text(title).font(.caption.weight(.semibold)).foregroundStyle(.primary)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity).padding(13)
    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18))
}

private struct ActivityDatedAmount {
    let date: Date
    let amount: Double
}

private struct ActivitySpendPoint: Identifiable {
    let date: Date
    let amount: Double
    var id: Date { date }
}

private func activityMonthlySpending(_ transactions: [ActivityDatedAmount]) -> [ActivitySpendPoint] {
    let calendar = Calendar.current
    let currentMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
    return (0..<6).reversed().compactMap { offset in
        guard let month = calendar.date(byAdding: .month, value: -offset, to: currentMonth),
            let interval = calendar.dateInterval(of: .month, for: month)
        else { return nil }
        return ActivitySpendPoint(
            date: month,
            amount: transactions.filter { interval.contains($0.date) }
                .reduce(0) { $0 + $1.amount }
        )
    }
}

private struct ActivitySpendTrendChart: View {
    let title: String
    let subtitle: String
    let points: [ActivitySpendPoint]
    let tint: Color

    var body: some View {
        SurfaceCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.headline)
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(compactMoney(points.reduce(0) { $0 + $1.amount }))
                        .font(.caption.weight(.semibold)).foregroundStyle(tint)
                }
                Chart(points) { point in
                    AreaMark(
                        x: .value("Month", point.date),
                        y: .value("Spend", point.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tint.opacity(0.28), .clear],
                            startPoint: .top, endPoint: .bottom))
                    LineMark(
                        x: .value("Month", point.date),
                        y: .value("Spend", point.amount)
                    )
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    PointMark(
                        x: .value("Month", point.date),
                        y: .value("Spend", point.amount)
                    )
                    .foregroundStyle(tint)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine().foregroundStyle(.clear)
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(compactMoney(amount)).font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 170)
            }
        }
    }
}

struct MaintenanceListView: View {
    @EnvironmentObject private var store: AppStore
    var vehicleID: UUID? = nil
    @State private var showAdd = false
    @AppStorage("smart-vehicle-maintenance-filter") private var filter = "All"
    private var vehicle: Vehicle? {
        store.vehicles.first(where: { $0.id == vehicleID }) ?? store.selectedVehicle
    }
    private var vehicleRecords: [MaintenanceRecord] {
        store.maintenance.filter { $0.vehicleID == vehicle?.id }
    }
    private var records: [MaintenanceRecord] {
        return filter == "All"
            ? vehicleRecords
            : vehicleRecords.filter {
                $0.type.localizedCaseInsensitiveContains(filter)
            }
    }
    private var thisMonthCost: Double {
        guard let interval = Calendar.current.dateInterval(of: .month, for: Date()) else { return 0 }
        return vehicleRecords.filter { interval.contains($0.date) }.reduce(0) { $0 + $1.cost }
    }
    private var totalCost: Double { vehicleRecords.reduce(0) { $0 + $1.cost } }
    private var lastService: MaintenanceRecord? {
        vehicleRecords.filter { $0.date <= Date() }.max { $0.date < $1.date }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ActiveVehicleSelector(fixedVehicleID: vehicleID)
                    .padding(.horizontal, 20)
                ActivityAddHeader(
                    title: "Maintenance",
                    subtitle: "Services, repairs and upcoming care.",
                    actionTitle: "Add service",
                    action: { showAdd = true }
                )
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ActivityMetricCard(
                        title: "THIS MONTH", value: compactMoney(thisMonthCost),
                        detail: "Maintenance spend", symbol: "calendar", tint: .orange)
                    ActivityMetricCard(
                        title: "TOTAL SPEND", value: compactMoney(totalCost),
                        detail: "All services", symbol: "creditcard.fill", tint: .purple)
                    ActivityMetricCard(
                        title: "SERVICE RECORDS", value: "\(vehicleRecords.count)",
                        detail: "Completed entries", symbol: "checklist", tint: .blue)
                    ActivityMetricCard(
                        title: "LAST SERVICE", value: lastService?.date.shortDate ?? "—",
                        detail: lastService?.type ?? "No service recorded",
                        symbol: "clock.arrow.circlepath", tint: .green)
                }
                .padding(.horizontal, 20)
                SurfaceCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("NEXT SERVICE").font(.caption2.weight(.bold)).tracking(1)
                                .foregroundStyle(.secondary)
                            Text(vehicle?.nextServiceMileage ?? 0, format: .number)
                                .font(.title2.bold())
                                + Text(" km").font(.headline).foregroundColor(.secondary)
                            Text(
                                "\(vehicle?.nextServiceDate.shortDate ?? "") · Oil & filter"
                            )
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: 29))
                            .foregroundStyle(.orange).frame(width: 58, height: 58)
                            .background(
                                Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding(.horizontal, 20)
                ActivitySpendTrendChart(
                    title: "Maintenance spending",
                    subtitle: "Last six months",
                    points: activityMonthlySpending(
                        vehicleRecords.map { ActivityDatedAmount(date: $0.date, amount: $0.cost) }
                    ),
                    tint: .orange
                )
                .padding(.horizontal, 20)
                HStack {
                    SectionHeading(title: "Service history")
                    Spacer()
                    Menu {
                        Button("All records") { filter = "All" }
                        Button("Oil service") { filter = "Oil" }
                        Button("Tires") { filter = "Tire" }
                        Button("Brakes") { filter = "Brake" }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Color.appAccent)
                    }
                }
                .padding(.horizontal, 20)
                if records.isEmpty {
                    EmptyStateView(
                        symbol: "wrench.and.screwdriver", title: "No service records yet",
                        message: filter == "All"
                            ? "Keep a complete history of maintenance and repairs."
                            : "No service records match this filter.",
                        action: filter == "All" ? "Add service" : "Clear filter"
                    ) {
                        if filter == "All" { showAdd = true } else { filter = "All" }
                    }
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(records) { record in
                            NavigationLink {
                                MaintenanceDetailView(record: record)
                            } label: {
                                SurfaceCard(padding: 14) {
                                    RecordRow(
                                        symbol: "wrench.and.screwdriver.fill", tint: .orange,
                                        title: record.type,
                                        subtitle:
                                            "\(record.date.shortDate) · \(record.mileage.formatted()) km",
                                        amount: money(record.cost))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack { AddMaintenanceView(vehicleID: vehicle?.id) }
        }
    }
}

struct AddMaintenanceView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var vehicleID: UUID? = nil
    @State private var type = "Oil & filter change"
    @State private var date = Date()
    @State private var mileage = ""
    @State private var cost = ""
    @State private var notes = ""
    @State private var setReminder = true
    @State private var reminderDate =
        Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var error: String?
    @State private var didAttemptSave = false
    @State private var isSaving = false
    @FocusState private var focusedField: Field?
    private enum Field { case mileage, cost }
    private let types = [
        "Oil & filter change", "Tire rotation", "Brake service", "Battery", "Inspection", "Repair",
        "Other",
    ]
    private var selectedVehicle: Vehicle? {
        store.vehicles.first(where: { $0.id == vehicleID }) ?? store.selectedVehicle
    }
    private var odometerWarning: String? {
        guard let vehicle = selectedVehicle, let reading = Int(mileage), reading >= 0 else {
            return nil
        }
        return store.odometerWarning(vehicleID: vehicle.id, reading: reading)
    }
    private var projectedNextServiceMileage: Int? {
        guard let vehicle = selectedVehicle, let reading = Int(mileage), reading >= 0 else {
            return nil
        }
        return reading + (vehicle.serviceMileageInterval ?? 5_000)
    }
    private var mileageError: String? {
        if mileage.isEmpty { return didAttemptSave ? "Odometer reading is required." : nil }
        return Int(mileage).map { $0 >= 0 } == true ? nil : "Enter a valid odometer reading."
    }
    private var costError: String? {
        if cost.isEmpty { return didAttemptSave ? "Service cost is required." : nil }
        return Double(cost).map { $0 >= 0 } == true ? nil : "Enter a valid service cost."
    }
    private func suggestedReminderDate(from serviceDate: Date) -> Date {
        let months = selectedVehicle?.serviceMonthInterval ?? 6
        let calculated = Calendar.current.date(
            byAdding: .month, value: months, to: serviceDate) ?? Date()
        return max(calculated, Date())
    }
    var body: some View {
        Form {
            Section {
                Picker("Service type", selection: $type) { ForEach(types, id: \.self) { Text($0) } }
                DatePicker("Service date", selection: $date, in: ...Date(), displayedComponents: .date)
                LabeledContent(
                    "Vehicle", value: selectedVehicle?.title ?? "No vehicle selected")
                LabeledContent(
                    "Current reading",
                    value: "\(selectedVehicle?.mileage.formatted() ?? "—") km")
                TextField("Odometer (km)", text: $mileage).keyboardType(.numberPad)
                    .focused($focusedField, equals: .mileage)
                TextField("Cost (LKR)", text: $cost).keyboardType(.decimalPad)
                    .focused($focusedField, equals: .cost)
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
            } header: {
                Text("Service")
            } footer: {
                if let mileageError { InlineValidationMessage(message: mileageError) }
                else if let odometerWarning {
                    Label(odometerWarning, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                if let costError { InlineValidationMessage(message: costError) }
            }
            Section("Reminder") {
                Toggle("Set next reminder", isOn: $setReminder)
                if setReminder {
                    DatePicker(
                        "Remind me on", selection: $reminderDate, in: Date()...,
                        displayedComponents: .date)
                }
                if let projectedNextServiceMileage {
                    LabeledContent(
                        "Next service mileage",
                        value: "\(projectedNextServiceMileage.formatted()) km")
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
            Section {
                Button(isSaving ? "Saving…" : "Save maintenance") { save() }
                    .disabled(isSaving || mileage.isEmpty || cost.isEmpty)
            }
        }
        .navigationTitle("Add maintenance").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        .onAppear {
            guard let vehicle = selectedVehicle else { return }
            if mileage.isEmpty { mileage = String(vehicle.mileage) }
            reminderDate = suggestedReminderDate(from: date)
        }
        .onChange(of: date) { _, newDate in
            reminderDate = suggestedReminderDate(from: newDate)
        }
    }
    private func save() {
        guard !isSaving else { return }
        didAttemptSave = true
        if mileageError != nil {
            focusedField = .mileage
            return
        }
        if costError != nil {
            focusedField = .cost
            return
        }
        guard
            let vehicle = store.vehicles.first(where: { $0.id == vehicleID })
                ?? store.selectedVehicle,
            let mileageValue = Int(mileage),
            mileageValue >= 0,
            let costValue = Double(cost), costValue >= 0
        else {
            error = "Enter valid mileage and cost."
            return
        }
        isSaving = true
        store.addMaintenance(
            MaintenanceRecord(
                vehicleID: vehicle.id, type: type, date: date, mileage: mileageValue,
                cost: costValue, notes: notes, nextReminder: setReminder ? reminderDate : nil))
        dismiss()
    }
}

struct MaintenanceDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var record: MaintenanceRecord
    var body: some View {
        List {
            Section {
                Label(record.type, systemImage: "wrench.and.screwdriver.fill").font(.title3.bold())
                StatusBadge(text: record.status)
            }
            Section("Service details") {
                LabeledContent("Date", value: record.date.shortDate)
                LabeledContent("Odometer", value: "\(record.mileage.formatted()) km")
                LabeledContent("Cost", value: money(record.cost))
                LabeledContent(
                    "Vehicle",
                    value: store.vehicles.first(where: { $0.id == record.vehicleID })?.title
                        ?? "Vehicle")
            }
            Section("Notes") {
                Text(record.notes.isEmpty ? "No notes added." : record.notes)
                    .foregroundStyle(.secondary)
            }
            Section("Reminder") {
                if let date = record.nextReminder {
                    Label("Reminder set for \(date.shortDate)", systemImage: "bell.badge")
                } else {
                    Text("No reminder was set")
                }
            }
        }
        .navigationTitle("Service details").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Delete record", systemImage: "trash", role: .destructive) {
                        store.deleteMaintenance(record)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Maintenance record actions")
            }
        }
    }
}

struct FuelListView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAdd = false
    @AppStorage("smart-vehicle-fuel-range") private var timeRange = "6M"
    @State private var searchText = ""
    private let timeRanges = ["1M", "3M", "6M", "1Y", "All"]
    private var thisMonthFuel: Double {
        guard let interval = Calendar.current.dateInterval(of: .month, for: Date()) else {
            return 0
        }
        return store.selectedFuelRecords
            .filter { interval.contains($0.date) }
            .reduce(0) { $0 + $1.total }
    }
    private var averageFillUp: Double {
        let records = store.selectedFuelRecords
        guard !records.isEmpty else { return 0 }
        return records.reduce(0) { $0 + $1.total } / Double(records.count)
    }
    private var estimatedEconomy: Double? {
        let records = store.selectedFuelRecords.sorted { $0.mileage < $1.mileage }
        guard records.count > 1 else { return nil }
        var distance = 0
        var litres = 0.0
        for index in 1..<records.count {
            let travelled = records[index].mileage - records[index - 1].mileage
            if travelled > 0 {
                distance += travelled
                litres += records[index].liters
            }
        }
        guard distance > 0, litres > 0 else { return nil }
        return Double(distance) / litres
    }
    private var chartRecords: [FuelRecord] {
        let calendar = Calendar.current
        let months: Int?
        switch timeRange {
        case "1M": months = 1
        case "3M": months = 3
        case "6M": months = 6
        case "1Y": months = 12
        default: months = nil
        }
        let records = store.selectedFuelRecords
        guard let months,
            let cutoff = calendar.date(byAdding: .month, value: -months, to: Date())
        else { return records.sorted { $0.date < $1.date } }
        return records.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }
    private var visibleRecords: [FuelRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.selectedFuelRecords
            .filter {
                query.isEmpty
                    || $0.station.localizedCaseInsensitiveContains(query)
                    || $0.date.shortDate.localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.date > $1.date }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ActiveVehicleSelector().padding(.horizontal, 20)

                ActivityAddHeader(
                    title: "Fuel Management",
                    subtitle: "Track fill-ups, spending and fuel efficiency.",
                    actionTitle: "Add fuel",
                    action: { showAdd = true }
                )

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ActivityMetricCard(
                        title: "MONTHLY SPEND", value: compactMoney(thisMonthFuel),
                        detail: "Current month", symbol: "creditcard.fill", tint: .appAccent)
                    ActivityMetricCard(
                        title: "AVG. FILL-UP", value: compactMoney(averageFillUp),
                        detail: "Per record", symbol: "gauge.with.dots.needle.50percent", tint: .blue)
                    ActivityMetricCard(
                        title: "FUEL ENTRIES", value: "\(store.selectedFuelRecords.count)",
                        detail: "Total recorded", symbol: "list.bullet.rectangle", tint: .orange)
                    ActivityMetricCard(
                        title: "EST. ECONOMY",
                        value: estimatedEconomy.map { String(format: "%.1f km/L", $0) } ?? "—",
                        detail: "From odometer data", symbol: "leaf.fill", tint: .green)
                }
                .padding(.horizontal, 20)

                SurfaceCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Fuel expenditure").font(.headline)
                                Text(compactMoney(chartRecords.reduce(0) { $0 + $1.total }))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(timeRanges, id: \.self) { range in
                                    Button(range) { timeRange = range }
                                        .font(.caption2.weight(timeRange == range ? .bold : .medium))
                                        .foregroundStyle(
                                            timeRange == range ? Color.appCanvas : .secondary)
                                        .padding(.horizontal, 7).padding(.vertical, 5)
                                        .background(
                                            timeRange == range ? Color.appAccent : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                        if chartRecords.isEmpty {
                            ContentUnavailableView(
                                "No chart data", systemImage: "chart.xyaxis.line",
                                description: Text("Add a fuel record for this period."))
                                .frame(height: 150)
                        } else {
                            Chart(chartRecords) { record in
                                AreaMark(
                                    x: .value("Date", record.date),
                                    y: .value("Spend", record.total)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.appAccent.opacity(0.3), .clear],
                                        startPoint: .top, endPoint: .bottom))
                                LineMark(
                                    x: .value("Date", record.date),
                                    y: .value("Spend", record.total)
                                )
                                .foregroundStyle(Color.appAccent)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                PointMark(
                                    x: .value("Date", record.date),
                                    y: .value("Spend", record.total)
                                )
                                .foregroundStyle(Color.appAccent)
                                .symbolSize(24)
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.16))
                                    AxisValueLabel {
                                        if let amount = value.as(Double.self) {
                                            Text(compactMoney(amount)).font(.caption2)
                                        }
                                    }
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                                    AxisGridLine().foregroundStyle(.clear)
                                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                                }
                            }
                            .frame(height: 180)
                        }
                    }
                }
                .padding(.horizontal, 20)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search station or date", text: $searchText)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).frame(height: 44)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)

                HStack {
                    Text("Recent fuel records").font(.appSectionTitle)
                    Spacer()
                    Text("\(visibleRecords.count) entries")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                if visibleRecords.isEmpty {
                    EmptyStateView(
                        symbol: "fuelpump", title: "No fuel records",
                        message: searchText.isEmpty
                            ? "Add your first fill-up to see your fuel usage."
                            : "No fuel records match your search.",
                        action: searchText.isEmpty ? "Add fuel" : "Clear search"
                    ) {
                        if searchText.isEmpty { showAdd = true } else { searchText = "" }
                    }
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(visibleRecords) { record in
                            NavigationLink {
                                FuelDetailView(record: record)
                            } label: {
                                FuelRecordCard(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $showAdd) { NavigationStack { AddFuelView() } }
    }
}

private struct ActivityMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        SurfaceCard(padding: 15) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title).font(.caption2.bold()).tracking(0.55)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: symbol).font(.caption.weight(.semibold))
                        .foregroundStyle(tint).frame(width: 28, height: 28)
                        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))
                }
                Text(value).font(.title3.bold()).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.72)
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct FuelRecordCard: View {
    let record: FuelRecord

    var body: some View {
        SurfaceCard(padding: 15) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 12) {
                    Image(systemName: "fuelpump.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.appAccent).frame(width: 44, height: 44)
                        .background(Color.appMint, in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.station.isEmpty ? "Fuel fill-up" : record.station)
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        Text(record.date.shortDate).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(money(record.total)).font(.subheadline.bold()).foregroundStyle(.primary)
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Divider().overlay(Color.primary.opacity(0.06))
                HStack(spacing: 8) {
                    FuelValuePill(symbol: "drop.fill", value: "\(record.liters.formatted()) L")
                    FuelValuePill(symbol: "banknote", value: "\(money(record.pricePerLiter))/L")
                    FuelValuePill(symbol: "gauge.with.dots.needle.50percent", value: "\(record.mileage.formatted()) km")
                }
            }
        }
    }
}

private struct FuelValuePill: View {
    let symbol: String
    let value: String

    var body: some View {
        Label(value, systemImage: symbol)
            .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            .lineLimit(1).minimumScaleFactor(0.65)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Color.appElevated, in: Capsule())
    }
}

struct AddFuelView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var mileage = ""
    @State private var liters = ""
    @State private var price = ""
    @State private var station = ""
    @State private var error: String?
    @State private var didAttemptSave = false
    @State private var isSaving = false
    @FocusState private var focusedField: Field?
    private enum Field { case mileage, liters, price }
    var total: Double { (Double(liters) ?? 0) * (Double(price) ?? 0) }
    private var odometerWarning: String? {
        guard let vehicle = store.selectedVehicle, let reading = Int(mileage), reading >= 0 else {
            return nil
        }
        return store.odometerWarning(vehicleID: vehicle.id, reading: reading)
    }
    private var mileageError: String? {
        if mileage.isEmpty { return didAttemptSave ? "Odometer reading is required." : nil }
        return Int(mileage).map { $0 >= 0 } == true ? nil : "Enter a valid odometer reading."
    }
    private var litersError: String? {
        if liters.isEmpty { return didAttemptSave ? "Fuel quantity is required." : nil }
        return Double(liters).map { $0 > 0 } == true ? nil : "Fuel quantity must be greater than zero."
    }
    private var priceError: String? {
        if price.isEmpty { return didAttemptSave ? "Price per litre is required." : nil }
        return Double(price).map { $0 > 0 } == true ? nil : "Price must be greater than zero."
    }
    var body: some View {
        Form {
            Section {
                LabeledContent("Vehicle", value: store.selectedVehicle?.title ?? "No vehicle selected")
                LabeledContent(
                    "Current reading",
                    value: "\(store.selectedVehicle?.mileage.formatted() ?? "—") km")
                TextField("Odometer (km)", text: $mileage).keyboardType(.numberPad)
                    .focused($focusedField, equals: .mileage)
            } header: {
                Text("Odometer")
            } footer: {
                if let mileageError { InlineValidationMessage(message: mileageError) }
                else if let odometerWarning {
                    Label(odometerWarning, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Text("A higher reading updates the Dashboard. Older readings stay in fuel history.")
                }
            }
            Section {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Fuel quantity (L)", text: $liters).keyboardType(.decimalPad)
                    .focused($focusedField, equals: .liters)
                TextField("Price per litre (LKR)", text: $price).keyboardType(.decimalPad)
                    .focused($focusedField, equals: .price)
                TextField("Station (optional)", text: $station)
                LabeledContent("Total", value: money(total))
                    .fontWeight(.semibold)
            } header: {
                Text("Fill-up")
            } footer: {
                if let litersError { InlineValidationMessage(message: litersError) }
                if let priceError { InlineValidationMessage(message: priceError) }
            }
            if let error { Text(error).foregroundStyle(.red) }
            Section {
                Button(isSaving ? "Saving…" : "Save fuel record") { save() }
                    .disabled(isSaving || mileage.isEmpty || liters.isEmpty || price.isEmpty)
            }
        }
        .navigationTitle("Add fuel").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
    }
    private func save() {
        guard !isSaving else { return }
        didAttemptSave = true
        if mileageError != nil { focusedField = .mileage; return }
        if litersError != nil { focusedField = .liters; return }
        if priceError != nil { focusedField = .price; return }
        guard let vehicle = store.selectedVehicle, let mileageValue = Int(mileage),
            mileageValue >= 0,
            let litersValue = Double(liters), let priceValue = Double(price), litersValue > 0,
            priceValue > 0
        else {
            error = "Enter valid odometer, quantity, and price."
            return
        }
        isSaving = true
        store.addFuel(
            FuelRecord(
                vehicleID: vehicle.id, date: date, mileage: mileageValue, liters: litersValue,
                pricePerLiter: priceValue, station: station))
        dismiss()
    }
}

struct FuelDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var record: FuelRecord
    var body: some View {
        List {
            Section { Label("Fuel fill-up", systemImage: "fuelpump.fill").font(.title3.bold()) }
            Section("Details") {
                LabeledContent("Date", value: record.date.shortDate)
                LabeledContent("Odometer", value: "\(record.mileage.formatted()) km")
                LabeledContent("Fuel quantity", value: "\(record.liters.formatted()) L")
                LabeledContent("Price per litre", value: money(record.pricePerLiter))
                LabeledContent("Total", value: money(record.total))
                if !record.station.isEmpty { LabeledContent("Station", value: record.station) }
            }
        }
        .navigationTitle("Fuel details").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Delete record", systemImage: "trash", role: .destructive) {
                        store.deleteFuelRecord(record)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Fuel record actions")
            }
        }
    }
}

struct ExpenseListView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAdd = false
    private var totalExpenses: Double {
        store.selectedExpenses.reduce(0) { $0 + $1.amount }
    }
    private var thisMonthExpenses: Double {
        guard let interval = Calendar.current.dateInterval(of: .month, for: Date()) else { return 0 }
        return store.selectedExpenses.filter { interval.contains($0.date) }
            .reduce(0) { $0 + $1.amount }
    }
    private var largestExpense: ExpenseRecord? {
        store.selectedExpenses.max { $0.amount < $1.amount }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ActiveVehicleSelector().padding(.horizontal, 20)
                ActivityAddHeader(
                    title: "Expenses",
                    subtitle: "Track every vehicle-related payment.",
                    actionTitle: "Add expense",
                    action: { showAdd = true }
                )
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ActivityMetricCard(
                        title: "THIS MONTH", value: compactMoney(thisMonthExpenses),
                        detail: "Other expenses", symbol: "calendar", tint: .blue)
                    ActivityMetricCard(
                        title: "TOTAL SPEND", value: compactMoney(totalExpenses),
                        detail: "All recorded", symbol: "creditcard.fill", tint: .purple)
                    ActivityMetricCard(
                        title: "EXPENSE ENTRIES", value: "\(store.selectedExpenses.count)",
                        detail: "Total recorded", symbol: "list.bullet.rectangle", tint: .appAccent)
                    ActivityMetricCard(
                        title: "LARGEST EXPENSE",
                        value: largestExpense.map { compactMoney($0.amount) } ?? "—",
                        detail: largestExpense?.title ?? "No expenses recorded",
                        symbol: "arrow.up.right", tint: .orange)
                }
                .padding(.horizontal, 20)
                ActivitySpendTrendChart(
                    title: "Expense trend",
                    subtitle: "Last six months",
                    points: activityMonthlySpending(
                        store.selectedExpenses.map {
                            ActivityDatedAmount(date: $0.date, amount: $0.amount)
                        }
                    ),
                    tint: .blue
                )
                .padding(.horizontal, 20)
                ExpenseBreakdownChart().padding(.horizontal, 20)
                SectionHeading(title: "Expense history").padding(.horizontal, 20)
                if store.selectedExpenses.isEmpty {
                    EmptyStateView(
                        symbol: "creditcard", title: "No expenses yet",
                        message: "Track insurance, parking, parts, and more."
                    )
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(store.selectedExpenses) { record in
                            NavigationLink {
                                ExpenseDetailView(record: record)
                            } label: {
                                SurfaceCard(padding: 14) {
                                    RecordRow(
                                        symbol: ExpenseCategory(rawValue: record.category)?.symbol
                                            ?? "ellipsis.circle.fill",
                                        tint: Color.forName(
                                            ExpenseCategory(rawValue: record.category)?.tint
                                                ?? "gray"), title: record.title,
                                        subtitle: "\(record.date.shortDate) · \(record.category)",
                                        amount: money(record.amount))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $showAdd) { NavigationStack { AddExpenseView() } }
    }
}

private struct ActivityAddHeader: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.appScreenTitle)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(action: action) {
                Label(actionTitle, systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appCanvas)
                    .padding(.horizontal, 13)
                    .frame(minHeight: 44)
                    .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(actionTitle)
        }
        .padding(.horizontal, 20)
    }
}

struct AddExpenseView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category = ExpenseCategory.other.rawValue
    @State private var amount = ""
    @State private var mileage = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var error: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var receiptData: Data?
    @State private var receiptPreview: UIImage?
    @State private var showReceiptActions = false
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    @State private var isSaving = false
    @State private var didAttemptSave = false
    @FocusState private var focusedField: Field?
    private enum Field { case title, amount, mileage }
    private var odometerWarning: String? {
        guard let vehicle = store.selectedVehicle, !mileage.isEmpty,
            let reading = Int(mileage), reading >= 0
        else { return nil }
        return store.odometerWarning(vehicleID: vehicle.id, reading: reading)
    }
    private var titleError: String? {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty && (didAttemptSave || !title.isEmpty)
            ? "A description is required." : nil
    }
    private var amountError: String? {
        if amount.isEmpty { return didAttemptSave ? "Amount is required." : nil }
        return Double(amount).map { $0 > 0 } == true ? nil : "Amount must be greater than zero."
    }
    private var mileageError: String? {
        guard !mileage.isEmpty else { return nil }
        return Int(mileage).map { $0 >= 0 } == true ? nil : "Enter a valid odometer reading."
    }
    var body: some View {
        Form {
            Section {
                LabeledContent("Vehicle", value: store.selectedVehicle?.title ?? "No vehicle selected")
                TextField("Description", text: $title)
                    .focused($focusedField, equals: .title)
                Picker("Category", selection: $category) {
                    ForEach(ExpenseCategory.allCases.filter { $0 != .fuel && $0 != .maintenance }) {
                        Text($0.rawValue).tag($0.rawValue)
                    }
                }
                TextField("Amount (LKR)", text: $amount).keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                LabeledContent(
                    "Current reading",
                    value: "\(store.selectedVehicle?.mileage.formatted() ?? "—") km")
                TextField("Odometer (km, optional)", text: $mileage).keyboardType(.numberPad)
                    .focused($focusedField, equals: .mileage)
                TextField("Notes", text: $notes, axis: .vertical)
            } header: {
                Text("Expense")
            } footer: {
                if let titleError { InlineValidationMessage(message: titleError) }
                if let amountError { InlineValidationMessage(message: amountError) }
                if let mileageError { InlineValidationMessage(message: mileageError) }
                else if let odometerWarning {
                    Label(odometerWarning, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            Section("Receipt") {
                Button {
                    showReceiptActions = true
                } label: {
                    Label(
                        receiptData == nil ? "Add receipt photo" : "Change receipt photo",
                        systemImage: "receipt")
                }
                if let receiptPreview {
                    Image(uiImage: receiptPreview).resizable().scaledToFit()
                        .frame(maxHeight: 220)
                    Button("Remove receipt", role: .destructive) {
                        receiptData = nil
                        self.receiptPreview = nil
                    }
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
            Section {
                Button(isSaving ? "Saving…" : "Save expense") { save() }
                    .disabled(isSaving || title.isEmpty || amount.isEmpty)
            }
        }
        .navigationTitle("Add expense").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        .confirmationDialog("Receipt photo", isPresented: $showReceiptActions) {
            Button("Choose photo") { showPhotoLibrary = true }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take photo") { showCamera = true }
            }
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $selectedPhoto, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPhotoPicker { data in
                showCamera = false
                if let data { setReceiptPreview(data) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw PhotoProcessing.Error.invalidImage
                    }
                    setReceiptPreview(data)
                } catch { self.error = error.localizedDescription }
                selectedPhoto = nil
            }
        }
    }

    private func setReceiptPreview(_ data: Data) {
        guard let image = UIImage(data: data) else {
            error = PhotoProcessing.Error.invalidImage.localizedDescription
            return
        }
        receiptData = data
        receiptPreview = image
        error = nil
    }

    private func save() {
        guard !isSaving else { return }
        didAttemptSave = true
        if titleError != nil { focusedField = .title; return }
        if amountError != nil { focusedField = .amount; return }
        if mileageError != nil { focusedField = .mileage; return }
        guard let vehicle = store.selectedVehicle, let amountValue = Double(amount), amountValue > 0
        else {
            error = "Enter a valid amount."
            return
        }
        let expenseMileage: Int
        if mileage.isEmpty {
            expenseMileage = vehicle.mileage
        } else if let value = Int(mileage), value >= 0 {
            expenseMileage = value
        } else {
            error = "Enter a valid odometer reading or leave it empty."
            return
        }
        isSaving = true
        Task {
            var record = ExpenseRecord(
                vehicleID: vehicle.id, title: title, category: category, date: date,
                mileage: expenseMileage, amount: amountValue, notes: notes)
            do {
                if let receiptData {
                    try await store.setExpenseReceipt(receiptData, expenseID: record.id)
                    record.hasReceipt = true
                }
                store.addExpense(record)
                dismiss()
            } catch {
                self.error = error.localizedDescription
                isSaving = false
            }
        }
    }
}

struct ExpenseDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var record: ExpenseRecord
    var body: some View {
        List {
            Section {
                Label(
                    record.title,
                    systemImage: ExpenseCategory(rawValue: record.category)?.symbol
                        ?? "creditcard.fill"
                )
                .font(.title3.bold())
            }
            Section("Details") {
                LabeledContent("Category", value: record.category)
                LabeledContent("Date", value: record.date.shortDate)
                LabeledContent("Amount", value: money(record.amount))
                LabeledContent("Odometer", value: "\(record.mileage.formatted()) km")
            }
            Section("Notes") {
                Text(record.notes.isEmpty ? "No notes added." : record.notes)
                    .foregroundStyle(.secondary)
            }
            if record.hasReceipt == true {
                Section("Receipt photo") {
                    if let image = store.expenseReceiptPhotos[record.id] {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Loading receipt photo, or it may only be on the device where it was added.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Expense details").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if record.hasReceipt == true { store.refreshExpenseReceipt(record.id) }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Delete expense", systemImage: "trash", role: .destructive) {
                        store.deleteExpense(record)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Expense actions")
            }
        }
    }
}

private struct BillEntry: Identifiable {
    enum Source {
        case expense(ExpenseRecord)
        case fuel(FuelRecord)
        case maintenance(MaintenanceRecord)
    }

    let source: Source
    var id: String {
        switch source {
        case .expense(let record): "expense-\(record.id.uuidString)"
        case .fuel(let record): "fuel-\(record.id.uuidString)"
        case .maintenance(let record): "maintenance-\(record.id.uuidString)"
        }
    }
    var vehicleID: UUID {
        switch source {
        case .expense(let record): record.vehicleID
        case .fuel(let record): record.vehicleID
        case .maintenance(let record): record.vehicleID
        }
    }
    var date: Date {
        switch source {
        case .expense(let record): record.date
        case .fuel(let record): record.date
        case .maintenance(let record): record.date
        }
    }
    var title: String {
        switch source {
        case .expense(let record): record.title
        case .fuel(let record): record.station.isEmpty ? "Fuel fill-up" : record.station
        case .maintenance(let record): record.type
        }
    }
    var amount: Double {
        switch source {
        case .expense(let record): record.amount
        case .fuel(let record): record.total
        case .maintenance(let record): record.cost
        }
    }
    var category: String {
        switch source {
        case .expense: "Expense"
        case .fuel: "Fuel"
        case .maintenance: "Maintenance"
        }
    }
}

struct BillsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedVehicleID: UUID?
    @AppStorage("smart-vehicle-bills-category") private var selectedCategory = "All"

    private var bills: [BillEntry] {
        let entries = store.expenses.map { BillEntry(source: .expense($0)) }
            + store.fuelRecords.map { BillEntry(source: .fuel($0)) }
            + store.maintenance.map { BillEntry(source: .maintenance($0)) }
        return entries.filter { entry in
            (selectedVehicleID == nil || entry.vehicleID == selectedVehicleID)
                && (selectedCategory == "All" || entry.category == selectedCategory)
        }
        .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeading(title: "Bills & spending", subtitle: "Records across your vehicles")
                Picker("Vehicle", selection: $selectedVehicleID) {
                    Text("All vehicles").tag(UUID?.none)
                    ForEach(store.vehicles) { vehicle in
                        Text(vehicle.title).tag(Optional(vehicle.id))
                    }
                }
                .pickerStyle(.menu).padding(.horizontal, 20)
                Picker("Type", selection: $selectedCategory) {
                    ForEach(["All", "Expense", "Fuel", "Maintenance"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .pickerStyle(.segmented).padding(.horizontal, 20)
                HStack {
                    SectionHeading(title: "Your records")
                    Spacer()
                    Text("\(bills.count) entries · \(money(bills.reduce(0) { $0 + $1.amount }))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                if bills.isEmpty {
                    EmptyStateView(
                        symbol: "receipt", title: "No bills or spending yet",
                        message: "Add fuel, maintenance, or expense records to see them here.")
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(bills) { entry in
                            NavigationLink {
                                switch entry.source {
                                case .expense(let record): ExpenseDetailView(record: record)
                                case .fuel(let record): FuelDetailView(record: record)
                                case .maintenance(let record): MaintenanceDetailView(record: record)
                                }
                            } label: {
                                SurfaceCard(padding: 14) {
                                    RecordRow(
                                        symbol: "receipt.fill", tint: Color.appAccent,
                                        title: entry.title,
                                        subtitle: "\(store.vehicles.first(where: { $0.id == entry.vehicleID })?.registration ?? "Vehicle") · \(entry.category) · \(entry.date.shortDate)",
                                        amount: money(entry.amount))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appCanvas.ignoresSafeArea())
        .navigationTitle("Bills & spending").navigationBarTitleDisplayMode(.inline)
    }
}

struct ExpenseBreakdownChart: View {
    @EnvironmentObject private var store: AppStore
    private var values: [(String, Double)] {
        let now = Date()
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        var pairs: [(String, Double)] = ExpenseCategory.allCases.map { category in
            let total: Double =
                switch category {
                case .fuel:
                    store.selectedFuelRecords.filter { $0.date >= cutoff && $0.date <= now }
                        .reduce(0) { $0 + $1.total }
                case .maintenance:
                    store.selectedVehicleRecords.filter { $0.date >= cutoff && $0.date <= now }
                        .reduce(0) { $0 + $1.cost }
                default:
                    store.selectedExpenses.filter {
                        $0.category == category.rawValue && $0.date >= cutoff && $0.date <= now
                    }
                        .reduce(0) { $0 + $1.amount }
                }
            return (category.rawValue, total)
        }
        pairs.removeAll { $0.1 == 0 }
        return pairs
    }
    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Spending by category").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("Last 30 days").font(.caption).foregroundStyle(.secondary)
                }
                if values.isEmpty {
                    Text("Add records to see your spending breakdown.").font(.caption)
                        .foregroundStyle(.secondary).frame(height: 90).frame(maxWidth: .infinity)
                } else {
                    Chart(values, id: \.0) { item in
                        SectorMark(
                            angle: .value("Spend", item.1), innerRadius: .ratio(0.62),
                            angularInset: 3
                        )
                        .foregroundStyle(
                            Color.forName(ExpenseCategory(rawValue: item.0)?.tint ?? "gray")
                        )
                        .cornerRadius(4)
                    }
                    .frame(height: 155)
                    .overlay {
                        VStack(spacing: 2) {
                            Text(compactMoney(values.reduce(0) { $0 + $1.1 }))
                                .font(.headline.bold())
                            Text("TOTAL").font(.caption2).tracking(1).foregroundStyle(.secondary)
                        }
                    }
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        alignment: .leading, spacing: 10
                    ) {
                        ForEach(values, id: \.0) { item in
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(
                                        Color.forName(
                                            ExpenseCategory(rawValue: item.0)?.tint ?? "gray")
                                    )
                                    .frame(width: 8, height: 8)
                                Text(item.0).font(.caption).foregroundStyle(.secondary)
                                Spacer(minLength: 2)
                                Text(compactMoney(item.1)).font(.caption.weight(.semibold))
                            }
                        }
                    }
                }
            }
        }
    }
}

extension Color {
    static func forName(_ name: String) -> Color {
        switch name {
        case "orange": .orange
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        case "teal": .teal
        case "appAccent": .appAccent
        case "red": .red
        default: .gray
        }
    }
}
