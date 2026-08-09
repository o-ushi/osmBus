import SwiftUI

struct ResultBannerView: View {
    let state: MainViewModel.ResultDisplayState
    let busNumber: String
    var onRetry: (() -> Void)?
    var onStartRiding: (() -> Void)?
    var onStartRidingWithVariant: ((String) -> Void)? = nil
    var isBoardingRouteCheapest: Bool = true
    var isRiding: Bool = false
    var onStopRiding: (() -> Void)? = nil
    var otherBoardableVariants: [String] = []

    @Environment(\.mainScreenCompactLayout) private var compactLayout
    @Environment(\.busCardStyle) private var cardStyle
    @Environment(\.locale) private var locale

    @State private var showsVariantPicker = false
    @State private var pendingVariantNames: [String] = []

    private var cardBg: Color { cardStyle.cardFill }

    private var verdictFontSize: CGFloat {
        compactLayout ? 24 : 30
    }

    private var shouldShowRidingOverride: Bool {
        isRiding
    }

    var body: some View {
        Group {
            if shouldShowRidingOverride {
                boardingVerdict(
                    AppLocaleString.text("乗車中", locale: locale),
                    color: Color.green.readable(against: cardBg)
                )
            } else { switch state {
            case .idle:
                idleContent
            case .checking:
                checkingContent
            case .canBoard(_, _, let directionHint):
                boardingVerdict(
                    AppLocaleString.text("乗ってください！", locale: locale),
                    color: Color.green.readable(against: cardBg),
                    directionHint: directionHint
                )
            case .canBoardIfVariant(let variantNames, _, _, let directionHint):
                boardingVerdict(
                    variantBoardMessage(for: variantNames),
                    color: verdictYellow.readable(against: cardBg),
                    directionHint: directionHint,
                    variantNames: variantNames,
                    otherVariants: otherBoardableVariants
                )
            case .cannotBoard:
                centeredVerdict(
                    AppLocaleString.text("見送ってください", locale: locale),
                    color: Color.red.readable(against: cardBg)
                )
            case .noTransitRoutes:
                noTransitRoutesContent
            case .trialExhausted:
                trialExhaustedContent
            case .error(let message):
                errorContent(message)
            } }  // switch + else
        }
        .padding(.horizontal, compactLayout ? 12 : 16)
        .padding(.vertical, compactLayout ? 10 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)
        .background(BusCardBackground(style: cardStyle))
        .animation(.easeInOut(duration: 0.2), value: state)
        .confirmationDialog(
            AppLocaleString.text("系統選択_タイトル", locale: locale),
            isPresented: $showsVariantPicker,
            titleVisibility: .visible
        ) {
            ForEach(pendingVariantNames, id: \.self) { name in
                Button(name) { onStartRidingWithVariant?(name) }
            }
            Button(AppLocaleString.text("キャンセル", locale: locale), role: .cancel) {}
        }
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

    @ViewBuilder
    private func boardingVerdict(_ text: String, color: Color, directionHint: String? = nil, variantNames: [String]? = nil, otherVariants: [String] = []) -> some View {
        VStack(spacing: compactLayout ? 5 : 8) {
            Text(text)
                .font(.system(size: verdictFontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.55)
                .lineLimit(3)

            if let directionHint {
                Label(directionHint, systemImage: "location.north.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if !otherVariants.isEmpty {
                Label(
                    AppLocaleString.text("他の系統も乗れるかも", locale: locale),
                    systemImage: "questionmark.circle"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(verdictYellow.readable(against: cardBg))
            }

            if isRiding {
                VStack(spacing: compactLayout ? 4 : 6) {
                    if let onStopRiding {
                        Button(action: onStopRiding) {
                            Label(
                                AppLocaleString.text("降車", locale: locale),
                                systemImage: "hand.raised.fill"
                            )
                            .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
            } else if let variants = variantNames, !variants.isEmpty, onStartRidingWithVariant != nil {
                Button {
                    if variants.count == 1, let only = variants.first {
                        onStartRidingWithVariant?(only)
                    } else {
                        pendingVariantNames = variants
                        showsVariantPicker = true
                    }
                } label: {
                    Label(
                        AppLocaleString.text("乗車開始", locale: locale),
                        systemImage: "map"
                    )
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(isBoardingRouteCheapest ? .blue : .green)
            } else if let onStartRiding {
                Button(action: onStartRiding) {
                    Label(
                        AppLocaleString.text("乗車開始", locale: locale),
                        systemImage: "map"
                    )
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(isBoardingRouteCheapest ? .blue : .green)
            }
        }
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
                            compactLayout ? "バス番号例" : "バス番号説明",
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
            return AppLocaleString.formatted("だったら乗ってください_%@", locale: locale, name)
        }
        return AppLocaleString.formatted("だったら乗ってください_複数_%@", locale: locale, joined)
    }

    private var noTransitRoutesContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.orange.opacity(0.95))
                Text(AppLocaleString.text("ルートなし", locale: locale))
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
            Text(AppLocaleString.text("お試し枠_使い切り", locale: locale))
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
