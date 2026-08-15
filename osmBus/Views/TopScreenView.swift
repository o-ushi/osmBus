import SwiftUI

/// トップ画面。行き先・現在地の上に横長の距離バー、その下にバス番号表を置く。
struct TopScreenView: View {
    let destinationLabel: String
    let hasDestination: Bool
    let currentLocationStatusText: String
    let isUpdatingCurrentLocation: Bool
    let showsLocationSettingsAction: Bool
    let hasManualOrigin: Bool
    let isInputDisabled: Bool
    let accumulatedTransitRoutes: [ParsedTransitRoute]
    let transitRoutesLoadState: MainViewModel.TransitRoutesLoadState
    let ridingBusNumber: String?
    var originLatitude: Double? = nil
    var originLongitude: Double? = nil
    /// バス番号表の枠の外（下）に出すお試し残り回数。nil なら非表示。
    var trialRemainingText: String? = nil
    /// 行き先・現在地カードの上に出す距離。nil なら非表示。
    var distanceMeters: Double? = nil
    var onDistanceTap: (() -> Void)? = nil

    let onDestinationTap: () -> Void
    let onDestinationMapPick: () -> Void
    let onCurrentLocationRefresh: () -> Void
    let onOpenLocationSettings: () -> Void
    let onClearManualOrigin: () -> Void
    let onCurrentLocationMapPick: () -> Void
    let onReloadTransitRoutes: () -> Void
    let onTapBusNumber: (String) -> Void
    let onLongPressBusNumber: (String) -> Void

    @Environment(\.busCardStyle) private var cardStyle

    private let locationRowHeight: CGFloat = 56

    var body: some View {
        VStack(spacing: 12) {
            if let distanceMeters, let onDistanceTap {
                TopDistanceBadge(distanceMeters: distanceMeters, onTap: onDistanceTap)
                    .frame(maxWidth: .infinity)
                    .frame(height: locationRowHeight)
            }

            locationCard

            BusNumberTableView(
                routes: accumulatedTransitRoutes,
                loadState: transitRoutesLoadState,
                ridingBusNumber: ridingBusNumber,
                originLatitude: originLatitude,
                originLongitude: originLongitude,
                onReload: onReloadTransitRoutes,
                onTapBusNumber: onTapBusNumber,
                onLongPressBusNumber: onLongPressBusNumber
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if let trialRemainingText {
                Text(trialRemainingText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.accentColor.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
            }
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .busMainScreenStyled()
    }

    /// 行き先・現在地を1枚のカードにまとめ、個別の枠を減らしてスペースを節約する。
    private var locationCard: some View {
        VStack(spacing: 0) {
            DestinationBarView(
                label: destinationLabel,
                hasDestination: hasDestination,
                isDisabled: isInputDisabled,
                onTap: onDestinationTap,
                onMapPick: onDestinationMapPick
            )
            .frame(height: locationRowHeight)
            .environment(\.busCardStyle, .flat)

            Divider().padding(.leading, AppTheme.cardPaddingH + 10)

            CurrentLocationBarView(
                statusText: currentLocationStatusText,
                isUpdating: isUpdatingCurrentLocation,
                showsSettingsAction: showsLocationSettingsAction,
                hasManualOrigin: hasManualOrigin,
                isDisabled: isInputDisabled,
                onRefresh: onCurrentLocationRefresh,
                onOpenSettings: onOpenLocationSettings,
                onClearManualOrigin: onClearManualOrigin,
                onMapPick: onCurrentLocationMapPick
            )
            .frame(height: locationRowHeight)
            .environment(\.busCardStyle, .flat)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .background(BusCardBackground(style: cardStyle))
    }
}

/// 距離欄の背景色バンド（3km/1km/500m/200m 区切り）。
enum DistanceColorBand {
    case blue, green, yellow, orange, red

    init(meters: Double) {
        switch meters {
        case 3000...: self = .blue
        case 1000..<3000: self = .green
        case 500..<1000: self = .yellow
        case 200..<500: self = .orange
        default: self = .red
        }
    }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .red: return .red
        }
    }

    /// 各背景色に対して読みやすい文字色（ユーザー指定）。
    var textColor: Color {
        switch self {
        case .blue, .green, .red: return .white
        case .yellow, .orange: return .black
        }
    }

    static func formattedDistanceText(meters: Double) -> String {
        meters < 1000
            ? String(format: "%.0f m", meters)
            : String(format: "%.1f km", meters / 1000)
    }
}

/// 行き先・現在地カードの上に置く、角丸の横長距離バー。タップでルート図を開く。
struct TopDistanceBadge: View {
    let distanceMeters: Double
    let onTap: () -> Void

    @Environment(\.locale) private var locale

    private let shape = RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)

    var body: some View {
        let band = DistanceColorBand(meters: distanceMeters)

        Button(action: onTap) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(AppLocaleString.text("あと", locale: locale))
                    .font(.subheadline.weight(.semibold))
                Text(DistanceColorBand.formattedDistanceText(meters: distanceMeters))
                    .font(.title2.weight(.bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .foregroundStyle(band.textColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(band.color, in: shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppLocaleString.text("あと", locale: locale))
        .accessibilityValue(DistanceColorBand.formattedDistanceText(meters: distanceMeters))
        .accessibilityHint(AppLocaleString.text("タップで地図", locale: locale))
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        TopScreenView(
            destinationLabel: "渋谷駅",
            hasDestination: true,
            currentLocationStatusText: "取得済み",
            isUpdatingCurrentLocation: false,
            showsLocationSettingsAction: false,
            hasManualOrigin: false,
            isInputDisabled: true,
            accumulatedTransitRoutes: [],
            transitRoutesLoadState: .idle,
            ridingBusNumber: nil,
            onDestinationTap: {},
            onDestinationMapPick: {},
            onCurrentLocationRefresh: {},
            onOpenLocationSettings: {},
            onClearManualOrigin: {},
            onCurrentLocationMapPick: {},
            onReloadTransitRoutes: {},
            onTapBusNumber: { _ in },
            onLongPressBusNumber: { _ in }
        )
    }
}
