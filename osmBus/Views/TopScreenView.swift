import SwiftUI
import UIKit

/// トップ画面。行き先・現在地カードの下にバス番号表を置く。距離はナビゲーションバーのバッジ（MainView 側）で表示する。
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
    var destinationLatitude: Double? = nil
    var destinationLongitude: Double? = nil
    /// バス番号表の枠の外（下）に出すお試し残り回数。nil なら非表示。
    var trialRemainingText: String? = nil

    let onDestinationTap: () -> Void
    let onDestinationMapPick: () -> Void
    let onCurrentLocationRefresh: () -> Void
    let onOpenLocationSettings: () -> Void
    let onClearManualOrigin: () -> Void
    let onCurrentLocationMapPick: () -> Void
    /// 現在地バー本体タップで出発地の地名検索シートを出す (Step 10)。
    var onCurrentLocationTap: (() -> Void)? = nil
    let onReloadTransitRoutes: () -> Void
    let onTapBusNumber: (Int, String) -> Void
    let onLongPressBusNumber: (Int, String) -> Void

    var body: some View {
        VStack(spacing: ScreenChrome.sectionSpacing) {
            OriginDestinationCard(
                destinationLabel: destinationLabel,
                hasDestination: hasDestination,
                isDestinationDisabled: isInputDisabled,
                currentLocationStatusText: currentLocationStatusText,
                isUpdatingCurrentLocation: isUpdatingCurrentLocation,
                showsLocationSettingsAction: showsLocationSettingsAction,
                hasManualOrigin: hasManualOrigin,
                onDestinationTap: onDestinationTap,
                onDestinationMapPick: onDestinationMapPick,
                onCurrentLocationRefresh: onCurrentLocationRefresh,
                onOpenLocationSettings: onOpenLocationSettings,
                onClearManualOrigin: onClearManualOrigin,
                onCurrentLocationMapPick: onCurrentLocationMapPick,
                onCurrentLocationTap: onCurrentLocationTap
            )

            BusNumberTableView(
                routes: accumulatedTransitRoutes,
                loadState: transitRoutesLoadState,
                ridingBusNumber: ridingBusNumber,
                originLatitude: originLatitude,
                originLongitude: originLongitude,
                destinationLatitude: destinationLatitude,
                destinationLongitude: destinationLongitude,
                onReload: onReloadTransitRoutes,
                onTapBusNumber: onTapBusNumber,
                onLongPressBusNumber: onLongPressBusNumber
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if let trialRemainingText {
                TrialRemainingLabel(text: trialRemainingText)
            }
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.top, ScreenChrome.topPadding)
        .padding(.bottom, ScreenChrome.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .busMainScreenStyled()
    }
}

/// トップとメインで目的地・出発地カードの位置を揃えるための余白。
enum ScreenChrome {
    static let topPadding: CGFloat = 12
    static let bottomPadding: CGFloat = 8
    static let sectionSpacing: CGFloat = 12
    static let locationRowHeight: CGFloat = 56
}

/// 行き先・現在地を1枚のカードにまとめる。トップ／メインで同じビューを使い、切り替え時に枠が動かないようにする。
struct OriginDestinationCard: View {
    let destinationLabel: String
    let hasDestination: Bool
    let isDestinationDisabled: Bool
    let currentLocationStatusText: String
    let isUpdatingCurrentLocation: Bool
    let showsLocationSettingsAction: Bool
    let hasManualOrigin: Bool
    let onDestinationTap: () -> Void
    let onDestinationMapPick: () -> Void
    let onCurrentLocationRefresh: () -> Void
    let onOpenLocationSettings: () -> Void
    let onClearManualOrigin: () -> Void
    let onCurrentLocationMapPick: () -> Void
    var onCurrentLocationTap: (() -> Void)? = nil

    @Environment(\.busCardStyle) private var cardStyle

    var body: some View {
        VStack(spacing: 0) {
            DestinationBarView(
                label: destinationLabel,
                hasDestination: hasDestination,
                isDisabled: isDestinationDisabled,
                onTap: onDestinationTap,
                onMapPick: onDestinationMapPick
            )
            .frame(height: ScreenChrome.locationRowHeight)
            .environment(\.busCardStyle, .flat)
            .environment(\.mainScreenCompactLayout, false)

            Divider().padding(.leading, AppTheme.cardPaddingH + 10)

            CurrentLocationBarView(
                statusText: currentLocationStatusText,
                isUpdating: isUpdatingCurrentLocation,
                showsSettingsAction: showsLocationSettingsAction,
                hasManualOrigin: hasManualOrigin,
                isDisabled: false,
                onRefresh: onCurrentLocationRefresh,
                onOpenSettings: onOpenLocationSettings,
                onClearManualOrigin: onClearManualOrigin,
                onMapPick: onCurrentLocationMapPick,
                onTap: onCurrentLocationTap
            )
            .frame(height: ScreenChrome.locationRowHeight)
            .environment(\.busCardStyle, .flat)
            .environment(\.mainScreenCompactLayout, false)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .background(BusCardBackground(style: cardStyle))
    }
}

/// トップ・メインで同じ見た目の残り回数。表／キーパッドの枠の外（下）に出す。
struct TrialRemainingLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.accentColor.opacity(0.88))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            .padding(.bottom, 6)
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

/// ナビゲーションバーに置く、あと距離のバッジ。トップ・メイン共通、タップでルート図を開く。
struct TopDistanceBadge: View {
    /// nil は「距離を出さない」（例: 目的地未設定のまま乗車中）。値は — で表示する。
    let distanceMeters: Double?
    /// nil のときは乗車していないので、タップしても路線図を開かない（表示のみ）。
    let onTap: (() -> Void)?
    /// 長押しでナビ中止。nil なら長押しを無効化する。
    var onLongPress: (() -> Void)? = nil

    @Environment(\.locale) private var locale

    private let labelFontSize: CGFloat = 15
    private let valueFontSize: CGFloat = 23
    private let horizontalPadding: CGFloat = 14
    private let verticalPadding: CGFloat = 9

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    var body: some View {
        let band = distanceMeters.map(DistanceColorBand.init)

        content(band: band)
            // ツールバー内の Button + SwiftUI 長押しは、乗車中の GPS 再描画でジェスチャーが
            // 壊れ、長押しがタップ扱いになったりバッジが消えたりする。認識は UIKit 側で固定する。
            .overlay {
                DistanceBadgePressOverlay(onTap: onTap, onLongPress: onLongPress)
            }
            .accessibilityAddTraits(onTap == nil ? [] : .isButton)
            .accessibilityHint(onTap == nil ? "" : AppLocaleString.text("タップで地図", locale: locale))
            .accessibilityLabel(AppLocaleString.text("あと", locale: locale))
            .accessibilityValue(distanceMeters.map(DistanceColorBand.formattedDistanceText) ?? "—")
            .accessibilityAction(named: Text(AppLocaleString.text("ナビを中止", locale: locale))) {
                onLongPress?()
            }
    }

    private func content(band: DistanceColorBand?) -> some View {
        VStack(spacing: 1) {
            Text(AppLocaleString.text("あと", locale: locale))
                .font(.system(size: labelFontSize, weight: .semibold))
            Text(distanceMeters.map(DistanceColorBand.formattedDistanceText) ?? "—")
                .font(.system(size: valueFontSize, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .fixedSize()
        .foregroundStyle(band?.textColor ?? Color(UIColor.secondaryLabel))
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(band?.color ?? Color(UIColor.systemGray5), in: shape)
    }
}

/// ナビバーの再描画でも長押しが切れないよう、タップ/長押しを UIKit で扱う。
private struct DistanceBadgePressOverlay: UIViewRepresentable {
    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.6
        tap.cancelsTouchesInView = false
        longPress.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(longPress)
        context.coordinator.tapRecognizer = tap
        context.coordinator.longPressRecognizer = longPress
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onLongPress = onLongPress
        context.coordinator.tapRecognizer?.isEnabled = onTap != nil
        context.coordinator.longPressRecognizer?.isEnabled = onLongPress != nil
    }

    final class Coordinator: NSObject {
        var onTap: (() -> Void)?
        var onLongPress: (() -> Void)?
        weak var tapRecognizer: UITapGestureRecognizer?
        weak var longPressRecognizer: UILongPressGestureRecognizer?
        private var ignoreNextTap = false

        @objc func handleTap() {
            guard !ignoreNextTap else { return }
            onTap?()
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began {
                ignoreNextTap = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onLongPress?()
                return
            }
            if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
                DispatchQueue.main.async { [weak self] in
                    self?.ignoreNextTap = false
                }
            }
        }
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
            onTapBusNumber: { _, _ in },
            onLongPressBusNumber: { _, _ in }
        )
    }
}
