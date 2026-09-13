import SwiftUI

/// `BusLineMapStore` にキャッシュ済みの路線図を一覧表示し、選んだ路線をキャッシュから即復元する。
/// Overpass への再取得はしない。
struct BusRouteMapHistoryView: View {
    var isEmbedded = false
    var onSelect: (BusRouteDetail) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var records: [BusLineMapStore.Record] = []

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
        .lightSheetChrome()
        .onAppear { reload() }
    }

    private var historyList: some View {
        List {
            if records.isEmpty {
                Section {
                    ContentUnavailableView(
                        AppLocaleString.text("路線図_履歴_空状態", locale: locale),
                        systemImage: "clock.arrow.circlepath",
                        description: Text(AppLocaleString.text("路線図_履歴_空状態_詳細", locale: locale))
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(records, id: \.relationId) { record in
                        Button {
                            select(record)
                        } label: {
                            BusRouteMapHistoryRow(record: record)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                forget(record)
                            } label: {
                                Label(AppLocaleString.text("削除", locale: locale), systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteRecords)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(AppLocaleString.text("路線図_履歴", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reload() {
        records = BusLineMapStore.recentRecords()
            .sorted { $0.ref.localizedStandardCompare($1.ref) == .orderedAscending }
    }

    private func select(_ record: BusLineMapStore.Record) {
        guard let detail = BusLineMapStore.detail(forRelationId: record.relationId) else { return }
        onSelect(detail)
        if !isEmbedded {
            dismiss()
        }
    }

    private func forget(_ record: BusLineMapStore.Record) {
        BusLineMapStore.forget(relationId: record.relationId)
        reload()
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            BusLineMapStore.forget(relationId: records[index].relationId)
        }
        reload()
    }
}

private struct BusRouteMapHistoryRow: View {
    let record: BusLineMapStore.Record

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bus.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.ref)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(Self.relativeFormatter.localizedString(for: record.lastUsedAt, relativeTo: Date()))
                    .font(.caption)
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String? {
        if let from = record.from, let to = record.to, !from.isEmpty, !to.isEmpty {
            return "\(from) → \(to)"
        }
        return record.name != record.ref ? record.name : nil
    }
}

#Preview {
    BusRouteMapHistoryView(onSelect: { _ in })
        .environment(\.locale, Locale(identifier: "ja"))
}
