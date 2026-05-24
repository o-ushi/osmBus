import SwiftUI

struct APIKeySetupBanner: View {
    var isTrialExhausted = false
    let onOpenSettings: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: onOpenSettings) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isTrialExhausted ? "key.fill" : "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(isTrialExhausted ? .orange : .yellow)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        AppLocaleString.text(
                            isTrialExhausted ? "osmBus_お試し終了_タイトル" : "osmBus_APIキー未設定",
                            locale: locale
                        )
                    )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .multilineTextAlignment(.leading)

                    Text(
                        AppLocaleString.text(
                            isTrialExhausted ? "osmBus_お試し終了_説明" : "osmBus_APIキー未設定_説明",
                            locale: locale
                        )
                    )
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.top, 2)
            }
            .padding(.horizontal, AppTheme.cardPaddingH)
            .padding(.vertical, 10)
            .background(Color.orange.opacity(0.22), in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityHint(AppLocaleString.text("osmBus_設定画面を開くヒント", locale: locale))
    }
}

#Preview {
    ZStack {
        AppTheme.brandBlue.ignoresSafeArea()
        APIKeySetupBanner(onOpenSettings: {})
            .environment(\.locale, Locale(identifier: "ja"))
            .padding()
    }
}
