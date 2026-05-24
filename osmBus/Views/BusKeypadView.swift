import SwiftUI

struct BusKeypadView: View {
    let busNumber: String
    let onCharacter: (String) -> Void
    let onDelete: () -> Void
    let onClear: () -> Void

    @Environment(\.busFrameStyle) private var frameStyle
    @Environment(\.mainScreenCompactLayout) private var compactLayout

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
                    keypadRow(["CLR", "0", ""], includesDelete: true)
                }
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
            .foregroundStyle(.primary)
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
        includesDelete: Bool = false,
        rowHeight: CGFloat = KeypadMetrics.keyHeight
    ) -> some View {
        HStack(spacing: KeypadMetrics.gridSpacing) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                if includesDelete && index == titles.count - 1 {
                    keypadDeleteButton {
                        onDelete()
                    }
                } else {
                    let keyStyle: KeyStyle = title == "CLR" ? .clear : style
                    keypadButton(title, style: keyStyle, rowHeight: rowHeight) {
                        if title == "CLR" {
                            onClear()
                        } else {
                            onCharacter(title)
                        }
                    }
                }
            }
        }
        .frame(height: rowHeight)
    }

    private func keypadDeleteButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "delete.backward")
                .font(.system(size: KeypadMetrics.deleteIconSize, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(.primary)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.keypadCornerRadius))
        }
        .buttonStyle(KeypadButtonStyle())
    }

    private func keypadButton(
        _ title: String,
        style: KeyStyle = .primary,
        rowHeight: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: KeypadMetrics.keyFontSize, weight: style == .primary ? .semibold : .bold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(.primary)
                .background(backgroundColor(for: style), in: RoundedRectangle(cornerRadius: AppTheme.keypadCornerRadius))
        }
        .buttonStyle(KeypadButtonStyle())
    }

    private func backgroundColor(for style: KeyStyle) -> Color {
        switch style {
        case .primary:
            return AppTheme.surfacePressed
        case .clear:
            return AppTheme.surface
        case .letter:
            return Color.white.opacity(0.2)
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
        BusKeypadView(busNumber: "35A", onCharacter: { _ in }, onDelete: {}, onClear: {})
            .padding()
            .frame(height: 360)
    }
}
