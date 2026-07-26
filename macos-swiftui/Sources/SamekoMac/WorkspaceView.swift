import SwiftUI

struct WorkspaceView: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(model: model)
            HStack(spacing: 8) {
                if model.showExplorer { Explorer(model: model).frame(width: 218) }
                VStack(spacing: 8) {
                    EditorDeck(model: model)
                    BottomDeck(model: model).frame(minHeight: 180, idealHeight: 220, maxHeight: 290)
                }
                if model.showTests { TestRail(model: model).frame(width: 238) }
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            StatusBar(model: model)
        }
        .background(WorkspaceBackdrop(theme: model.theme))
        .overlay {
            if model.commandPaletteVisible { CommandPalette(model: model) }
        }
        .sheet(item: $model.settingsSection) { section in SettingsSheet(model: model, section: section) }
        .onChange(of: model.glassEnabled) { _, _ in model.persistPreferences() }
        .onChange(of: model.glassStyle) { _, _ in model.persistPreferences() }
        .onChange(of: model.cppStandard) { _, _ in model.persistPreferences() }
        .onChange(of: model.optimization) { _, _ in model.persistPreferences() }
        .onChange(of: model.warningsEnabled) { _, _ in model.persistPreferences() }
        .onChange(of: model.extraFlags) { _, _ in model.persistPreferences() }
        .onChange(of: model.singleFileCompile) { _, _ in model.persistPreferences() }
        .onChange(of: model.theme) { _, _ in model.persistPreferences() }
        .onChange(of: model.editorFontSize) { _, _ in model.persistPreferences() }
        .onChange(of: model.editorTabSize) { _, _ in model.persistPreferences() }
        .onChange(of: model.editorWordWrap) { _, _ in model.persistPreferences() }
        .onChange(of: model.autoSaveEnabled) { _, _ in model.persistPreferences() }
        .onChange(of: model.autoSaveDelay) { _, _ in model.persistPreferences() }
    }
}

private struct AppHeader: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        HStack(spacing: 8) {
            Text("C++").font(.caption.weight(.heavy)).foregroundStyle(.black)
                .frame(width: 38, height: 26).background(.lime).clipShape(Capsule())
            Menu("File") { Button("New File", action: model.newFile); Button("New File in Workspace", action: model.createFileInWorkspace); Button("New Folder", action: model.createFolderInWorkspace); Divider(); Button("Save") { try? model.save() }; Button("Save As…", action: model.saveAs); Button("Open Folder…", action: model.openFolder) }
            Menu("Edit") { Button("Save") { try? model.save() }; Button("Format Source", action: model.formatSource) }
            Menu("View") { Toggle("Explorer", isOn: $model.showExplorer); Toggle("Tests", isOn: $model.showTests); Toggle("Split Editor", isOn: $model.showSplitEditor) }
            Menu("Run") { Button("Build & Run", action: model.buildAndRun); Button("Start Debugging", action: model.startDebugging); Button("Stop", action: model.stop) }
            Divider().frame(height: 22)
            TabStrip(model: model)
            Button(action: model.newFile) { Image(systemName: "plus") }.buttonStyle(.plain).padding(5)
            Spacer(minLength: 4)
            HeaderIcon("sidebar.left", action: { model.showExplorer.toggle() })
            HeaderIcon("magnifyingglass", action: { model.commandPaletteVisible = true })
            HeaderIcon("ladybug", action: model.startDebugging)
            HeaderIcon("gearshape", action: { model.settingsSection = .appearance })
            Button(action: model.buildAndRun) { Label("Run", systemImage: "play.fill") }.buttonStyle(.borderedProminent).tint(.lime)
        }
        .padding(.horizontal, 10).frame(height: 46)
        .modifier(GlassChrome(enabled: model.glassEnabled, style: model.glassStyle))
    }
}

private struct CommandPalette: View {
    @Bindable var model: WorkspaceModel
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { model.commandPaletteVisible = false }
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "command")
                    TextField("Type a command", text: $model.commandPaletteQuery)
                        .textFieldStyle(.plain).focused($isFocused)
                    Button { model.commandPaletteVisible = false } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }
                .padding(12)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.filteredCommands) { command in
                            Button { model.execute(command) } label: {
                                HStack { Text(command.rawValue); Spacer(); Image(systemName: "return").foregroundStyle(.secondary) }
                                    .padding(.horizontal, 12).padding(.vertical, 9).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }.frame(maxHeight: 310)
            }
            .frame(width: 470).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 14)).shadow(radius: 24)
        }
        .onAppear { isFocused = true }
        .onExitCommand { model.commandPaletteVisible = false }
    }
}

private struct TabStrip: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(model.tabs) { tab in
                    HStack(spacing: 5) {
                        Text(tab.title).lineLimit(1)
                        if tab.isDirty { Circle().frame(width: 4, height: 4) }
                        Button { model.closeTab(tab) } label: { Image(systemName: "xmark").font(.caption2) }.buttonStyle(.plain)
                    }
                    .font(.caption.weight(.medium)).padding(.horizontal, 9).frame(height: 26)
                    .background(model.activeTabID == tab.id ? Color.white.opacity(0.16) : .clear)
                    .clipShape(Capsule()).contentShape(Capsule()).onTapGesture { model.activateTab(tab) }
                }
            }
        }
        .frame(maxWidth: 420)
    }
}

private struct Explorer: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("EXPLORER").font(.caption2.weight(.bold)); Spacer(); Button(action: model.createFileInWorkspace) { Image(systemName: "doc.badge.plus") }.buttonStyle(.plain); Button(action: model.createFolderInWorkspace) { Image(systemName: "folder.badge.plus") }.buttonStyle(.plain); Button(action: model.reloadFiles) { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain) }
                .padding(10).background(.thinMaterial)
            List(selection: $model.selectedFile) {
                if model.files.isEmpty { Text("Open a folder to begin").foregroundStyle(.secondary) }
                ForEach(model.files) { file in Label(file.name, systemImage: file.id.pathExtension == "hpp" ? "curlybraces.square" : "doc.text").padding(.leading, CGFloat(file.depth * 12)).tag(file).contextMenu { Button("Rename…") { model.rename(file) }; Button("Duplicate") { model.duplicate(file) }; Divider(); Button("Move to Trash", role: .destructive) { model.selectedFile = file; model.moveSelectedFileToTrash() } } }
            }
            .scrollContentBackground(.hidden)
            Spacer()
            Button("Open Folder…", action: model.openFolder).buttonStyle(.borderless).padding(8)
        }
        .onChange(of: model.selectedFile) { _, file in if let file { model.select(file) } }
        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct EditorDeck: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        Group {
            if model.showSplitEditor {
                HStack(spacing: 1) { CodeEditor(model: model); CodeEditor(model: model) }
            } else { CodeEditor(model: model) }
        }
        .overlay(alignment: .topTrailing) { Text(model.activeTabID == nil ? "untitled.cpp" : "C++20").font(.caption2).foregroundStyle(.secondary).padding(10) }
        .overlay(alignment: .top) {
            if let message = model.externalChangeNotice {
                HStack(spacing: 8) {
                    Text(message).font(.caption)
                    Button("Reload", action: model.reloadActiveFileFromDisk).buttonStyle(.bordered)
                    Button("Keep editor", action: model.keepEditorVersion).buttonStyle(.bordered)
                }
                .padding(6).background(.yellow.opacity(0.92)).foregroundStyle(.black).clipShape(Capsule()).padding(8)
            }
        }
        .background(Color(nsColor: .textBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1)) }
    }
}

private struct CodeEditor: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        NativeCodeEditor(
            source: $model.source,
            cursorPosition: $model.cursorPosition,
            fontSize: model.editorFontSize,
            tabSize: model.editorTabSize,
            wordWrap: model.editorWordWrap,
            backgroundColor: model.theme.palette.editorBackground,
            foregroundColor: model.theme.palette.editorForeground,
            accentColor: model.theme.palette.accent,
            onSourceChange: model.sourceDidChange,
            onCursorChange: model.updateCursor,
            requestCompletions: model.requestCompletions
        )
    }
}

private struct TestRail: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        VStack(spacing: 8) {
            MiniPanel(title: "INPUT", text: $model.testInput)
            MiniPanel(title: "EXPECTED", text: $model.expectedOutput)
        }
        .padding(6).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MiniPanel: View {
    let title: String; @Binding var text: String
    var body: some View { VStack(spacing: 0) { HStack { Text(title).font(.caption2.weight(.bold)); Spacer(); Image(systemName: "circle.fill").font(.system(size: 7)).foregroundStyle(.lime) }.padding(8); Divider(); TextEditor(text: $text).font(.system(.caption, design: .monospaced)).scrollContentBackground(.hidden).padding(6) }.background(Color.black.opacity(0.36)).clipShape(RoundedRectangle(cornerRadius: 11)) }
}

private struct BottomDeck: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(WorkspaceModel.BottomPanel.allCases) { panel in Button(panel.rawValue.uppercased()) { model.bottomPanel = panel }.font(.caption2.weight(.bold)).buttonStyle(.bordered).tint(model.bottomPanel == panel ? .lime : .gray) }
                Spacer(); Button("Run All", action: model.runAllTests).buttonStyle(.borderedProminent).tint(.lime)
            }.padding(8).background(.thinMaterial)
            Group { switch model.bottomPanel { case .tests: TestResults(model: model); case .terminal: TerminalOutput(model: model); case .problems: ProblemsView(model: model); case .debug: DebugView(model: model) } }
        }.background(Color.black.opacity(0.32)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct TestResults: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        List {
            let passed = model.testCases.filter { $0.passed == true }.count
            Label("\(passed)/\(model.testCases.count) passed", systemImage: passed == model.testCases.count ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(passed == model.testCases.count ? .green : .secondary)
            ForEach(model.testCases) { test in
                HStack {
                    Image(systemName: test.passed == nil ? "circle" : (test.passed == true ? "checkmark.seal.fill" : "xmark.seal.fill"))
                        .foregroundStyle(test.passed == false ? .red : .lime)
                    Text(test.name)
                    Spacer()
                    if let passed = test.passed { Text(passed ? "Passed" : "Failed").foregroundStyle(passed ? .green : .red) }
                }
            }
        }.listStyle(.plain).scrollContentBackground(.hidden)
    }
}
private struct TerminalOutput: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(model.output).frame(maxWidth: .infinity, alignment: .leading).font(.system(.callout, design: .monospaced)).textSelection(.enabled).padding(12)
            }
            Divider()
            HStack(spacing: 8) {
                TextField("Program input", text: $model.terminalInput)
                    .textFieldStyle(.plain)
                    .font(.system(.callout, design: .monospaced))
                    .onSubmit(model.sendTerminalInput)
                    .disabled(!model.isRunning)
                Button("Send", action: model.sendTerminalInput).disabled(!model.isRunning || model.terminalInput.isEmpty)
            }
            .padding(8).background(.thinMaterial)
        }
    }
}
private struct DebugView: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("BREAKPOINTS").font(.caption2.weight(.bold))
                    Spacer()
                    Button("Start", action: model.startDebugging).disabled(model.isDebugging)
                }
                HStack(spacing: 4) {
                    Button(action: model.continueDebugging) { Image(systemName: "play.fill") }.help("Continue")
                    Button(action: model.stepOverDebugging) { Image(systemName: "arrow.turn.down.right") }.help("Step Over")
                    Button(action: model.stepIntoDebugging) { Image(systemName: "arrow.down.right") }.help("Step Into")
                    Button(action: model.refreshDebugVariables) { Image(systemName: "list.bullet.rectangle") }.help("Refresh stack and variables")
                    Button(action: model.endDebugging) { Image(systemName: "stop.fill") }.help("Stop Debugging")
                }
                .buttonStyle(.bordered)
                .disabled(!model.isDebugging)
                HStack {
                    Stepper("Line \(model.breakpointLine)", value: $model.breakpointLine, in: 1...100_000)
                    Button(action: model.addBreakpoint) { Image(systemName: "plus") }.buttonStyle(.bordered)
                }
                List {
                    ForEach(model.breakpoints) { breakpoint in
                        HStack {
                            Toggle("Line \(breakpoint.line)", isOn: Binding(get: { breakpoint.enabled }, set: { value in if let index = model.breakpoints.firstIndex(where: { $0.id == breakpoint.id }) { model.breakpoints[index].enabled = value } }))
                            Spacer()
                            Button(role: .destructive) { model.removeBreakpoint(breakpoint) } label: { Image(systemName: "trash") }.buttonStyle(.plain)
                        }
                    }
                }.listStyle(.plain)
                Text("LLDB stops at enabled breakpoints, then prints stack frames and visible variables.").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(10).frame(width: 270)
            Divider()
            ScrollView { Text(model.debugOutput).frame(maxWidth: .infinity, alignment: .leading).font(.system(.callout, design: .monospaced)).textSelection(.enabled).padding(12) }
        }
    }
}
private struct ProblemsView: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        List {
            Button("Check syntax", action: model.checkSyntax).buttonStyle(.borderless)
            if let symbolInfo = model.symbolInfo {
                Section("Symbol information") { Text(symbolInfo).font(.system(.callout, design: .monospaced)).textSelection(.enabled) }
            }
            ForEach(model.diagnostics, id: \.self) { message in Label(message, systemImage: message.contains("error:") ? "xmark.circle.fill" : "checkmark.circle").foregroundStyle(message.contains("error:") ? .red : .secondary).textSelection(.enabled) }
        }.listStyle(.plain).scrollContentBackground(.hidden)
    }
}

private struct StatusBar: View { @Bindable var model: WorkspaceModel; var body: some View { HStack { Label("Sameko Mac", systemImage: "fish"); Spacer(); Text(model.companionStatus).foregroundStyle(.secondary); Divider().frame(height: 12); Text(model.isRunning ? "Building…" : "Ready"); Divider().frame(height: 12); Text(model.cursorPosition); Divider().frame(height: 12); Text(model.cppStandard.uppercased()) }.font(.caption2).padding(.horizontal, 10).frame(height: 24).background(.thinMaterial) } }
private struct HeaderIcon: View { let symbol: String; let action: () -> Void; init(_ symbol: String, action: @escaping () -> Void) { self.symbol = symbol; self.action = action }; var body: some View { Button(action: action) { Image(systemName: symbol) }.buttonStyle(.bordered) } }
private struct WorkspaceBackdrop: View {
    let theme: WorkspaceModel.AppTheme
    var body: some View { LinearGradient(colors: [Color(nsColor: theme.palette.backdropStart), Color(nsColor: theme.palette.backdropEnd)], startPoint: .topLeading, endPoint: .bottomTrailing).overlay(alignment: .topTrailing) { Circle().fill(Color(nsColor: theme.palette.accent).opacity(0.12)).frame(width: 600).blur(radius: 100) } }
}

private struct SettingsSheet: View {
    @Bindable var model: WorkspaceModel; let section: WorkspaceModel.SettingsSection
    var body: some View {
        NavigationSplitView {
            List(WorkspaceModel.SettingsSection.allCases, selection: $model.settingsSection) { Text($0.rawValue).tag(Optional($0)) }.navigationTitle("Settings")
        } detail: {
            Form {
                switch section {
                case .compiler:
                    Section("Compiler") { Picker("C++ standard", selection: $model.cppStandard) { ForEach(["c++17", "c++20", "c++23", "c++26"], id: \.self) { Text($0).tag($0) } }; Picker("Optimisation", selection: $model.optimization) { ForEach(["-O0", "-O2", "-O3"], id: \.self) { Text($0).tag($0) } }; Toggle("Warnings", isOn: $model.warningsEnabled); Toggle("Single-file compile", isOn: $model.singleFileCompile); if !model.singleFileCompile { Text("Builds all .cpp, .cc and .cxx files in the workspace.").font(.caption).foregroundStyle(.secondary) }; TextField("Additional flags", text: $model.extraFlags) }
                case .snippets:
                    Section("Snippet editor") {
                        TextField("Name", text: $model.snippetName)
                        TextEditor(text: $model.snippetBody).font(.system(.body, design: .monospaced)).frame(minHeight: 110)
                        Button(model.snippetName.isEmpty ? "Add snippet" : "Save snippet", action: model.saveSnippet)
                    }
                    Section("Saved snippets") {
                        ForEach(model.snippets) { snippet in
                            HStack {
                                Button(snippet.name) { model.insertSnippet(snippet) }.buttonStyle(.borderless)
                                Spacer()
                                Button(action: { model.editSnippet(snippet) }) { Image(systemName: "pencil") }.buttonStyle(.borderless)
                                Button(role: .destructive, action: { model.deleteSnippet(snippet) }) { Image(systemName: "trash") }.buttonStyle(.borderless)
                            }
                        }
                    }
                case .appearance:
                    Section("Appearance") { Picker("Color theme", selection: $model.theme) { ForEach(WorkspaceModel.AppTheme.allCases) { Text($0.rawValue).tag($0) } }; Toggle("Liquid Glass", isOn: $model.glassEnabled); Picker("Glass style", selection: $model.glassStyle) { ForEach(WorkspaceModel.GlassStyle.allCases) { Text($0.rawValue).tag($0) } } }
                case .editor:
                    Section("Editor") {
                        Slider(value: $model.editorFontSize, in: 11...24, step: 1) { Text("Font size") } minimumValueLabel: { Text("11") } maximumValueLabel: { Text("24") }
                        Picker("Indentation", selection: $model.editorTabSize) { Text("2 spaces").tag(2); Text("4 spaces").tag(4); Text("8 spaces").tag(8) }
                        Toggle("Word wrap", isOn: $model.editorWordWrap)
                        Toggle("Auto-save", isOn: $model.autoSaveEnabled)
                        if model.autoSaveEnabled {
                            Picker("Auto-save delay", selection: $model.autoSaveDelay) {
                                Text("1 second").tag(1.0); Text("2 seconds").tag(2.0); Text("5 seconds").tag(5.0)
                            }
                        }
                        Toggle("Split editor", isOn: $model.showSplitEditor)
                        Toggle("Show test rail", isOn: $model.showTests)
                        HStack { Text("Checkpoints: \(model.checkpoints.count)"); Spacer(); Button("Clear", role: .destructive, action: model.clearCheckpoints).disabled(model.checkpoints.isEmpty) }
                        ForEach(model.checkpoints) { checkpoint in
                            Button("Restore \(checkpoint.createdAt.formatted(date: .abbreviated, time: .shortened))") { model.restoreCheckpoint(checkpoint.source) }
                        }
                    }
                case .execution:
                    Section("Execution") { Text(model.toolchainStatus).textSelection(.enabled); Button("Refresh toolchain", action: model.refreshToolchainStatus); Toggle("Show tests", isOn: $model.showTests) }
                case .about:
                    Section("Sameko Mac") { Text("Native SwiftUI migration"); Text("Liquid Glass uses the system material on macOS 26+") }
                }
            }.formStyle(.grouped).padding()
        }.frame(minWidth: 680, minHeight: 460)
    }
}

private struct GlassChrome: ViewModifier { let enabled: Bool; let style: WorkspaceModel.GlassStyle; @ViewBuilder func body(content: Content) -> some View { if enabled { if #available(macOS 26.0, *) { content.glassEffect(style == .clear ? .clear : .regular, in: .rect(cornerRadius: 0)) } else { content.background(.bar) } } else { content.background(.bar) } } }
