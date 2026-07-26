import SwiftUI

@main
struct SamekoMacApp: App {
    @State private var model = WorkspaceModel()

    var body: some Scene {
        WindowGroup("Sameko IDE") {
            WorkspaceView(model: model)
                .frame(minWidth: 960, minHeight: 640)
        }
        .defaultSize(width: 1280, height: 820)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New C++ File") { model.newFile() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Open Folder…") { model.openFolder() }
                    .keyboardShortcut("o", modifiers: .command)
            }

            CommandMenu("Run") {
                Button("Build & Run") { model.buildAndRun() }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                Button("Stop") { model.stop() }
                    .keyboardShortcut(".", modifiers: .command)
                    .disabled(!model.isRunning)
            }
        }
    }
}
