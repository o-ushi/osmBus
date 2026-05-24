import SwiftUI

private struct BusFrameStyleKey: EnvironmentKey {
    static let defaultValue = AppFramePreset.pastel.builtInStyle()
}

extension EnvironmentValues {
    var busFrameStyle: AppFrameResolvedStyle {
        get { self[BusFrameStyleKey.self] }
        set { self[BusFrameStyleKey.self] = newValue }
    }
}

struct BusCardBackground: View {
    let style: AppFrameResolvedStyle

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

struct BusMainScreenThemeModifier: ViewModifier {
    @Environment(AppAppearanceStore.self) private var appearance
    @Environment(ColorThemeManager.self) private var themeManager

    func body(content: Content) -> some View {
        let frameStyle = appearance.resolvedFrameStyle()
        let cardFill = frameStyle.cardFill
        let cardScheme: ColorScheme = cardFill.relativeLuminance > 0.18 ? .light : .dark
        let accent = themeManager.currentTheme.accentColor.readable(against: cardFill)

        content
            .environment(\.busFrameStyle, frameStyle)
            .environment(\.cardFillColor, cardFill)
            .environment(\.colorScheme, cardScheme)
            .tint(accent)
    }
}

extension View {
    func busMainScreenThemed() -> some View {
        modifier(BusMainScreenThemeModifier())
    }
}
