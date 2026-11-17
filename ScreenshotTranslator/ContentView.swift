import SwiftUI
import Translation

struct ContentView: View {
    @StateObject private var state = TranslationState.shared
    @State private var configuration: TranslationSession.Configuration?
    @State private var extractedBlocks: [RecognizedBlock] = []
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 16) {
            if isProcessing {
                ProgressView("Translating Screenshot...")
            } else {
                Text("Run the 'Translate Screenshot' Shortcut to begin.")
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: state.incomingImage) { _, newImage in
            guard let image = newImage else { return }
            Task {
                isProcessing = true
                extractedBlocks = (try? await OverlayProcessor.extractText(from: image)) ?? []
                // Trigger Apple Translation session (auto-detect source -> device language)
                configuration = TranslationSession.Configuration()
            }
        }
        .translationTask(configuration) { session in
            guard let image = state.incomingImage, !extractedBlocks.isEmpty else {
                isProcessing = false
                return
            }
            do {
                let requests = extractedBlocks.enumerated().map { index, block in
                    TranslationSession.Request(sourceText: block.text, clientIdentifier: "\(index)")
                }
                let responses = try await session.translations(from: requests)
                let translatedStrings = responses.map { $0.targetText }
                
                if let url = OverlayProcessor.renderOverlay(on: image, blocks: extractedBlocks, translations: translatedStrings) {
                    state.previewFileURL = url
                }
            } catch {
                print("Translation error: \(error)")
            }
            isProcessing = false
        }
        .sheet(item: Binding(
            get: { state.previewFileURL.map { IdentifiableURL(url: $0) } },
            set: { if $0 == nil { state.previewFileURL = nil } }
        )) { item in
            QuickLookPreview(url: item.url)
                .ignoresSafeArea()
        }
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}