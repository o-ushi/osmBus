import SwiftUI
import UIKit

struct BusKeypadView: View {
    let busNumber: String
    let canSubmit: Bool
    var isDisabled: Bool = false
    let onCharacter: (String) -> Void
    let onSubmit: () -> Void
    let onClear: () -> Void

    @Environment(\.busFrameStyle) private var frameStyle
    @Environment(\.mainScreenCompactLayout) private var compactLayout
    @Environment(\.locale) private var locale

    var body: some View {
        GeometryReader { geometry in
            let metrics = KeypadLayoutMetrics.resolved(
                containerHeight: geometry.size.height,
                compactLayout: compactLayout
            )
            let rowSpacing = Self.rowSpacing(
                containerHeight: geometry.size.height,
                metrics: metrics
            )

            VStack(spacing: 0) {
                busNumberDisplay(metrics: metrics)
                    .padding(.bottom, metrics.displayBottomSpacing)

                Spacer(minLength: 0)

                VStack(spacing: rowSpacing) {
                    keypadRow(["1", "2", "3"])
                    keypadRow(["4", "5", "6"])
                    keypadRow(["7", "8", "9"])
                    keypadRow(["CLR", "0", ""], includesEnter: true)
                }
                .disabled(isDisabled)
            }
            .padding(.horizontal, KeypadMetrics.edgePaddingHorizontal)
            .padding(.top, metrics.edgePaddingTop)
            .padding(.bottom, metrics.edgePaddingBottom + KeypadMetrics.cardBottomInset)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .background(BusCardBackground(style: frameStyle))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private static func rowSpacing(
        containerHeight: CGFloat,
        metrics: KeypadLayoutMetrics
    ) -> CGFloat {
        let slack = containerHeight - metrics.totalFixedHeight
        guard slack > 0 else { return KeypadMetrics.gridSpacing }
        return KeypadMetrics.gridSpacing + slack / 3
    }

    private func busNumberDisplay(metrics: KeypadLayoutMetrics) -> some View {
        Text(busNumber.isEmpty ? "—" : busNumber)
            .font(.system(size: metrics.busNumberFontSize, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .foregroundStyle(isDisabled ? Color.secondary : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: metrics.displayHeight, alignment: .center)
            .multilineTextAlignment(.center)
            .animation(.snappy, value: busNumber)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private enum KeyStyle {
        case primary
        case clear
        case letter
    }

    private func keypadRow(
        _ titles: [String],
        style: KeyStyle = .primary,
        includesEnter: Bool = false,
        rowHeight: CGFloat = KeypadMetrics.keyHeight
    ) -> some View {
        let regularTitles = includesEnter ? Array(titles.dropLast()) : titles
        return HStack(spacing: KeypadMetrics.gridSpacing) {
            ForEach(Array(regularTitles.enumerated()), id: \.offset) { _, title in
                let keyStyle: KeyStyle = title == "CLR" ? .clear : style
                keypadButton(title, style: keyStyle, rowHeight: rowHeight) {
                    if title == "CLR" { onClear() } else { onCharacter(title) }
                }
            }
            if includesEnter {
                keypadEnterButton { onSubmit() }
            }
        }
        .frame(height: rowHeight)
    }

    private static let enterSymbolName: String =
        ["return", "arrow.turn.down.left"].first { UIImage(systemName: $0) != nil } ?? "return"

    private var isLightCard: Bool {
        frameStyle.cardFill.relativeLuminance > 0.18
    }

    private func keypadEnterButton(action: @escaping () -> Void) -> some View {
        let active = canSubmit && !isDisabled
        return Button {
            guard canSubmit else { return }
            KeypadFeedbackSettings.triggerEnterKey()
            action()
        } label: {
            Image(systemName: Self.enterSymbolName)
                .font(.system(size: KeypadMetrics.deleteIconSize + 2, weight: .bold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(active ? .white : Color.secondary)
                .background(
                    active ? Color.green : backgroundColor(for: .clear),
                    in: RoundedRectangle(cornerRadius: AppTheme.keypadCornerRadius)
                )
                .animation(.easeInOut(duration: 0.18), value: active)
        }
        .buttonStyle(KeypadButtonStyle())
        .accessibilityLabel(AppLocaleString.text("テンキー_判定", locale: locale))
    }

    private func keypadButton(
        _ title: String,
        style: KeyStyle = .primary,
        rowHeight: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            KeypadFeedbackSettings.triggerKeyTap()
            action()
        } label: {
            Text(title)
                .font(.system(size: KeypadMetrics.keyFontSize, weight: style == .primary ? .semibold : .bold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(isDisabled ? Color.secondary : Color.primary)
                .background(backgroundColor(for: style), in: RoundedRectangle(cornerRadius: AppTheme.keypadCornerRadius))
        }
        .buttonStyle(KeypadButtonStyle())
    }

    // カード背景の明暗に応じてボタン面の色を選ぶ。
    // 明るいカード: 黒い薄膜でキーの輪郭を出す。暗いカード: 白い薄膜。
    private func backgroundColor(for style: KeyStyle) -> Color {
        switch style {
        case .primary:
            return isLightCard ? Color.black.opacity(0.08) : Color.white.opacity(0.22)
        case .clear:
            return isLightCard ? Color.black.opacity(0.05) : Color.white.opacity(0.14)
        case .letter:
            return isLightCard ? Color.black.opacity(0.06) : Color.white.opacity(0.20)
        }
    }
}

private struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        AppTheme.brandBlue.ignoresSafeArea()
        BusKeypadView(
            busNumber: "35",
            canSubmit: true,
            onCharacter: { _ in },
            onSubmit: {},
            onClear: {}
        )
            .padding()
            .frame(height: 360)
    }
}
