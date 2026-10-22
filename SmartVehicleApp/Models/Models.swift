import Foundation

extension Date {
    var shortDate: String { formatted(date: .abbreviated, time: .omitted) }
    var monthYear: String { formatted(.dateTime.month(.abbreviated).year()) }
}

struct Vehicle: Identifiable, Codable, Hashable {
    var id = UUID()
    var make: String
    var model: String
    var year: Int
    var registration: String
    var mileage: Int
    var fuel: String
    var color: String
    var image: String
    var nextServiceMileage: Int
    var nextServiceDate: Date
    var vin: String
    var engine: String
    var transmission: String
    var notes: String = ""
    var title: String { "\(make) \(model)" }
    var distanceToService: Int { max(0, nextServiceMileage - mileage) }
}

struct MaintenanceRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var vehicleID: UUID
    var type: String
    var date: Date
    var mileage: Int
    var cost: Double
    var notes: String
    var status: String = "Completed"
    var nextReminder: Date? = nil
}

struct FuelRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var vehicleID: UUID
    var date: Date
    var mileage: Int
    var liters: Double
    var pricePerLiter: Double
    var station: String
    var total: Double { liters * pricePerLiter }
}

struct ExpenseRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var vehicleID: UUID
    var title: String
    var category: String
    var date: Date
    var mileage: Int
    var amount: Double
    var notes: String
    var hasReceipt: Bool? = nil
}

struct VehicleDocument: Identifiable, Codable, Hashable {
    var id = UUID()
    var vehicleID: UUID
    var type: String
    var number: String
    var registration: String
    var issueDate: Date
    var expiryDate: Date
    var status: String
    var imageName: String = "doc.text"
    var scanPageCount: Int? = nil
}

struct CommunityPost: Identifiable, Codable, Hashable {
    var id = UUID()
    var author: String
    var initials: String
    var vehicle: String
    var time: String
    var text: String
    var category: String
    var comments: Int
    var likes: Int
    var image: String? = nil
    var isLiked: Bool = false
    var authorID: String? = nil
}

struct CommunityComment: Identifiable, Codable, Hashable {
    var id = UUID()
    var author: String
    var text: String
}

struct MarketplaceItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var subtitle: String
    var price: String
    var category: String
    var symbol: String
    var tint: String
    var distance: String
    var sellerID: String? = nil
    var contact: String? = nil

    var priceAmount: Int {
        Int(price.filter(\.isNumber)) ?? 0
    }
}

struct NearbyPlace: Identifiable, Hashable {
    var id: String
    var name: String
    var category: String
    var distance: String
    var distanceSource: String
    var symbol: String
    var latitude: Double
    var longitude: Double
}

enum ExpenseCategory: String, CaseIterable, Identifiable {
    case fuel = "Fuel"
    case maintenance = "Maintenance"
    case insurance = "Insurance"
    case parking = "Parking"
    case parts = "Parts"
    case other = "Other"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .fuel: "fuelpump.fill"
        case .maintenance: "wrench.and.screwdriver.fill"
        case .insurance: "shield.lefthalf.filled"
        case .parking: "parkingsign.circle.fill"
        case .parts: "gearshape.2.fill"
        case .other: "ellipsis.circle.fill"
        }
    }
    var tint: String {
        switch self {
        case .fuel: "teal"
        case .maintenance: "orange"
        case .insurance: "blue"
        case .parking: "purple"
        case .parts: "pink"
        case .other: "gray"
        }
    }
}
