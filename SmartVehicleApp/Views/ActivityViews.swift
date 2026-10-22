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
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 11) {
                    MetricTile(
                        title: "This month", value: compactMoney(store.totalExpenses),
                        detail: "All categories", symbol: "creditcard.fill", tint: .blue)
                    MetricTile(
                        title: "Fuel", value: compactMoney(store.totalFuel),
                        detail: "\(store.selectedFuelRecords.count) fill-ups",
                        symbol: "fuelpump.fill")
                }
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

struct MaintenanceListView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAdd = false
    @State private var filter = "All"
    private var records: [MaintenanceRecord] {
        filter == "All"
            ? store.selectedVehicleRecords
            : store.selectedVehicleRecords.filter {
                $0.type.localizedCaseInsensitiveContains(filter)
            }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SurfaceCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("NEXT SERVICE").font(.caption2.weight(.bold)).tracking(1)
                                .foregroundStyle(.secondary)
                            Text(store.selectedVehicle?.nextServiceMileage ?? 0, format: .number)
                                .font(.system(size: 27, weight: .bold, design: .rounded))
                                + Text(" km").font(.headline).foregroundColor(.secondary)
                            Text(
                                "\(store.selectedVehicle?.nextServiceDate.shortDate ?? "") · Oil & filter"
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
                        message: "Keep a complete history of maintenance and repairs.",
                        action: "Add maintenance"
                    ) { showAdd = true }
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
        .overlay(alignment: .bottomTrailing) {
            Button {
                showAdd = true
            } label: {
                Image(systemName: "plus").font(.title3.bold()).foregroundStyle(.white)
                    .frame(width: 54, height: 54).background(Color.appAccent, in: Circle())
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
            }
            .accessibilityLabel("Add maintenance record")
            .padding(22)
        }
        .sheet(isPresented: $showAdd) { NavigationStack { AddMaintenanceView() } }
    }
}

struct AddMaintenanceView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var type = "Oil & filter change"
    @State private var date = Date()
    @State private var mileage = ""
    @State private var cost = ""
    @State private var notes = ""
    @State private var setReminder = true
    @State private var reminderDate =
        Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var error: String?
    private let types = [
        "Oil & filter change", "Tire rotation", "Brake service", "Battery", "Inspection", "Repair",
        "Other",
    ]
    var body: some View {
        Form {
            Section("Service") {
                Picker("Service type", selection: $type) { ForEach(types, id: \.self) { Text($0) } }
                DatePicker("Service date", selection: $date, displayedComponents: .date)
                TextField("Odometer (km)", text: $mileage).keyboardType(.numberPad)
                TextField("Cost (LKR)", text: $cost).keyboardType(.decimalPad)
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
            }
            Section("Reminder") {
                Toggle("Set next reminder", isOn: $setReminder)
                if setReminder {
                    DatePicker(
                        "Remind me on", selection: $reminderDate, in: Date()...,
                        displayedComponents: .date)
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
            Section {
                Button("Save maintenance") { save() }.disabled(mileage.isEmpty || cost.isEmpty)
            }
        }
        .navigationTitle("Add maintenance").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
    }
    private func save() {
        guard let vehicle = store.selectedVehicle, let mileageValue = Int(mileage),
            let costValue = Double(cost)
        else {
            error = "Enter valid mileage and cost."
            return
        }
        store.addMaintenance(
            MaintenanceRecord(
                vehicleID: vehicle.id, type: type, date: date, mileage: mileageValue,
                cost: costValue, notes: notes, nextReminder: setReminder ? reminderDate : nil))
        dismiss()
    }
}

struct MaintenanceDetailView: View {
    @EnvironmentObject private var store: AppStore
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
                LabeledContent("Vehicle", value: store.selectedVehicle?.title ?? "Vehicle")
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
    }
}

struct FuelListView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAdd = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 11) {
                    MetricTile(
                        title: "Fuel this month", value: compactMoney(store.totalFuel),
                        detail: "Across all fill-ups", symbol: "fuelpump.fill")
                    MetricTile(
                        title: "Fill-ups", value: "\(store.selectedFuelRecords.count)",
                        detail: "Recorded", symbol: "drop.fill", tint: .blue)
                }
                .padding(.horizontal, 20)
                SectionHeading(title: "Fuel history").padding(.horizontal, 20)
                if store.selectedFuelRecords.isEmpty {
                    EmptyStateView(
                        symbol: "fuelpump", title: "No fuel records",
                        message: "Add your first fill-up to see your fuel usage.",
                        action: "Add fuel"
                    ) { showAdd = true }
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(store.selectedFuelRecords) { record in
                            NavigationLink {
                                FuelDetailView(record: record)
                            } label: {
                                SurfaceCard(padding: 14) {
                                    RecordRow(
                                        symbol: "fuelpump.fill", tint: .appAccent,
                                        title: record.station.isEmpty
                                            ? "Fuel fill-up" : record.station,
                                        subtitle:
                                            "\(record.date.shortDate) · \(record.liters.formatted()) L · \(record.mileage.formatted()) km",
                                        amount: money(record.total))
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
        .overlay(alignment: .bottomTrailing) {
            Button {
                showAdd = true
            } label: {
                Image(systemName: "plus").font(.title3.bold()).foregroundStyle(.white)
                    .frame(width: 54, height: 54).background(Color.appAccent, in: Circle())
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
            }
            .accessibilityLabel("Add fuel record")
            .padding(22)
        }
        .sheet(isPresented: $showAdd) { NavigationStack { AddFuelView() } }
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
    var total: Double { (Double(liters) ?? 0) * (Double(price) ?? 0) }
    var body: some View {
        Form {
            Section {
                LabeledContent(
                    "Current reading",
                    value: "\(store.selectedVehicle?.mileage.formatted() ?? "—") km")
                TextField("Odometer (km)", text: $mileage).keyboardType(.numberPad)
            } header: {
                Text("Odometer")
            } footer: {
                Text("A higher reading updates the Dashboard. Older readings stay in fuel history.")
            }
            Section("Fill-up") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Fuel quantity (L)", text: $liters).keyboardType(.decimalPad)
                TextField("Price per litre (LKR)", text: $price).keyboardType(.decimalPad)
                TextField("Station (optional)", text: $station)
                LabeledContent("Total", value: money(total))
                    .fontWeight(.semibold)
            }
            if let error { Text(error).foregroundStyle(.red) }
            Section {
                Button("Save fuel record") { save() }
                    .disabled(mileage.isEmpty || liters.isEmpty || price.isEmpty)
            }
        }
        .navigationTitle("Add fuel").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
    }
    private func save() {
        guard let vehicle = store.selectedVehicle, let mileageValue = Int(mileage),
            mileageValue >= 0,
            let litersValue = Double(liters), let priceValue = Double(price), litersValue > 0,
            priceValue > 0
        else {
            error = "Enter valid odometer, quantity, and price."
            return
        }
        store.addFuel(
            FuelRecord(
                vehicleID: vehicle.id, date: date, mileage: mileageValue, liters: litersValue,
                pricePerLiter: priceValue, station: station))
        dismiss()
    }
}

struct FuelDetailView: View {
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
    }
}

struct ExpenseListView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAdd = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 11) {
                    MetricTile(
                        title: "Other expenses",
                        value: compactMoney(store.selectedExpenses.reduce(0) { $0 + $1.amount }),
                        detail: "All categories", symbol: "creditcard.fill", tint: .blue)
                    MetricTile(
                        title: "Entries", value: "\(store.selectedExpenses.count)",
                        detail: "Recorded", symbol: "list.bullet.rectangle")
                }
                .padding(.horizontal, 20)
                ExpenseBreakdownChart().padding(.horizontal, 20)
                SectionHeading(title: "Expense history").padding(.horizontal, 20)
                if store.selectedExpenses.isEmpty {
                    EmptyStateView(
                        symbol: "creditcard", title: "No expenses yet",
                        message: "Track insurance, parking, parts, and more.", action: "Add expense"
                    ) { showAdd = true }
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
        .overlay(alignment: .bottomTrailing) {
            Button {
                showAdd = true
            } label: {
                Image(systemName: "plus").font(.title3.bold()).foregroundStyle(.white)
                    .frame(width: 54, height: 54).background(Color.appAccent, in: Circle())
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
            }
            .accessibilityLabel("Add expense")
            .padding(22)
        }
        .sheet(isPresented: $showAdd) { NavigationStack { AddExpenseView() } }
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
    var body: some View {
        Form {
            Section("Expense") {
                TextField("Description", text: $title)
                Picker("Category", selection: $category) {
                    ForEach(ExpenseCategory.allCases.filter { $0 != .fuel && $0 != .maintenance }) {
                        Text($0.rawValue).tag($0.rawValue)
                    }
                }
                TextField("Amount (LKR)", text: $amount).keyboardType(.decimalPad)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Odometer (km, optional)", text: $mileage).keyboardType(.numberPad)
                TextField("Notes", text: $notes, axis: .vertical)
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
        guard let vehicle = store.selectedVehicle, let amountValue = Double(amount), amountValue > 0
        else {
            error = "Enter a valid amount."
            return
        }
        isSaving = true
        Task {
            var record = ExpenseRecord(
                vehicleID: vehicle.id, title: title, category: category, date: date,
                mileage: Int(mileage) ?? vehicle.mileage, amount: amountValue, notes: notes)
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
    @State private var selectedCategory = "All"

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
        var pairs: [(String, Double)] = ExpenseCategory.allCases.map { category in
            let total: Double =
                switch category {
                case .fuel: store.totalFuel
                case .maintenance: store.selectedVehicleRecords.reduce(0) { $0 + $1.cost }
                default:
                    store.selectedExpenses.filter { $0.category == category.rawValue }
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
