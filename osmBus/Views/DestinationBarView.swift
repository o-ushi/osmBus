import SwiftUI

struct DestinationBarView: View {
    let label: String
    let hasDestination: Bool
    let onTap: () -> Void

    @Environment(\.mainScreenCompactLayout) private var compactLayout
    @Environment(\.busFrameStyle) private var frameStyle
    @Environment(\.locale) private var locale

    private var titleSize: CGFloat { compactLayout ? 15 : 18 }
    private var iconFont: Font { compactLayout ? .body : .title3 }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: hasDestination ? "mappin.circle.fill" : "mappin.and.ellipse")
                    .font(iconFont)
                    .foregroundStyle(hasDestination ? Color.accentColor : Color.secondary)

                Text(label)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(hasDestination ? Color.primary : Color.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppTheme.cardPaddingH)
            .padding(.vertical, compactLayout ? 10 : 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(BusCardBackground(style: frameStyle))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppLocaleString.text("目的地", locale: locale))
        .accessibilityValue(label)
    }
}

struct CurrentLocationBarView: View {
    let statusText: String
    let isUpdating: Bool
    let showsSettingsAction: Bool
    let onRefresh: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.mainScreenCompactLayout) private var compactLayout
    @Environment(\.busFrameStyle) private var frameStyle
    @Environment(\.locale) private var locale

    private var titleSize: CGFloat { compactLayout ? 15 : 18 }
    private var iconFont: Font { compactLayout ? .body : .title3 }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(iconFont)
                .foregroundStyle(iconColor)

            Text("\(AppLocaleString.text("現在地", locale: locale)): \(statusText)")
                .font(.system(size: titleSize, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)

            if showsSettingsAction {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(iconFont)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppLocaleString.text("設定", locale: locale))
            } else {
                Button(action: onRefresh) {
                    if isUpdating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(iconFont)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isUpdating)
            }
        }
        .padding(.horizontal, AppTheme.cardPaddingH)
        .padding(.vertical, compactLayout ? 10 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(BusCardBackground(style: frameStyle))
    }

    private var iconName: String {
        showsSettingsAction ? "location.slash" : "location.fill"
    }

    private var iconColor: Color {
        showsSettingsAction ? Color.orange : Color.accentColor
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        VStack(spacing: 8) {
            DestinationBarView(label: "渋谷駅", hasDestination: true, onTap: {})
                .frame(height: 80)
            CurrentLocationBarView(
                statusText: "取得済み",
                isUpdating: false,
                showsSettingsAction: false,
                onRefresh: {},
                onOpenSettings: {}
            )
            .frame(height: 80)
        }
        .padding()
        .busMainScreenThemed()
    }
    .environment(AppAppearanceStore.shared)
    .environment(ColorThemeManager.shared)
}
