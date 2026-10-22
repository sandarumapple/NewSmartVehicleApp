import Foundation

/// Read-only dashboard logic, independent of SwiftUI and persistence.
struct DashboardViewModel {
    let vehicle: Vehicle?
    let maintenance: [MaintenanceRecord]
    let fuelRecords: [FuelRecord]
    let expenses: [ExpenseRecord]
    let documents: [VehicleDocument]
    let now: Date
    let calendar: Calendar

    init(
        vehicle: Vehicle?, maintenance: [MaintenanceRecord], fuelRecords: [FuelRecord],
        expenses: [ExpenseRecord], documents: [VehicleDocument],
        now: Date, calendar: Calendar = .current
    ) {
        self.vehicle = vehicle
        self.maintenance = maintenance
        self.fuelRecords = fuelRecords
        self.expenses = expenses
        self.documents = documents
        self.now = now
        self.calendar = calendar
    }

    private var selectedID: UUID? { vehicle?.id }

    var attentionDocuments: [VehicleDocument] {
        documents.filter {
            $0.vehicleID == selectedID
                && $0.expiryDate <= now.addingTimeInterval(30 * 24 * 60 * 60)
        }
        .sorted { $0.expiryDate < $1.expiryDate }
    }

    var serviceNeedsAttention: Bool {
        guard let vehicle else { return false }
        return vehicle.distanceToService <= 1_000
            || vehicle.nextServiceDate <= now.addingTimeInterval(30 * 24 * 60 * 60)
    }

    var thisMonthExpenses: Double {
        let inMonth: (Date) -> Bool = {
            calendar.isDate($0, equalTo: now, toGranularity: .month)
        }
        let other = expenses.filter { $0.vehicleID == selectedID && inMonth($0.date) }
            .reduce(0) { $0 + $1.amount }
        let fuel = fuelRecords.filter { $0.vehicleID == selectedID && inMonth($0.date) }
            .reduce(0) { $0 + $1.total }
        let services = maintenance.filter { $0.vehicleID == selectedID && inMonth($0.date) }
            .reduce(0) { $0 + $1.cost }
        return other + fuel + services
    }

    var nextReminder: Date? {
        let selectedServices = maintenance.filter { $0.vehicleID == selectedID }
        let selectedDocuments = documents.filter { $0.vehicleID == selectedID }
        return
            ([vehicle?.nextServiceDate] + selectedServices.map(\.nextReminder)
            + selectedDocuments.map { $0.expiryDate })
            .compactMap { $0 }
            .filter { $0 >= now }
            .min()
    }
}
