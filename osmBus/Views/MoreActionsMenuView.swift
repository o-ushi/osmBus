import SwiftUI

struct MoreActionsMenuView: View {
    @Environment(\.locale) private var locale

    let onHistory: () -> Void
    let onRegisterPlace: () -> Void
    let onSettings: () -> Void
    let onPlanManagement: () -> Void
    let onHelp: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                menuButton("履歴", systemImage: "clock.arrow.circlepath", action: onHistory)
                menuButton("場所を登録", systemImage: "mappin.and.ellipse", action: onRegisterPlace)

                menuDivider

                menuButton("設定", systemImage: "gearshape", action: onSettings)
                planManagementButton
                menuButton("ヘルプ", systemImage: "questionmark.circle", action: onHelp)
            }
            .padding(.vertical, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: 286)
        .frame(maxHeight: 620)
    }

    private var planManagementButton: some View {
        Button(action: onPlanManagement) {
            HStack(spacing: 14) {
                Image(systemName: "crown")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                Text(AppLocaleString.text("プラン管理", locale: locale))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 54, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func menuButton(
        _ titleKey: String,
        systemImage: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                Text(AppLocaleString.text(titleKey, locale: locale))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 54, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }

    private var menuDivider: some View {
        Divider()
            .padding(.vertical, 8)
            .padding(.leading, 56)
    }
}

#Preview {
    MoreActionsMenuView(
        onHistory: {},
        onRegisterPlace: {},
        onSettings: {},
        onPlanManagement: {},
        onHelp: {}
    )
}
