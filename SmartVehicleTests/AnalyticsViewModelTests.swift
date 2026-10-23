import Foundation
import Testing
@testable import SmartVehicle

@Suite("Analytics ViewModel")
struct AnalyticsViewModelTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("Totals include only the selected vehicle and past records")
    func totalsIncludeOnlySelectedVehicleAndPastRecords() {
        let vehicle = makeVehicle(mileage: 1_100)
        let otherVehicle = makeVehicle(mileage: 5_000)
        let now = date(2026, 6, 30)
        let fuel = [
            FuelRecord(
                vehicleID: vehicle.id, date: date(2026, 6, 1), mileage: 1_000,
                liters: 10, pricePerLiter: 10, station: "Test Station"),
            FuelRecord(
                vehicleID: otherVehicle.id, date: date(2026, 6, 1), mileage: 4_900,
                liters: 20, pricePerLiter: 10, station: "Other Station"),
            FuelRecord(
                vehicleID: vehicle.id, date: date(2026, 7, 1), mileage: 1_200,
                liters: 30, pricePerLiter: 10, station: "Future Station"),
        ]
        let maintenance = [
            MaintenanceRecord(
                vehicleID: vehicle.id, type: "Service", date: date(2026, 6, 10),
                mileage: 1_050, cost: 200, notes: "")
        ]
        let expenses = [
            ExpenseRecord(
                vehicleID: vehicle.id, title: "Parking", category: "Parking",
                date: date(2026, 6, 15), mileage: 1_075, amount: 50, notes: "")
        ]

        let sut = AnalyticsViewModel(
            vehicle: vehicle,
            fuelRecords: fuel,
            maintenance: maintenance,
            expenses: expenses,
            range: .all,
            selectedCategory: "All",
            now: now,
            calendar: calendar
        )

        #expect(sut.transactions.count == 3)
        #expect(abs(sut.totalSpending - 350) < 0.001)
        #expect(abs(sut.total(for: .fuel) - 100) < 0.001)
        #expect(abs(sut.total(for: .maintenance) - 200) < 0.001)
        #expect(abs(sut.total(for: .other) - 50) < 0.001)
        #expect(sut.recordedDistance == 100)
    }

    @Test("Selected category returns only matching transactions")
    func selectedCategoryReturnsOnlyMatchingTransactions() {
        let vehicle = makeVehicle(mileage: 2_000)
        let sut = AnalyticsViewModel(
            vehicle: vehicle,
            fuelRecords: [
                FuelRecord(
                    vehicleID: vehicle.id, date: date(2026, 4, 1), mileage: 1_900,
                    liters: 10, pricePerLiter: 10, station: "Test Station")
            ],
            maintenance: [
                MaintenanceRecord(
                    vehicleID: vehicle.id, type: "Service", date: date(2026, 4, 2),
                    mileage: 1_950, cost: 300, notes: "")
            ],
            expenses: [],
            range: .all,
            selectedCategory: "Fuel",
            now: date(2026, 4, 30),
            calendar: calendar
        )

        #expect(sut.selectedTransactions.count == 1)
        #expect(sut.selectedTransactions.first?.category == .fuel)
        #expect(sut.selectedTransactions.first?.amount == 100)
    }

    @Test("One-month range excludes older transactions")
    func oneMonthRangeExcludesOlderTransactions() {
        let vehicle = makeVehicle(mileage: 2_000)
        let sut = AnalyticsViewModel(
            vehicle: vehicle,
            fuelRecords: [
                FuelRecord(
                    vehicleID: vehicle.id, date: date(2026, 5, 20), mileage: 1_900,
                    liters: 10, pricePerLiter: 10, station: "Recent"),
                FuelRecord(
                    vehicleID: vehicle.id, date: date(2026, 3, 1), mileage: 1_700,
                    liters: 20, pricePerLiter: 10, station: "Old"),
            ],
            maintenance: [],
            expenses: [],
            range: .oneMonth,
            selectedCategory: "All",
            now: date(2026, 6, 1),
            calendar: calendar
        )

        #expect(sut.periodTransactions.count == 1)
        #expect(abs(sut.totalSpending - 100) < 0.001)
    }

    @Test("Fuel efficiency uses distance between consecutive fill-ups")
    func fuelEfficiencyUsesDistanceBetweenConsecutiveFillUps() {
        let vehicle = makeVehicle(mileage: 1_660)
        let sut = AnalyticsViewModel(
            vehicle: vehicle,
            fuelRecords: [
                FuelRecord(
                    vehicleID: vehicle.id, date: date(2026, 4, 1), mileage: 1_000,
                    liters: 20, pricePerLiter: 10, station: "First"),
                FuelRecord(
                    vehicleID: vehicle.id, date: date(2026, 4, 15), mileage: 1_300,
                    liters: 30, pricePerLiter: 10, station: "Second"),
                FuelRecord(
                    vehicleID: vehicle.id, date: date(2026, 5, 1), mileage: 1_660,
                    liters: 30, pricePerLiter: 10, station: "Third"),
            ],
            maintenance: [],
            expenses: [],
            range: .all,
            selectedCategory: "All",
            now: date(2026, 6, 1),
            calendar: calendar
        )

        #expect(sut.fuelEfficiencyReadings.count == 2)
        #expect(abs(sut.fuelEfficiencyReadings[0].kilometresPerLiter - 10) < 0.001)
        #expect(abs((sut.latestFuelEfficiency ?? 0) - 12) < 0.001)
        #expect(abs((sut.bestFuelEfficiency ?? 0) - 12) < 0.001)
        #expect(abs((sut.averageFuelEfficiency ?? 0) - 11) < 0.001)
    }

    @Test("Running-cost forecast uses the selected range")
    func runningCostForecastUsesSelectedRange() {
        let vehicle = makeVehicle(mileage: 2_000)
        let sut = AnalyticsViewModel(
            vehicle: vehicle,
            fuelRecords: [],
            maintenance: [],
            expenses: [
                ExpenseRecord(
                    vehicleID: vehicle.id, title: "Insurance", category: "Insurance",
                    date: date(2026, 5, 1), mileage: 1_900, amount: 600, notes: "")
            ],
            range: .threeMonths,
            selectedCategory: "All",
            now: date(2026, 6, 30),
            calendar: calendar
        )

        #expect(sut.analysedMonthCount == 3)
        #expect(abs(sut.averageMonthlySpending - 200) < 0.001)
        #expect(abs(sut.estimatedAnnualSpending - 2_400) < 0.001)
    }

    private func makeVehicle(mileage: Int) -> Vehicle {
        Vehicle(
            make: "Toyota",
            model: "Aqua",
            year: 2018,
            registration: "CAA-1234",
            mileage: mileage,
            fuel: "Hybrid",
            color: "White",
            image: "car.side.fill",
            nextServiceMileage: mileage + 5_000,
            nextServiceDate: date(2026, 12, 1),
            vin: "TESTVIN123",
            engine: "1500cc",
            transmission: "Automatic"
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
