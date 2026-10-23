import Foundation

enum AnalyticsRange: String, CaseIterable, Identifiable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "All"

    var id: String { rawValue }
    var monthCount: Int? {
        switch self {
        case .oneMonth: 1
        case .threeMonths: 3
        case .sixMonths: 6
        case .oneYear: 12
        case .all: nil
        }
    }
    var title: String {
        switch self {
        case .oneMonth: "Last month"
        case .threeMonths: "Last 3 months"
        case .sixMonths: "Last 6 months"
        case .oneYear: "Last year"
        case .all: "All time"
        }
    }
}

enum AnalyticsCategory: String, CaseIterable, Identifiable {
    case fuel = "Fuel"
    case maintenance = "Maintenance"
    case other = "Other"

    var id: String { rawValue }
    var title: String { self == .other ? "Other expenses" : rawValue }
}

struct AnalyticsTransaction {
    let date: Date
    let amount: Double
    let category: AnalyticsCategory
}

struct SpendingBucket: Identifiable {
    let date: Date
    let amount: Double
    var id: Date { date }
}

struct MileageReading: Identifiable {
    let date: Date
    let mileage: Int
    var id: Date { date }
}

struct FuelEfficiencyReading: Identifiable {
    let date: Date
    let mileage: Int
    let distance: Int
    let liters: Double
    let kilometresPerLiter: Double

    var id: String { "\(date.timeIntervalSinceReferenceDate)-\(mileage)" }
}

/// A pure projection of vehicle records. The SwiftUI view owns only selection state and rendering.
struct AnalyticsViewModel {
    let vehicle: Vehicle?
    let fuelRecords: [FuelRecord]
    let maintenance: [MaintenanceRecord]
    let expenses: [ExpenseRecord]
    let range: AnalyticsRange
    let selectedCategory: String
    let now: Date
    let calendar: Calendar

    init(
        vehicle: Vehicle?, fuelRecords: [FuelRecord], maintenance: [MaintenanceRecord],
        expenses: [ExpenseRecord], range: AnalyticsRange, selectedCategory: String,
        now: Date, calendar: Calendar = .current
    ) {
        self.vehicle = vehicle
        self.fuelRecords = fuelRecords
        self.maintenance = maintenance
        self.expenses = expenses
        self.range = range
        self.selectedCategory = selectedCategory
        self.now = now
        self.calendar = calendar
    }

    var periodStart: Date? {
        range.monthCount.flatMap { calendar.date(byAdding: .month, value: -$0, to: now) }
    }

    var transactions: [AnalyticsTransaction] {
        guard let vehicleID = vehicle?.id else { return [] }
        let fuel = fuelRecords.filter { $0.vehicleID == vehicleID }
            .map { AnalyticsTransaction(date: $0.date, amount: $0.total, category: .fuel) }
        let services = maintenance.filter { $0.vehicleID == vehicleID }
            .map { AnalyticsTransaction(date: $0.date, amount: $0.cost, category: .maintenance) }
        let other = expenses.filter { $0.vehicleID == vehicleID }
            .map { AnalyticsTransaction(date: $0.date, amount: $0.amount, category: .other) }
        return (fuel + services + other).filter { $0.date <= now }
    }

    var periodTransactions: [AnalyticsTransaction] {
        guard let periodStart else { return transactions }
        return transactions.filter { $0.date >= periodStart }
    }

    var selectedTransactions: [AnalyticsTransaction] {
        periodTransactions.filter {
            selectedCategory == "All" || $0.category.rawValue == selectedCategory
        }
    }

    var totalSpending: Double { periodTransactions.reduce(0) { $0 + $1.amount } }

    var analysedMonthCount: Int {
        if let months = range.monthCount { return max(1, months) }
        guard let earliest = periodTransactions.map(\.date).min() else { return 1 }
        let start = calendar.dateInterval(of: .month, for: earliest)?.start ?? earliest
        let end = calendar.dateInterval(of: .month, for: now)?.start ?? now
        return max(1, (calendar.dateComponents([.month], from: start, to: end).month ?? 0) + 1)
    }

    var averageMonthlySpending: Double {
        totalSpending / Double(analysedMonthCount)
    }

    var estimatedAnnualSpending: Double {
        averageMonthlySpending * 12
    }

    func total(for category: AnalyticsCategory) -> Double {
        periodTransactions.filter { $0.category == category }.reduce(0) { $0 + $1.amount }
    }

    var previousSpending: Double? {
        guard let months = range.monthCount, let start = periodStart,
            let previousStart = calendar.date(byAdding: .month, value: -months, to: start)
        else { return nil }
        return transactions.filter { $0.date >= previousStart && $0.date < start }
            .reduce(0) { $0 + $1.amount }
    }

    var comparisonText: String {
        guard let previousSpending else { return "Across all records" }
        guard previousSpending > 0 else { return "No prior-period spending" }
        let change = (totalSpending - previousSpending) / previousSpending * 100
        return "\(change >= 0 ? "Up" : "Down") \(Int(abs(change).rounded()))% vs prior period"
    }

    var bucketComponent: Calendar.Component {
        if range == .oneMonth { return .weekOfYear }
        if range == .all, let earliest = transactions.map(\.date).min(),
            calendar.dateComponents([.month], from: earliest, to: now).month ?? 0 > 24
        {
            return .year
        }
        return .month
    }

    var spendingBuckets: [SpendingBucket] {
        guard let earliest = selectedTransactions.map(\.date).min(),
            let first = calendar.dateInterval(of: bucketComponent, for: periodStart ?? earliest)?
                .start
        else { return [] }
        var buckets: [SpendingBucket] = []
        var date = first
        while date <= now {
            guard let next = calendar.date(byAdding: bucketComponent, value: 1, to: date)
            else { break }
            let amount = selectedTransactions.filter { $0.date >= date && $0.date < next }
                .reduce(0) { $0 + $1.amount }
            buckets.append(SpendingBucket(date: date, amount: amount))
            date = next
        }
        return buckets
    }

    var mileageReadings: [MileageReading] {
        guard let vehicle else { return [] }
        var byDay: [Date: Int] = [:]
        let records =
            fuelRecords.filter { $0.vehicleID == vehicle.id }
            .map { ($0.date, $0.mileage) }
            + maintenance.filter { $0.vehicleID == vehicle.id }
            .map { ($0.date, $0.mileage) }
            + expenses.filter { $0.vehicleID == vehicle.id }
            .map { ($0.date, $0.mileage) }
        for (date, mileage) in records where date <= now && mileage >= 0 {
            let day = calendar.startOfDay(for: date)
            byDay[day] = max(byDay[day] ?? 0, mileage)
        }
        let today = calendar.startOfDay(for: now)
        byDay[today] = max(byDay[today] ?? 0, vehicle.mileage)
        let readings = byDay.map { MileageReading(date: $0.key, mileage: $0.value) }
            .sorted { $0.date < $1.date }
        guard let periodStart else { return readings }
        return readings.filter { $0.date >= calendar.startOfDay(for: periodStart) }
    }

    var recordedDistance: Int? {
        guard let first = mileageReadings.first, let last = mileageReadings.last,
            first.date < last.date, last.mileage > first.mileage
        else { return nil }
        return last.mileage - first.mileage
    }

    var costPerKilometre: String {
        guard let recordedDistance else { return "—" }
        return (totalSpending / Double(recordedDistance))
            .formatted(.currency(code: "LKR").precision(.fractionLength(2)))
    }

    var fuelEfficiencyReadings: [FuelEfficiencyReading] {
        guard let vehicleID = vehicle?.id else { return [] }
        let records = fuelRecords
            .filter { $0.vehicleID == vehicleID && $0.date <= now && $0.liters > 0 }
            .sorted {
                if $0.date == $1.date { return $0.mileage < $1.mileage }
                return $0.date < $1.date
            }
        guard records.count >= 2 else { return [] }

        return zip(records, records.dropFirst()).compactMap { previous, current in
            let distance = current.mileage - previous.mileage
            guard distance > 0, periodStart.map({ current.date >= $0 }) ?? true else { return nil }
            return FuelEfficiencyReading(
                date: current.date,
                mileage: current.mileage,
                distance: distance,
                liters: current.liters,
                kilometresPerLiter: Double(distance) / current.liters
            )
        }
    }

    var averageFuelEfficiency: Double? {
        let readings = fuelEfficiencyReadings
        let liters = readings.reduce(0) { $0 + $1.liters }
        guard liters > 0 else { return nil }
        return Double(readings.reduce(0) { $0 + $1.distance }) / liters
    }

    var latestFuelEfficiency: Double? {
        fuelEfficiencyReadings.last?.kilometresPerLiter
    }

    var bestFuelEfficiency: Double? {
        fuelEfficiencyReadings.map(\.kilometresPerLiter).max()
    }
}
