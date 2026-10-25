import SwiftUI

struct BusCardStyle: Equatable {
    var cardFill: Color
    var cardBorder: Color
    var borderWidth: CGFloat
    var accentStrip: Color

    static let standard = BusCardStyle(
        cardFill: AppTheme.cardFill,
        cardBorder: AppTheme.cardBorder,
        borderWidth: AppTheme.cardBorderWidth,
        accentStrip: AppTheme.cardAccentStrip
    )

    /// 枠・縁取り・アクセント帯なし。複数の行を1枚のカードにまとめる際、
    /// 各行の個別背景を消して外側のカード1枚分だけを見せたい場合に使う。
    static let flat = BusCardStyle(
        cardFill: .clear,
        cardBorder: .clear,
        borderWidth: 0,
        accentStrip: .clear
    )
}

private struct BusCardStyleKey: EnvironmentKey {
    static let defaultValue = BusCardStyle.standard
}

extension EnvironmentValues {
    var busCardStyle: BusCardStyle {
        get { self[BusCardStyleKey.self] }
        set { self[BusCardStyleKey.self] = newValue }
    }
}

struct BusCardBackground: View {
    var style: BusCardStyle = .standard

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .fill(style.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(style.cardBorder, lineWidth: style.borderWidth)
                )
            RoundedRectangle(cornerRadius: 3)
                .fill(style.accentStrip)
                .frame(width: 4)
                .padding(.vertical, 10)
                .padding(.leading, 6)
        }
    }
}

struct BusMainScreenStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.busCardStyle, .standard)
            .environment(\.colorScheme, .light)
            .tint(AppTheme.accent)
    }
}

extension View {
    func busMainScreenStyled() -> some View {
        modifier(BusMainScreenStyleModifier())
    }

    /// 検索・履歴・登録地など、システムライトで統一するシート用。
    func lightSheetChrome() -> some View {
        preferredColorScheme(.light)
            .tint(AppTheme.accent)
    }
}
