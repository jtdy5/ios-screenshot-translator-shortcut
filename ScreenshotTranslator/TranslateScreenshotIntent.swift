import AppIntents
import SwiftUI

struct TranslateScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Screenshot Overlay"
    static var description = IntentDescription("Receives a screenshot, translates text using Apple Translation, and opens a Quick Look overlay.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Screenshot")
    var screenshot: IntentFile

    @MainActor
    func perform() async throws -> some IntentResult {
        if let image = UIImage(data: screenshot.data) {
            TranslationState.shared.incomingImage = image
        }
        return .result()
    }
}

struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateScreenshotIntent(),
            phrases: ["Translate screenshot with \(.applicationName)"],
            shortTitle: "Translate Screenshot",
            systemImageName: "text.viewfinder"
        )
    }
}