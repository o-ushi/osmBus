import SwiftUI
import WidgetKit

/// 文字盤に置く起動ボタン。距離などは出さず、タップで Watch の osmBus を開くだけ。
/// 中身が変わらないので、タイムラインは 1 件で更新しない。
@main
struct LaunchComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.osamushikubo.osmBus.launch", provider: Provider()) { _ in
            LaunchComplicationView()
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(Text("osmBus を開く"))
        .description(Text("文字盤から osmBus を開きます。"))
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry { SimpleEntry() }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry()], policy: .never))
    }
}

private struct SimpleEntry: TimelineEntry {
    let date = Date.distantPast
}

private struct LaunchComplicationView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("osmBus", systemImage: "bus.fill")
        case .accessoryCorner:
            Image(systemName: "bus.fill")
                .font(.title2)
                .widgetAccentable()
        default:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "bus.fill")
                    .font(.title2)
                    .widgetAccentable()
            }
        }
    }
}
