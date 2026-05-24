import SwiftUI

struct AppearanceFrameEditorSheet: View {
    @Environment(AppAppearanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            Form {
                Section(AppLocaleString.text("プリセットから始める", locale: locale)) {
                    ForEach(AppFramePreset.builtInSelectable) { preset in
                        Button {
                            store.applyBuiltInFrame(preset)
                        } label: {
                            HStack(spacing: 12) {
                                swatchRow(preset.builtInStyle().previewSwatches)
                                Text(preset.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if store.framePreset == preset {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section(AppLocaleString.text("カラーをカスタム", locale: locale)) {
                    ColorPicker(AppLocaleString.text("カード背景", locale: locale), selection: colorBinding(\.cardFillR, \.cardFillG, \.cardFillB), supportsOpacity: false)
                    ColorPicker(AppLocaleString.text("枠線", locale: locale), selection: colorBinding(\.cardBorderR, \.cardBorderG, \.cardBorderB), supportsOpacity: false)
                    ColorPicker(AppLocaleString.text("アクセント", locale: locale), selection: colorBinding(\.accentR, \.accentG, \.accentB), supportsOpacity: false)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(format: AppLocaleString.text("枠線の太さ  %@ pt", locale: locale), String(format: "%.1f", store.customFrameColors.borderWidth)))
                            .font(.subheadline)
                        Slider(value: widthBinding, in: 0.5 ... 5.0, step: 0.5)
                    }
                    Toggle(AppLocaleString.text("ダークカード（文字色を自動調整）", locale: locale), isOn: darkCardBinding)
                }
            }
            .navigationTitle(AppLocaleString.text("枠・見出しのカスタム", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(AppLocaleString.text("完了", locale: locale))
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func swatchRow(_ colors: [Color]) -> some View {
        HStack(spacing: 4) {
            ForEach(colors, id: \.self) { c in
                RoundedRectangle(cornerRadius: 3)
                    .fill(c)
                    .frame(width: 16, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(.separator), lineWidth: 0.5))
            }
        }
    }

    private func colorBinding(
        _ rKey: WritableKeyPath<AppFrameCustomColors, Double>,
        _ gKey: WritableKeyPath<AppFrameCustomColors, Double>,
        _ bKey: WritableKeyPath<AppFrameCustomColors, Double>
    ) -> Binding<Color> {
        Binding(
            get: {
                Color(red: store.customFrameColors[keyPath: rKey],
                      green: store.customFrameColors[keyPath: gKey],
                      blue: store.customFrameColors[keyPath: bKey])
            },
            set: { color in
                if store.framePreset != .custom { store.switchToCustomFrame() }
                let ui = UIColor(color)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return }
                store.customFrameColors[keyPath: rKey] = Double(r)
                store.customFrameColors[keyPath: gKey] = Double(g)
                store.customFrameColors[keyPath: bKey] = Double(b)
            }
        )
    }

    private var widthBinding: Binding<Double> {
        Binding(
            get: { store.customFrameColors.borderWidth },
            set: { v in
                if store.framePreset != .custom { store.switchToCustomFrame() }
                store.customFrameColors.borderWidth = v
            }
        )
    }

    private var darkCardBinding: Binding<Bool> {
        Binding(
            get: { store.customFrameColors.isDarkCard },
            set: { v in
                if store.framePreset != .custom { store.switchToCustomFrame() }
                store.customFrameColors.isDarkCard = v
            }
        )
    }
}
