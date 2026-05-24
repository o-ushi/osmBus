import SwiftUI

struct ResultBannerView: View {
    let state: MainViewModel.ResultDisplayState
    let busNumber: String
    var onRetry: (() -> Void)?

    @Environment(\.mainScreenCompactLayout) private var compactLayout
    @Environment(\.busFrameStyle) private var frameStyle
    @Environment(\.locale) private var locale

    private var verdictFontSize: CGFloat {
        compactLayout ? 24 : 30
    }

    var body: some View {
        Group {
            switch state {
            case .idle:
                idleContent
            case .checking:
                checkingContent
            case .canBoard:
                centeredVerdict(
                    AppLocaleString.text("乗ってください！", locale: locale),
                    color: .green
                )
            case .canBoardIfVariant(let variantNames, _, _):
                centeredVerdict(
                    variantBoardMessage(for: variantNames),
                    color: verdictYellow
                )
            case .cannotBoard:
                centeredVerdict(
                    AppLocaleString.text("osmBus_見送ってください", locale: locale),
                    color: .red
                )
            case .noTransitRoutes:
                noTransitRoutesContent
            case .trialExhausted:
                trialExhaustedContent
            case .error(let message):
                errorContent(message)
            }
        }
        .padding(.horizontal, compactLayout ? 12 : 16)
        .padding(.vertical, compactLayout ? 10 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)
        .background(BusCardBackground(style: frameStyle))
        .animation(.easeInOut(duration: 0.2), value: state)
    }

    private var contentAlignment: Alignment {
        switch state {
        case .canBoard, .canBoardIfVariant, .cannotBoard:
            return .center
        case .trialExhausted:
            return .leading
        default:
            return .leading
        }
    }

    private var verdictYellow: Color {
        Color(red: 0.86, green: 0.62, blue: 0.04)
    }

    private func centeredVerdict(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: verdictFontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.55)
            .lineLimit(3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var idleContent: some View {
        HStack(spacing: compactLayout ? 10 : 14) {
            Image(systemName: "bus.fill")
                .font(compactLayout ? .title2 : .largeTitle)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: compactLayout ? 4 : 6) {
                if busNumber.isEmpty {
                    Text(AppLocaleString.text("バス番号を入力", locale: locale))
                        .font(.system(size: compactLayout ? 16 : 20, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(
                        AppLocaleString.text(
                            compactLayout ? "osmBus_バス番号例" : "osmBus_バス番号説明",
                            locale: locale
                        )
                    )
                    .font(.system(size: compactLayout ? 13 : 16))
                    .foregroundStyle(.secondary)
                    .lineLimit(compactLayout ? 1 : 2)
                    .minimumScaleFactor(0.85)
                } else {
                    Text("\(AppLocaleString.text("バス", locale: locale)) \(busNumber)")
                        .font(.system(size: compactLayout ? 16 : 20, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(AppLocaleString.text("ルートを確認しています…", locale: locale))
                        .font(.system(size: compactLayout ? 13 : 16))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var checkingContent: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(AppLocaleString.text("ルートを確認中…", locale: locale))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }

    private func variantBoardMessage(for variantNames: [String]) -> String {
        let joined = variantNames.joined(separator: "・")
        if variantNames.count == 1, let name = variantNames.first {
            return AppLocaleString.formatted("osmBus_だったら乗ってください_%@", locale: locale, name)
        }
        return AppLocaleString.formatted("osmBus_だったら乗ってください_複数_%@", locale: locale, joined)
    }

    private var noTransitRoutesContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.orange.opacity(0.95))
                Text(AppLocaleString.text("osmBus_ルートなし", locale: locale))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }

            if let onRetry {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(AppLocaleString.text("もう一度試す", locale: locale))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trialExhaustedContent: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "key.fill")
                .font(.body)
                .foregroundStyle(Color.orange.opacity(0.95))
            Text(AppLocaleString.text("osmBus_お試し枠_使い切り", locale: locale))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.body)
                    .foregroundStyle(Color.orange.opacity(0.95))
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }

            if let onRetry {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(AppLocaleString.text("もう一度試す", locale: locale))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Idle") {
    ZStack {
        AppTheme.brandBlue.ignoresSafeArea()
        ResultBannerView(state: .idle, busNumber: "")
            .padding()
    }
}
