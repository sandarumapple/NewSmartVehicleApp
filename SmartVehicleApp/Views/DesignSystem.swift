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

struct ScreenHeading: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title.weight(.bold)).foregroundStyle(.primary)
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
            Text(title).font(.system(size: 17, weight: .semibold))
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
                Text(value).font(.title3.weight(.bold)).lineLimit(2)
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
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(
                Color.appAccent.opacity(configuration.isPressed ? 0.78 : 1),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(Color.appAccent)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
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
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
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
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
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

