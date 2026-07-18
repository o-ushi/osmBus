import SwiftUI

struct DestinationHistoryView: View {
    let currentDestination: Destination?
    var isEmbedded = false
    let onSelectDestination: (Destination) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(PlanStore.self) private var planStore
    @State private var entries: [DestinationHistoryEntry] = []
    @State private var showsClearConfirmation = false

    var body: some View {
        Group {
            if isEmbedded {
                historyList
            } else {
                NavigationStack {
                    historyList
                }
            }
        }
        .environment(\.locale, locale)
        .preferredColorScheme(.light)
        .tint(.blue)
    }

    private var historyList: some View {
        List {
            if entries.isEmpty {
                Section {
                    ContentUnavailableView(
                        AppLocaleString.text("履歴がありません", locale: locale),
                        systemImage: "clock.arrow.circlepath",
                        description: Text(AppLocaleString.text("目的地を設定すると、ここに履歴として表示されます。", locale: locale))
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(entries) { entry in
                        Button {
                            selectDestination(entry.destination)
                        } label: {
                            DestinationHistoryRow(
                                entry: entry,
                                isCurrentDestination: isCurrentDestination(entry.destination)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(AppLocaleString.text("目的地の履歴", locale: locale))
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppLocaleString.text("タップすると、その目的地を設定します。", locale: locale))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                        if planStore.isFree {
                            Text(AppLocaleString.formatted("履歴_FREE上限", locale: locale, PlanStore.freeItemLimit))
                                .foregroundStyle(Color(UIColor.secondaryLabel))
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showsClearConfirmation = true
                    } label: {
                        Label(
                            AppLocaleString.text("履歴を消去", locale: locale),
                            systemImage: "trash"
                        )
                    }
                } footer: {
                    Text(AppLocaleString.text("履歴消去フッター", locale: locale))
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle(AppLocaleString.text("履歴", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
        .hiddenBackButtonWithSwipe()
        .confirmationDialog(
            AppLocaleString.text("履歴をすべて消去しますか？", locale: locale),
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppLocaleString.text("履歴を消去", locale: locale), role: .destructive) {
                DestinationHistoryStore.clearAll()
                reloadEntries()
            }
            Button(AppLocaleString.text("キャンセル", locale: locale), role: .cancel) {}
        } message: {
            Text(AppLocaleString.text("この操作は取り消せません。", locale: locale))
        }
        .onAppear {
            reloadEntries()
        }
    }

    private func reloadEntries() {
        entries = DestinationHistoryStore.loadAll()
    }

    private func selectDestination(_ destination: Destination) {
        onSelectDestination(destination)
        if !isEmbedded {
            dismiss()
        }
    }

    private func isCurrentDestination(_ destination: Destination) -> Bool {
        guard let currentDestination else { return false }
        return DestinationHistoryStore.matches(currentDestination, destination)
    }
}

private struct DestinationHistoryRow: View {
    let entry: DestinationHistoryEntry
    let isCurrentDestination: Bool

    @Environment(\.locale) private var locale

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.destination.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let subtitle = entry.destination.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(Self.relativeFormatter.localizedString(for: entry.setAt, relativeTo: Date()))
                    .font(.caption)
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }

            Spacer(minLength: 8)

            if isCurrentDestination {
                Text(AppLocaleString.text("設定中", locale: locale))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    DestinationHistoryView(currentDestination: nil, onSelectDestination: { _ in })
        .environment(PlanStore.shared)
        .environment(\.locale, Locale(identifier: "ja"))
}
