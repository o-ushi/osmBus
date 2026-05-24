import SwiftUI

enum AppTheme {
    /// メイン背景色 RGB(61, 89, 147)
    static let brandBlue = Color(red: 61 / 255, green: 89 / 255, blue: 147 / 255)

    /// カード・ボタン面
    static let surface = Color.white.opacity(0.14)
    static let surfacePressed = Color.white.opacity(0.22)

    /// テキスト
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.72)
    static let placeholderText = Color.white.opacity(0.45)

    static let cornerRadius: CGFloat = 14
    static let keypadCornerRadius: CGFloat = 12

    static let screenPadding: CGFloat = 14
    static let sectionSpacing: CGFloat = 10
    static let cardPaddingH: CGFloat = 12
    static let cardPaddingV: CGFloat = 10
    static let keypadKeyHeight: CGFloat = 44
    static let keypadLetterHeight: CGFloat = 40
    static let keypadGridSpacing: CGFloat = 6
}

enum KeypadMetrics {
    /// 拡大表示（文字を拡大）時は論理解像度が下がる
    static func isZoomedCompact(screenHeight: CGFloat) -> Bool {
        screenHeight < 740
    }

    static let keyHeight: CGFloat = 44
    static let letterKeyHeight: CGFloat = 40
    static let keyFontSize: CGFloat = 22
    static let deleteIconSize: CGFloat = 22
    static let busNumberFontSize: CGFloat = 48
    static let busNumberLabelFontSize: CGFloat = 12
    static let gridSpacing: CGFloat = 6
    static let edgePaddingHorizontal: CGFloat = 12
    static let edgePaddingTop: CGFloat = 12
    static let edgePaddingBottom: CGFloat = 18
    static let displayHeight: CGFloat = 58
    static let displayBottomSpacing: CGFloat = 8
    /// 枠線＋角丸クリップで下段キーが切れないよう、見えない内側余白を足す。
    static let cardBottomInset: CGFloat = 4

    static var fixedContentHeight: CGFloat {
        KeypadLayoutMetrics.standard.totalFixedHeight
    }
}

struct KeypadLayoutMetrics {
    let edgePaddingTop: CGFloat
    let edgePaddingBottom: CGFloat
    let displayHeight: CGFloat
    let displayBottomSpacing: CGFloat
    let busNumberFontSize: CGFloat
    let busNumberLabelFontSize: CGFloat
    let letterKeyHeight: CGFloat

    static let standard = KeypadLayoutMetrics(
        edgePaddingTop: KeypadMetrics.edgePaddingTop,
        edgePaddingBottom: KeypadMetrics.edgePaddingBottom,
        displayHeight: KeypadMetrics.displayHeight,
        displayBottomSpacing: KeypadMetrics.displayBottomSpacing,
        busNumberFontSize: KeypadMetrics.busNumberFontSize,
        busNumberLabelFontSize: KeypadMetrics.busNumberLabelFontSize,
        letterKeyHeight: KeypadMetrics.letterKeyHeight
    )

    static let compact = KeypadLayoutMetrics(
        edgePaddingTop: 10,
        edgePaddingBottom: 14,
        displayHeight: 46,
        displayBottomSpacing: 4,
        busNumberFontSize: 38,
        busNumberLabelFontSize: 11,
        letterKeyHeight: 36
    )

    var totalFixedHeight: CGFloat {
        edgePaddingTop
            + edgePaddingBottom
            + KeypadMetrics.cardBottomInset
            + displayHeight
            + displayBottomSpacing
            + KeypadMetrics.gridSpacing * 3
            + KeypadMetrics.keyHeight * 4
    }

    /// テンキー領域の高さに合わせて表示帯を縮め、番号が枠外に出ないようにする。
    static func resolved(containerHeight: CGFloat, compactLayout: Bool) -> KeypadLayoutMetrics {
        let preferred = compactLayout ? compact : standard
        let deficit = preferred.totalFixedHeight - containerHeight
        guard deficit > 0 else { return preferred }

        return KeypadLayoutMetrics(
            edgePaddingTop: max(6, preferred.edgePaddingTop - deficit * 0.12),
            edgePaddingBottom: max(14, preferred.edgePaddingBottom),
            displayHeight: max(28, preferred.displayHeight - deficit * 0.5),
            displayBottomSpacing: max(2, preferred.displayBottomSpacing - 2),
            busNumberFontSize: max(28, preferred.busNumberFontSize - deficit * 0.28),
            busNumberLabelFontSize: preferred.busNumberLabelFontSize,
            letterKeyHeight: preferred.letterKeyHeight
        )
    }
}

private struct MainScreenCompactLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var mainScreenCompactLayout: Bool {
        get { self[MainScreenCompactLayoutKey.self] }
        set { self[MainScreenCompactLayoutKey.self] = newValue }
    }
}
