import SwiftUI

extension Color {
    private static func theme(_ dark: UInt32, _ light: UInt32) -> Color {
        Color(
            uiColor: UIColor { traits in
                let hex = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat((hex >> 16) & 255) / 255,
                    green: CGFloat((hex >> 8) & 255) / 255,
                    blue: CGFloat(hex & 255) / 255, alpha: 1)
            })
    }
    static let appInk = theme(0xE1E2EB, 0x191C22)
    static let appMuted = theme(0x8C90A1, 0x626778)
    static let appAccent = theme(0xB3C5FF, 0x345DA8)
    static let appCanvas = theme(0x10131A, 0xF3F5FA)
    static let appCard = theme(0x191C22, 0xFFFFFF)
    static let appElevated = theme(0x1D2026, 0xE7EBF4)
    static let appMint = theme(0x272A31, 0xE5ECFF)
    static let appSuccess = theme(0x53E16F, 0x247638)
}

// Semantic typography keeps the app aligned with iOS Dynamic Type and the
// user's preferred text size. Decorative SF Symbols can still use fixed sizes.
extension Font {
    static let appScreenTitle = Font.title.weight(.bold)
    static let appSectionTitle = Font.headline
    static let appCardTitle = Font.subheadline.weight(.semibold)
    static let appBody = Font.subheadline
    static let appMetadata = Font.caption
    static let appBadge = Font.caption2.weight(.semibold)
    static let appMetric = Font.title3.weight(.bold)
}

struct ScreenHeading: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.appScreenTitle).foregroundStyle(.primary)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer()
            if let trailing { trailing }
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
    }
}

struct SectionHeading: View {
    let title: String
    var action: String? = nil
    var onTap: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(title).font(.appSectionTitle)
            Spacer()
            if let action {
                Button(action, action: { onTap?() }).font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appAccent)
            }
        }
    }
}

struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(padding)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.025), radius: 12, x: 0, y: 5)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    var tint: Color = .appAccent
    var body: some View {
        SurfaceCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol).font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint).frame(width: 32, height: 32)
                    .background(tint.opacity(0.11), in: Circle())
                Text(value).font(.appMetric).lineLimit(2)
                    .minimumScaleFactor(0.85)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct StatusBadge: View {
    let text: String
    var body: some View {
        let color: Color =
            text.lowercased().contains("expired")
            ? .red
            : (text.lowercased().contains("soon") || text.lowercased().contains("due")
                ? .orange : .appAccent)
        Text(text).font(.caption2.weight(.bold)).foregroundStyle(color).padding(.horizontal, 9)
            .padding(.vertical, 5).background(color.opacity(0.11), in: Capsule())
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.appAccent).frame(width: 72, height: 72)
                .background(Color.appMint, in: Circle())
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 270)
            if let action {
                Button(action, action: { onAction?() }).buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity).padding(28)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(Color.appCanvas)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                Color.appAccent.opacity(configuration.isPressed ? 0.78 : 1),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(Color.appAccent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.appMint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct IconButton: View {
    let symbol: String
    let accessibilityLabel: String
    var tint: Color = .primary
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint).frame(width: 46, height: 46)
                .background(Color.appCard, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct ActiveVehicleSelector: View {
    @EnvironmentObject private var store: AppStore
    var fixedVehicleID: UUID? = nil

    private var vehicle: Vehicle? {
        store.vehicles.first(where: { $0.id == fixedVehicleID }) ?? store.selectedVehicle
    }

    var body: some View {
        Group {
            if fixedVehicleID == nil {
                Menu {
                    ForEach(store.vehicles) { item in
                        Button {
                            store.selectedVehicleID = item.id
                            store.persist()
                        } label: {
                            if item.id == store.selectedVehicle?.id {
                                Label(item.title, systemImage: "checkmark")
                            } else {
                                Text(item.title)
                            }
                        }
                    }
                } label: {
                    selectorLabel(showsChevron: true)
                }
                .buttonStyle(.plain)
            } else {
                selectorLabel(showsChevron: false)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active vehicle")
        .accessibilityValue(vehicle?.title ?? "No vehicle selected")
    }

    private func selectorLabel(showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "car.side.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .frame(width: 40, height: 40)
                .background(Color.appMint, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("ACTIVE VEHICLE").font(.appBadge).tracking(0.6).foregroundStyle(.secondary)
                Text(vehicle?.title ?? "Select a vehicle")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                if let registration = vehicle?.registration {
                    Text(registration).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.bold()).foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.appSuccess)
            }
        }
        .padding(12)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06))
        }
    }
}

struct AppFeedbackBanner: View {
    let message: String
    let isError: Bool
    var retry: (() -> Void)? = nil
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? Color.orange : Color.appSuccess)
            Text(message).font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
            if let retry {
                Button("Try again", action: retry)
                    .font(.caption.weight(.semibold)).foregroundStyle(Color.appAccent)
            }
            Button(action: dismiss) {
                Image(systemName: "xmark").font(.caption.bold()).frame(width: 32, height: 32)
            }
            .buttonStyle(.plain).accessibilityLabel("Dismiss")
        }
        .padding(.leading, 14).padding(.trailing, 8).padding(.vertical, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder((isError ? Color.orange : Color.appSuccess).opacity(0.35))
        }
        .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        .accessibilityElement(children: .combine)
    }
}

struct UndoActionBanner: View {
    let message: String
    let undo: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .foregroundStyle(Color.orange)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
            Button("Undo", action: undo)
                .font(.subheadline.bold())
                .foregroundStyle(Color.appAccent)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss undo message")
        }
        .padding(.leading, 14).padding(.trailing, 8).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.orange.opacity(0.3))
        }
        .shadow(color: .black.opacity(0.18), radius: 16, y: 7)
        .accessibilityElement(children: .contain)
    }
}

struct LoadingSkeletonList: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var highlighted = false

    var rows: Int = 3

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.14))
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(Color.secondary.opacity(0.16)).frame(height: 12)
                        Capsule().fill(Color.secondary.opacity(0.1))
                            .frame(width: 150, height: 9)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .redacted(reason: .placeholder)
        .opacity(highlighted ? 0.55 : 0.9)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.85).repeatForever(autoreverses: true),
            value: highlighted
        )
        .onAppear { highlighted = true }
        .accessibilityElement()
        .accessibilityLabel("Loading content")
    }
}

struct InlineValidationMessage: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption).foregroundStyle(.red)
            .accessibilityLabel("Error: \(message)")
    }
}

struct RecordRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    let amount: String?
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint).frame(width: 44, height: 44)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.appCardTitle).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let amount { Text(amount).font(.subheadline.weight(.bold)).monospacedDigit() }
        }
        .padding(.vertical, 3)
    }
}

struct FormField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.appBadge).foregroundStyle(.secondary)
            TextField(placeholder.isEmpty ? title : placeholder, text: $text).keyboardType(keyboard)
                .padding(14).background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

struct CurrencyText: View {
    let amount: Double
    var body: some View {
        Text(amount, format: .currency(code: "LKR").precision(.fractionLength(0))).monospacedDigit()
    }
}

