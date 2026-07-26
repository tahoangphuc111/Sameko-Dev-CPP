import SwiftUI

struct WorkspaceView: View {
    @Bindable var model: WorkspaceModel
    @State private var sidebarVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            FileSidebar(model: model)
                .navigationSplitViewColumnWidth(min: 190, ideal: 250, max: 340)
        } detail: {
            VStack(spacing: 0) {
                workspaceToolbar
                Divider()
                editor
                Divider()
                ConsoleView(output: model.output, isRunning: model.isRunning)
                    .frame(minHeight: 148, idealHeight: 190, maxHeight: 260)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .navigationTitle(model.workspaceURL?.lastPathComponent ?? "Sameko IDE")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: model.buildAndRun) {
                    Label("Build & Run", systemImage: "play.fill")
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(model.isRunning)

                Button(action: model.stop) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!model.isRunning)

                Menu {
                    Toggle("Liquid Glass", isOn: $model.glassEnabled)
                    Picker("Style", selection: $model.glassStyle) {
                        ForEach(WorkspaceModel.GlassStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                } label: {
                    Label("Appearance", systemImage: "slider.horizontal.3")
                }
            }
        }
    }

    private var workspaceToolbar: some View {
        HStack(spacing: 10) {
            Text(model.selectedFile?.name ?? "Untitled.cpp")
                .font(.headline)
            Spacer()
            Text(model.isRunning ? "Running" : "Ready")
                .font(.caption)
                .foregroundStyle(model.isRunning ? .orange : .secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .modifier(GlassChrome(enabled: model.glassEnabled, style: model.glassStyle))
    }

    private var editor: some View {
        TextEditor(text: $model.source)
            .font(.system(.body, design: .monospaced))
            .lineSpacing(3)
            .padding(14)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct FileSidebar: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        List(selection: $model.selectedFile) {
            Section("Workspace") {
                if model.files.isEmpty {
                    ContentUnavailableView("No C++ files", systemImage: "folder", description: Text("Open a folder to start."))
                } else {
                    ForEach(model.files) { file in
                        Label(file.name, systemImage: file.id.pathExtension == "hpp" ? "curlybraces.square" : "doc.text")
                            .tag(file)
                    }
                }
            }
        }
        .onChange(of: model.selectedFile) { _, file in
            if let file { model.select(file) }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: model.openFolder) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
            }
        }
    }
}

private struct ConsoleView: View {
    let output: String
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(isRunning ? "Process" : "Output", systemImage: isRunning ? "circle.fill" : "terminal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isRunning ? .orange : .secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(.bar)

            ScrollView {
                Text(output)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(14)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct GlassChrome: ViewModifier {
    let enabled: Bool
    let style: WorkspaceModel.GlassStyle

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            if #available(macOS 26.0, *) {
                content.glassEffect(style == .clear ? .clear : .regular, in: .rect(cornerRadius: 0))
            } else {
                content.background(.bar)
            }
        } else {
            content.background(.bar)
        }
    }
}
