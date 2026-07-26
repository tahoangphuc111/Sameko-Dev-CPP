import AppKit
import SwiftUI

@main
struct SamekoMacApp: App {
    @State private var model = WorkspaceModel()

    init() {
        // Establish the AppKit appearance before SwiftUI creates the window so
        // the native title bar and embedded controls never flash in light mode.
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    }

    var body: some Scene {
        WindowGroup("Sameko IDE") {
            WorkspaceView(model: model)
                .frame(minWidth: 960, minHeight: 640)
                .overlay { WindowStateRestorer().frame(width: 0, height: 0) }
        }
        .defaultSize(width: 1280, height: 820)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New C++ File") { model.newFile() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Open Folder…") { model.openFolder() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Save") { try? model.save() }
                    .keyboardShortcut("s", modifiers: .command)
                Button("Save As…") { model.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandMenu("Run") {
                Button("Build & Run") { model.buildAndRun() }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                Button("Stop") { model.stop() }
                    .keyboardShortcut(".", modifiers: .command)
                    .disabled(!model.isRunning)
                Button("Start Debugging") { model.startDebugging() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }

            CommandMenu("Source") {
                Button("Format Source") { model.formatSource() }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                Button("Check Syntax") { model.checkSyntax() }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                Button("Inspect Symbol") { model.inspectSymbolAtCursor() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
            }

            CommandMenu("View") {
                Button("Command Palette…") { model.commandPaletteVisible = true }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                Button("Toggle Explorer") { model.showExplorer.toggle() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Toggle Split Editor") { model.showSplitEditor.toggle() }
                    .keyboardShortcut("\\", modifiers: [.command])
            }
        }
    }
}
