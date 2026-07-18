import SwiftUI

struct AppearanceSceneColorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    var seedColor: Color
    var onApply: (Color) -> Void
    @State private var selection: Color = .gray

    var body: some View {
        NavigationStack {
            Form {
                ColorPicker(AppLocaleString.text("シーン色", locale: locale), selection: $selection, supportsOpacity: false)
            }
            .navigationTitle(AppLocaleString.text("カスタム下地色", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { selection = seedColor }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { onApply(selection); dismiss() } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(AppLocaleString.text("適用", locale: locale))
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
