import SwiftUI

/// 保存済みの路線データベースを一覧し、選んだ路線を地図に出す。
struct BusRouteMapHistoryView: View {
    var isEmbedded = false
    var onSelect: (BusRouteListItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var items: [BusRouteListItem] = []

    var body: some View {
        Group {
            if isEmbedded {
                routeList
            } else {
                NavigationStack {
                    routeList
                }
            }
        }
        .environment(\.locale, locale)
        .lightSheetChrome()
        .onAppear { reload() }
    }

    private var routeList: some View {
        List {
            if items.isEmpty {
                Section {
                    ContentUnavailableView(
                        AppLocaleString.text("路線図_一覧_空状態", locale: locale),
                        systemImage: "list.bullet",
                        description: Text(AppLocaleString.text("路線図_一覧_空状態_詳細", locale: locale))
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                            if !isEmbedded { dismiss() }
                        } label: {
                            BusRouteCatalogRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(AppLocaleString.text("路線図_一覧", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reload() {
        var merged = BusRouteCatalogStore.listItems()
        let known = Set(merged.map(\.relationId))
        for record in BusLineMapStore.recentRecords() where !known.contains(record.relationId) {
            merged.append(
                BusRouteListItem(
                    relationId: record.relationId,
                    ref: record.ref,
                    name: record.name,
                    from: record.from,
                    to: record.to,
                    hasGeometry: true
                )
            )
        }
        items = merged.sorted { lhs, rhs in
            let order = lhs.ref.localizedStandardCompare(rhs.ref)
            if order != .orderedSame { return order == .orderedAscending }
            return (lhs.from ?? "") < (rhs.from ?? "")
        }
    }
}

struct BusRouteCatalogRow: View {
    let item: BusRouteListItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bus.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.ref)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle = item.directionText {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    BusRouteMapHistoryView(onSelect: { _ in })
        .environment(\.locale, Locale(identifier: "ja"))
}
