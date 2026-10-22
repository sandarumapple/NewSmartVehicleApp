import Foundation
import UIKit

struct VehicleReportInput {
    let vehicle: Vehicle
    let maintenance: [MaintenanceRecord]
    let fuelRecords: [FuelRecord]
    let expenses: [ExpenseRecord]
    let documents: [VehicleDocument]
    let start: Date
    let end: Date
    let sections: Set<String>
}

enum VehicleReportGenerator {
    static func generate(_ input: VehicleReportInput) throws -> Data {
        let vehicle = input.vehicle
        let start = input.start
        let end = input.end
        let sections = input.sections
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            var y: CGFloat = 0
            var pageNo = 0
            func beginPage() {
                context.beginPage()
                pageNo += 1
                y = 48
                draw(
                    "SMART GARAGE", at: CGPoint(x: 45, y: 30), size: 9,
                    color: UIColor(red: 0.04, green: 0.52, blue: 0.45, alpha: 1), bold: true)
                draw(
                    "\(vehicle.title) · VEHICLE REPORT", at: CGPoint(x: 45, y: 50), size: 18,
                    color: .darkText, bold: true)
                draw(
                    "\(start.shortDate) — \(end.shortDate)", at: CGPoint(x: 45, y: 77), size: 10,
                    color: .secondaryLabel)
                y = 112
            }
            func ensure(_ height: CGFloat = 45) {
                if y + height > 735 {
                    draw(
                        "Page \(pageNo)", at: CGPoint(x: 520, y: 760), size: 8,
                        color: .secondaryLabel)
                    beginPage()
                }
            }
            func header(_ text: String) {
                ensure(40)
                draw(
                    text.uppercased(), at: CGPoint(x: 45, y: y), size: 10,
                    color: UIColor(red: 0.04, green: 0.52, blue: 0.45, alpha: 1), bold: true)
                y += 20
            }
            func row(_ left: String, _ right: String) {
                ensure()
                draw(left, at: CGPoint(x: 45, y: y), size: 10, color: .darkText)
                draw(right, at: CGPoint(x: 290, y: y), size: 10, color: .darkText)
                y += 19
            }
            beginPage()
            if sections.contains("Vehicle Details") {
                header("Vehicle details")
                row("Vehicle", vehicle.title)
                row("Year", "\(vehicle.year)")
                row("Registration", vehicle.registration)
                row("VIN", vehicle.vin)
                row("Fuel", vehicle.fuel)
                row("Current mileage", "\(vehicle.mileage.formatted()) km")
            }
            if sections.contains("Mileage") {
                header("Mileage")
                row("Current odometer", "\(vehicle.mileage.formatted()) km")
                row("Next service", "\(vehicle.nextServiceMileage.formatted()) km")
            }
            if sections.contains("Maintenance") {
                header("Maintenance records")
                let records = input.maintenance.filter { $0.date >= start && $0.date <= end }
                for r in records {
                    row(
                        "\(r.date.shortDate) · \(r.type)",
                        "\(r.mileage.formatted()) km · \(currency(r.cost))")
                }
                if records.isEmpty { row("No maintenance records", "") }
            }
            if sections.contains("Fuel") {
                header("Fuel records")
                for r in input.fuelRecords.filter({ $0.date >= start && $0.date <= end }) {
                    row("\(r.date.shortDate) · \(r.liters.formatted()) L", currency(r.total))
                }
            }
            if sections.contains("Expenses") {
                header("Other expenses")
                for r in input.expenses.filter({ $0.date >= start && $0.date <= end }) {
                    row("\(r.date.shortDate) · \(r.category)", "\(r.title) · \(currency(r.amount))")
                }
            }
            if sections.contains("Documents") {
                header("Vehicle documents")
                for d in input.documents {
                    row("\(d.type) · \(d.number)", "\(d.status) · exp. \(d.expiryDate.shortDate)")
                }
            }
            if sections.contains("Analytics") {
                header("Summary")
                let fuel = input.fuelRecords.filter({ $0.date >= start && $0.date <= end })
                    .reduce(0) { $0 + $1.total }
                let maint = input.maintenance
                    .filter({ $0.date >= start && $0.date <= end }).reduce(0) { $0 + $1.cost }
                let other = input.expenses.filter({ $0.date >= start && $0.date <= end })
                    .reduce(0) { $0 + $1.amount }
                row("Fuel spending", currency(fuel))
                row("Maintenance cost", currency(maint))
                row("Other expenses", currency(other))
                row("Total recorded", currency(fuel + maint + other))
            }
            draw(
                "Generated by Smart Garage · Vehicle records as of \(Date.now.shortDate)",
                at: CGPoint(x: 45, y: 752), size: 8, color: .secondaryLabel)
        }
    }
    private static func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "LKR").precision(.fractionLength(0)))
    }
    private static func draw(
        _ text: String, at point: CGPoint, size: CGFloat, color: UIColor, bold: Bool = false
    ) {
        (text as NSString)
            .draw(
                at: point,
                withAttributes: [
                    .font: bold
                        ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size),
                    .foregroundColor: color,
                ])
    }
}
