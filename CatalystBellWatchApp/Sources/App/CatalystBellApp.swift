import SwiftUI

@main
struct CatalystBellApp: App {
    @StateObject private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--debug-rain-surface") {
                    RainSurfaceDebugHarness()
                } else {
                    ContentView()
                }
                #else
                ContentView()
                #endif
            }
                .environmentObject(sessionManager)
                .tint(StillRainPalette.accent)
                .onOpenURL { url in
                    guard let deepLink = CatalystBellDeepLink(url: url) else { return }

                    switch deepLink {
                    case let .start(source):
                        sessionManager.start(launchSource: source)
                    }
                }
        }
    }
}
