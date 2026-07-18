import SwiftUI

private enum AppearanceSheet: Identifiable {
    case frameEditor
    case sceneColorPicker
    var id: Self { self }
}

struct AppearanceSettingsView: View {
    @Environment(AppAppearanceStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @State private var activeSheet: AppearanceSheet?

    var body: some View {
        Form {
            // MARK: 枠や見出し
            Section {
                ForEach(AppFramePreset.builtInSelectable) { preset in
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            store.applyBuiltInFrame(preset)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            presetPreview(preset)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 6) {
                                    Image(systemName: preset.symbolName)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(AppLocaleString.text(preset.displayName, locale: locale))
                                        .font(.body)
                                        .fontWeight(store.framePreset == preset ? .semibold : .regular)
                                        .foregroundStyle(.primary)
                                }
                            }
                            Spacer()
                            if store.framePreset == preset {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    activeSheet = .frameEditor
                } label: {
                    Label(AppLocaleString.text("カスタムで編集…", locale: locale), systemImage: "slider.horizontal.3")
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            } header: {
                Text(AppLocaleString.text("枠や見出し", locale: locale))
            } footer: {
                Text(AppLocaleString.text("メイン画面のカードや枠線のスタイルを変更します。", locale: locale))
            }

            // MARK: テクスチャ
            Section {
                ForEach(AppTexture.allCases) { tex in
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            store.texture = tex
                        }
                    } label: {
                        HStack {
                            Label(AppLocaleString.text(tex.displayName, locale: locale), systemImage: tex.symbolName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if store.texture == tex {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(AppLocaleString.text("テクスチャ", locale: locale))
            } footer: {
                Text(AppLocaleString.text("メイン画面の背景に重ねる模様を選びます。", locale: locale))
            }

            // MARK: 下地・シーン色
            Section {
                ForEach(AppSceneTint.selectable, id: \.self) { preset in
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            store.applySceneTint(preset)
                        }
                    } label: {
                        HStack {
                            sceneTintLabel(preset)
                            Spacer()
                            if store.matchesSceneTint(preset) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    activeSheet = .sceneColorPicker
                } label: {
                    HStack {
                        Label(AppLocaleString.text("カスタム…", locale: locale), systemImage: "slider.horizontal.3")
                            .foregroundStyle(.primary)
                        Spacer()
                        if store.matchesSceneTint(.custom) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text(AppLocaleString.text("下地・シーン色", locale: locale))
            } footer: {
                Text(AppLocaleString.text("アプリ背景の下地色を変更します。テクスチャと組み合わせて使えます。", locale: locale))
            }

            // MARK: プレビュー
            Section(AppLocaleString.text("プレビュー", locale: locale)) {
                ZStack {
                    AppearanceBackgroundLayer(
                        texture: store.texture,
                        colorScheme: colorScheme,
                        sceneColor: store.resolvedSceneColor(colorScheme: colorScheme)
                    )
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    HStack(spacing: 10) {
                        ForEach(0 ..< 2) { _ in
                            previewCard
                        }
                    }
                    .padding()
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }
        }
        .navigationTitle(AppLocaleString.text("外観", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
        .hiddenBackButtonWithSwipe()
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .frameEditor:
                AppearanceFrameEditorSheet()
                    .environment(store)
            case .sceneColorPicker:
                AppearanceSceneColorSheet(
                    seedColor: store.pickerSeedColor,
                    onApply: { store.setSceneColor(from: $0) }
                )
            }
        }
    }

    // MARK: - Helpers

    private func presetPreview(_ preset: AppFramePreset) -> some View {
        let style = preset.builtInStyle()
        return HStack(spacing: 4) {
            ForEach(style.previewSwatches, id: \.self) { color in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 14, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(.separator), lineWidth: 0.4))
            }
        }
    }

    private func sceneTintLabel(_ preset: AppSceneTint) -> some View {
        let accentColor: Color = {
            switch preset {
            case .systemAdaptive: return .primary
            case .ivory:      return Color(red: 253/255, green: 252/255, blue: 240/255)
            case .skyBlue:    return Color(red: 0.88, green: 0.94, blue: 0.99)
            case .mint:       return Color(red: 0.90, green: 0.98, blue: 0.94)
            case .sand:       return Color(red: 0.96, green: 0.90, blue: 0.78)
            case .lavender:   return Color(red: 0.92, green: 0.88, blue: 0.99)
            case .terracotta: return Color(red: 0.94, green: 0.72, blue: 0.62)
            case .custom:     return .secondary
            }
        }()
        return Label {
            Text(AppLocaleString.text(preset.displayName, locale: locale))
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: preset.symbolName)
                .foregroundStyle(
                    preset == .systemAdaptive || preset == .custom
                        ? AnyShapeStyle(.secondary)
                        : AnyShapeStyle(accentColor)
                )
                .background(
                    preset != .systemAdaptive && preset != .custom
                        ? RoundedRectangle(cornerRadius: 4).fill(Color(.systemBackground)).frame(width: 24, height: 24)
                        : nil
                )
        }
    }

    private var previewCard: some View {
        let style = store.resolvedFrameStyle()
        return RoundedRectangle(cornerRadius: 10)
            .fill(style.cardFill)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(style.cardBorder, lineWidth: style.borderWidth))
            .frame(height: 72)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(style.accentStrip)
                    .frame(width: 4)
                    .padding(.vertical, 12)
                    .padding(.leading, 8)
            }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
    .environment(AppAppearanceStore.shared)
    .environment(ColorThemeManager.shared)
}
