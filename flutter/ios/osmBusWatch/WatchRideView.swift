import SwiftUI

/// iPhone の乗車状態を映すだけの画面。地図・テンキー・設定は持たない。
struct WatchRideView: View {
    let store: WatchRideStore

    /// iPhone のバス番号長押しと同じ押下時間。
    private static let longPressDuration = 0.6

    var body: some View {
        let snapshot = store.snapshot
        VStack(spacing: 6) {
            if snapshot.isRiding, let busNumber = snapshot.busNumber {
                bigBusNumber(busNumber, hint: "長押しで降車")
                Text(snapshot.distanceText ?? "—")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let next = snapshot.nextTransferBusNumber {
                    transferRow(next)
                }
            } else if let boardBusNumber = snapshot.boardBusNumber {
                bigBusNumber(boardBusNumber, hint: "長押しで乗車")
            } else {
                Text("未乗車")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 4)
    }

    private func bigBusNumber(_ busNumber: String, hint: LocalizedStringKey) -> some View {
        Text(busNumber)
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: Self.longPressDuration) {
                store.sendLongPress(busNumber: busNumber)
            }
            .accessibilityHint(Text(hint))
    }

    private func transferRow(_ busNumber: String) -> some View {
        HStack(spacing: 6) {
            Text("乗換")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(busNumber)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: Self.longPressDuration) {
            store.sendLongPress(busNumber: busNumber)
        }
        .accessibilityHint(Text("長押しで乗車"))
    }
}
