//
//  appintents.swift
//  UPSext
//
//  Created by Mark Clayton on 11/15/25.
//

import AppIntents

struct GetStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get the unit status"
    static let description: LocalizedStringResource = "Gets the status of the unit"

    /// Launch your app when the system triggers this intent.
    static let openAppWhenRun: Bool = true

    @Parameter(
        //title: "Files",
        //description: "Files to Transfer",
        //supportedTypeIdentifiers: ["public.image"],
        //inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var fileURLs: [IntentFile]?

    /// Define the method that the system calls when it triggers this event.
    @MainActor
    func perform() async throws -> some IntentResult {
        if let fileURLs = fileURLs?.compactMap({ $0.fileURL }), !fileURLs.isEmpty {
            /// Import and handle file URLs
        }

        /// Deeplink into the Transfer Creation page
        //DeepLinkManager.handle(TransferURLScheme.createTransferFromShareExtension)

        /// Return an empty result since we're opening the app
        return .result()
    }
}

struct UPSAppShortcutProvider: AppShortcutsProvider {
    // 2.
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        // 3.
        AppShortcut(
            intent: GetStatusIntent(),
            phrases: [
                "Get status in ${applicationName}",
                "Check unit status in ${applicationName}"
            ],
            shortTitle: "Get Status",
            systemImageName: "gauge"
        )
        
        AppShortcut(
            intent: GetStatusIntent(),
            phrases: [
                "Open ${applicationName}",
                "Show status in ${applicationName}"
            ],
            shortTitle: "Open App",
            systemImageName: "app"
        )
    }
}
