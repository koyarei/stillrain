import SwiftUI
import WidgetKit

struct StillRainEntry: TimelineEntry {
    let date: Date
}

struct StillRainProvider: TimelineProvider {
    func placeholder(in context: Context) -> StillRainEntry {
        StillRainEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (StillRainEntry) -> Void) {
        completion(StillRainEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StillRainEntry>) -> Void) {
        completion(Timeline(entries: [StillRainEntry(date: Date())], policy: .never))
    }
}

struct StillRainComplicationView: View {
    var body: some View {
        Image("StillRainComplicationSymbol")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(.white)
            .padding(5)
        .containerBackground(.black, for: .widget)
        .widgetURL(URL(string: "stillrain://start?source=complication"))
    }
}

struct StillRainComplication: Widget {
    let kind = "StillRainComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StillRainProvider()) { _ in
            StillRainComplicationView()
        }
        .configurationDisplayName("StillRain")
        .description("Start a discreet haptic anchor.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular
        ])
    }
}

@main
struct StillRainComplicationBundle: WidgetBundle {
    var body: some Widget {
        StillRainComplication()
    }
}
