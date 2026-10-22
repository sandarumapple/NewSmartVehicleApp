import SwiftUI
import WidgetKit

struct VehicleWidgetEntry: TimelineEntry {
    let date: Date
    let vehicle: String
    let mileage: String
    let service: String
    let document: String
    let alert: String
    let alertIsUrgent: Bool
    let isRaize: Bool
}

struct VehicleWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> VehicleWidgetEntry {
        VehicleWidgetEntry(
            date: .now, vehicle: "Toyota Corolla", mileage: "28,450 km", service: "1,550 km",
            document: "Insurance · 18 days", alert: "All systems ready", alertIsUrgent: false,
            isRaize: false)
    }
    func getSnapshot(in context: Context, completion: @escaping (VehicleWidgetEntry) -> Void) {
        completion(readEntry())
    }
    func getTimeline(
        in context: Context, completion: @escaping (Timeline<VehicleWidgetEntry>) -> Void
    ) {
        let entry = readEntry()
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 60))))
    }
    private func readEntry() -> VehicleWidgetEntry {
        guard
            let data = UserDefaults(suiteName: "group.com.sandaru.smartvehicle")?
                .data(forKey: "smart-vehicle-store"),
            let state = try? JSONDecoder().decode(WidgetStoreState.self, from: data),
            let car = state.vehicles.first(where: { $0.id == state.selectedVehicleID })
                ?? state.vehicles.first
        else {
            return VehicleWidgetEntry(
                date: .now, vehicle: "Add a vehicle", mileage: "— km", service: "— km",
                document: "No documents added", alert: "Open Smart Garage to get started",
                alertIsUrgent: false, isRaize: false)
        }
        let doc = state.documents
            .filter { $0.vehicleID == car.id }
            .min { $0.expiryDate < $1.expiryDate }
        let documentExpired = doc?.status == "Expired"
        let serviceDueSoon = car.distanceToService <= 1000
        let urgent = documentExpired || serviceDueSoon
        let documentText =
            doc.map {
                "\($0.type) · \($0.expiryDate.formatted(.dateTime.month(.abbreviated).day()))"
            } ?? "No documents added"
        let alert: String
        if documentExpired {
            alert = "Document expired"
        } else if serviceDueSoon {
            alert = "Service due soon"
        } else {
            alert = "All systems ready"
        }
        return VehicleWidgetEntry(
            date: .now, vehicle: car.title, mileage: "\(car.mileage.formatted()) km",
            service: "\(car.distanceToService.formatted()) km", document: documentText,
            alert: alert, alertIsUrgent: urgent,
            isRaize: car.model.localizedCaseInsensitiveContains("raize"))
    }
}

private struct WidgetStoreState: Decodable {
    var vehicles: [WidgetVehicle]
    var selectedVehicleID: UUID?
    var documents: [WidgetDocument]
}
private struct WidgetVehicle: Decodable {
    var id: UUID
    var make: String
    var model: String
    var mileage: Int
    var nextServiceMileage: Int
    var title: String { "\(make) \(model)" }
    var distanceToService: Int { max(0, nextServiceMileage - mileage) }
}
private struct WidgetDocument: Decodable {
    var vehicleID: UUID
    var type: String
    var expiryDate: Date
    var status: String
}

struct SmartVehicleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VehicleWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                if entry.isRaize {
                    Image("ToyotaRaize").resizable().scaledToFit()
                        .frame(width: 34, height: 24)
                } else {
                    Image(systemName: "car.side.fill")
                        .foregroundStyle(Color(red: 0.04, green: 0.52, blue: 0.45))
                }
                Text(entry.vehicle).font(.caption.bold()).lineLimit(1)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption2).foregroundStyle(.tertiary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(entry.mileage)
                    .font(
                        .system(
                            size: family == .systemSmall ? 23 : 27, weight: .bold, design: .rounded)
                    )
                Text("mileage").font(.caption2).foregroundStyle(.secondary)
            }
            if family == .systemMedium {
                HStack(spacing: 8) {
                    info("wrench.fill", "Next service", entry.service, .orange)
                    info("doc.text.fill", "Document", entry.document, .blue)
                }
                Label(
                    entry.alert,
                    systemImage: entry.alertIsUrgent
                        ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(entry.alertIsUrgent ? .orange : .green).lineLimit(1)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Service · \(entry.service)", systemImage: "wrench.fill").font(.caption2)
                        .lineLimit(1)
                    Label(
                        entry.alert,
                        systemImage: entry.alertIsUrgent
                            ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(entry.alertIsUrgent ? .orange : .green).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14).containerBackground(.background, for: .widget)
    }
    private func info(_ icon: String, _ title: String, _ value: String, _ tint: Color) -> some View
    {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: icon).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(9)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct SmartVehicleWidget: Widget {
    let kind = "SmartVehicleWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VehicleWidgetProvider()) { entry in
            SmartVehicleWidgetView(entry: entry)
        }
        .configurationDisplayName("My Vehicle")
        .description("Mileage, maintenance, documents, and important vehicle alerts.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main struct SmartVehicleWidgetBundle: WidgetBundle {
    var body: some Widget { SmartVehicleWidget() }
}
