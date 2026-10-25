import SwiftUI

struct DestinationBarView: View {
    let label: String
    let hasDestination: Bool
    var isDisabled: Bool = false
    let onTap: () -> Void
    var onMapPick: (() -> Void)? = nil

    @Environment(\.mainScreenCompactLayout) private var compactLayout
    @Environment(\.busCardStyle) private var cardStyle
    @Environment(\.locale) private var locale

    private var titleSize: CGFloat { compactLayout ? 15 : 18 }
    private var iconFont: Font { compactLayout ? .body : .title3 }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Image(systemName: hasDestination ? "mappin.circle.fill" : "mappin.and.ellipse")
                        .font(iconFont)
                        .foregroundStyle(isDisabled ? Color.secondary : (hasDestination ? Color.accentColor : Color.secondary))

                    Text(label)
                        .font(.system(size: titleSize, weight: isDisabled ? .medium : .semibold))
                        .foregroundStyle(isDisabled ? Color.secondary : (hasDestination ? Color.primary : Color.secondary))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    if onMapPick == nil {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, AppTheme.cardPaddingH)
                .padding(.vertical, compactLayout ? 10 : 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!isDisabled)
            .accessibilityLabel(AppLocaleString.text("目的地", locale: locale))
            .accessibilityValue(label)

            if let onMapPick {
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 1)
                    .padding(.vertical, 10)

                Button(action: onMapPick) {
                    Image(systemName: "map")
                        .font(iconFont)
                        .foregroundStyle(isDisabled ? Color.secondary : .blue)
                        .padding(.horizontal, AppTheme.cardPaddingH)
                        .padding(.vertical, compactLayout ? 10 : 14)
                        .frame(maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .allowsHitTesting(!isDisabled)
                .accessibilityLabel(AppLocaleString.text("地図から選択", locale: locale))
            }
        }
        .background(BusCardBackground(style: cardStyle))
    }
}

struct CurrentLocationBarView: View {
    let statusText: String
    let isUpdating: Bool
    let showsSettingsAction: Bool
    var hasManualOrigin: Bool = false
    var isDisabled: Bool = false
    let onRefresh: () -> Void
    let onOpenSettings: () -> Void
    var onClearManualOrigin: (() -> Void)? = nil
    var onMapPick: (() -> Void)? = nil
    /// 本体タップで出発地の地名検索シートを出す (Step 10)。nil ならタップ無効。
    var onTap: (() -> Void)? = nil

    @Environment(\.mainScreenCompactLayout) private var compactLayout
    @Environment(\.busCardStyle) private var cardStyle
    @Environment(\.locale) private var locale

    private var titleSize: CGFloat { compactLayout ? 15 : 18 }
    private var iconFont: Font { compactLayout ? .body : .title3 }

    private var barLabel: String {
        let prefix = hasManualOrigin
            ? AppLocaleString.text("地図_出発地", locale: locale)
            : AppLocaleString.text("現在地", locale: locale)
        return "\(prefix): \(statusText)"
    }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                onTap?()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: iconName)
                        .font(iconFont)
                        .foregroundStyle(isDisabled ? Color.secondary : iconColor)

                    Text(barLabel)
                        .font(.system(size: titleSize, weight: .medium))
                        .foregroundStyle(isDisabled ? Color.secondary : Color.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onTap == nil)
            .accessibilityLabel(barLabel)

            HStack(spacing: 12) {
                if hasManualOrigin, let onClearManualOrigin {
                    Button(action: onClearManualOrigin) {
                        Image(systemName: "xmark.circle")
                            .font(iconFont)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isDisabled ? Color.secondary : .orange)
                    .accessibilityLabel(AppLocaleString.text("地図_手動出発地クリア", locale: locale))
                } else if showsSettingsAction {
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

                if let onMapPick {
                    Button(action: onMapPick) {
                        Image(systemName: "map")
                            .font(iconFont)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isDisabled ? Color.secondary : .blue)
                    .accessibilityLabel(AppLocaleString.text("地図から選択", locale: locale))
                }
            }
            .padding(.trailing, AppTheme.cardPaddingH)
            .allowsHitTesting(!isDisabled)
        }
        .padding(.leading, AppTheme.cardPaddingH)
        .padding(.vertical, compactLayout ? 10 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(BusCardBackground(style: cardStyle))
    }

    private var iconName: String {
        if hasManualOrigin { return "mappin.circle.fill" }
        return showsSettingsAction ? "location.slash" : "location.fill"
    }

    private var iconColor: Color {
        if hasManualOrigin { return .green }
        return showsSettingsAction ? Color.orange : Color.accentColor
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
        .busMainScreenStyled()
    }
}
