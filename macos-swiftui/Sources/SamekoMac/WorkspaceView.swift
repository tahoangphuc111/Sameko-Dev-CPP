import Foundation
import SwiftUI

struct WorkspaceView: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        ZStack {
            WorkspaceBackdrop(theme: model.theme).allowsHitTesting(false)
            if model.showWelcome {
                WelcomeView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                VStack(spacing: 0) {
                    AppHeader(model: model)
                    HStack(spacing: 8) {
                        if model.showExplorer {
                            Explorer(model: model).frame(width: 218)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                        VStack(spacing: 8) {
                            EditorDeck(model: model).layoutPriority(1)
                            BottomDeck(model: model).frame(minHeight: 180, idealHeight: 220, maxHeight: 290)
                        }
                        if model.showTests {
                            TestRail(model: model).frame(width: 238)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    StatusBar(model: model)
                }
            }
        }
        .overlay {
            if model.commandPaletteVisible { CommandPalette(model: model) }
        }
        .sheet(isPresented: Binding(
            get: { model.settingsSection != nil },
            set: { if !$0 { model.settingsSection = nil } }
        )) { SettingsSheet(model: model) }
        .animation(.easeInOut(duration: 0.22), value: model.showExplorer)
        .animation(.easeInOut(duration: 0.22), value: model.showTests)
        .animation(.easeInOut(duration: 0.18), value: model.showSplitEditor)
        .animation(.easeInOut(duration: 0.28), value: model.showWelcome)
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

private struct WelcomeView: View {
    @Bindable var model: WorkspaceModel
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 9) {
                    Image(systemName: "fish.fill").font(.title2).foregroundStyle(Color(nsColor: model.theme.palette.accent))
                    Text("Sameko IDE").font(.system(size: 30, weight: .bold, design: .rounded))
                }
                Text("A focused C++ workspace for building, testing, and debugging.")
                    .font(.title3).foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                WelcomeCard(
                    index: 0,
                    icon: "doc.badge.plus",
                    title: "New C++ file",
                    subtitle: "Start from a compact C++ template.",
                    accent: Color(nsColor: model.theme.palette.accent),
                    action: model.newFile
                )
                WelcomeCard(
                    index: 1,
                    icon: "folder.badge.gearshape",
                    title: "Open workspace",
                    subtitle: "Browse a project folder and its C++ sources.",
                    accent: Color(nsColor: model.theme.palette.accent),
                    action: model.openFolder
                )
                WelcomeCard(
                    index: 2,
                    icon: "arrow.counterclockwise",
                    title: "Resume session",
                    subtitle: model.workspaceURL.map { "Return to \($0.lastPathComponent)." } ?? "No previous workspace to restore.",
                    accent: Color(nsColor: model.theme.palette.accent),
                    enabled: model.canResumeSession,
                    action: model.resumeLastSession
                )
            }
        }
        .padding(34)
        .frame(maxWidth: 940, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.92), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.14)) }
        .shadow(color: .black.opacity(0.24), radius: 28, y: 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear { withAnimation(.easeOut(duration: 0.42)) { appeared = true } }
        .padding(28)
    }
}

private struct WelcomeCard: View {
    let index: Int
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    var enabled = true
    let action: () -> Void
    @State private var hovered = false
    @State private var visible = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 42, height: 42)
                    .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 11))
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Label(enabled ? "Continue" : "Unavailable", systemImage: enabled ? "arrow.right" : "minus")
                    .font(.caption.weight(.semibold)).foregroundStyle(enabled ? accent : .secondary)
            }
            .padding(18).frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
            .background(.black.opacity(hovered ? 0.19 : 0.11), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(hovered ? accent.opacity(0.65) : .white.opacity(0.12)) }
        }
        .buttonStyle(PressableChrome())
        .disabled(!enabled)
        .scaleEffect(visible ? (hovered ? 1.025 : 1) : 0.92)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? (hovered ? -5 : 0) : 24)
        .shadow(color: hovered ? accent.opacity(0.24) : .clear, radius: 16, y: 8)
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.74).delay(Double(index) * 0.10)) {
                visible = true
            }
        }
        .onHover { isHovering in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.74)) { hovered = isHovering }
        }
    }
}

private struct AppHeader: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        HStack(spacing: 8) {
            Text("C++").font(.caption.weight(.heavy)).foregroundStyle(.black)
                .frame(width: 38, height: 26).background(Color.green).clipShape(Capsule())
            Menu("File") { Button("New File", action: model.newFile); Button("New File in Workspace", action: model.createFileInWorkspace); Button("New Folder", action: model.createFolderInWorkspace); Divider(); Button("Save") { try? model.save() }; Button("Save As…", action: model.saveAs); Button("Open Folder…", action: model.openFolder); Divider(); Button("Show Welcome") { model.showWelcome = true } }
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
            Button(action: model.buildAndRun) { Label("Run", systemImage: "play.fill") }.buttonStyle(.borderedProminent).tint(Color.green)
        }
        .padding(.horizontal, 10).frame(height: 46)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.94))
        .overlay(alignment: .bottom) { Divider().opacity(0.55) }
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
                    .background(model.activeTabID == tab.id ? Color.accentColor.opacity(0.24) : .clear)
                    .clipShape(Capsule()).contentShape(Capsule()).onTapGesture { model.activateTab(tab) }
                    .animation(.easeInOut(duration: 0.16), value: model.activeTabID)
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
            HStack { Text("EXPLORER").font(.caption2.weight(.bold)); Spacer(); Button(action: model.createFileInWorkspace) { Image(systemName: "doc.badge.plus") }.buttonStyle(.plain); Button(action: model.createFolderInWorkspace) { Image(systemName: "folder.badge.plus") }.buttonStyle(.plain); Button(action: { model.reloadFiles() }) { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain) }
                .padding(10).background(.thinMaterial)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if model.files.isEmpty {
                        Text("Open a folder to begin").foregroundStyle(.secondary).padding(12)
                    }
                    ForEach(model.files) { file in
                        Button { model.select(file) } label: {
                            Label(file.name, systemImage: file.id.pathExtension == "hpp" ? "curlybraces.square" : "doc.text")
                                .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, CGFloat(file.depth * 12) + 8).padding(.trailing, 8).padding(.vertical, 6)
                                .background(model.selectedFile?.id == file.id ? Color.accentColor.opacity(0.25) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .contextMenu { Button("Rename…") { model.rename(file) }; Button("Duplicate") { model.duplicate(file) }; Divider(); Button("Move to Trash", role: .destructive) { model.selectedFile = file; model.moveSelectedFileToTrash() } }
                    }
                }.padding(6)
            }
            .frame(maxHeight: .infinity)
            Button("Open Folder…", action: model.openFolder).buttonStyle(.borderless).padding(8)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.88)).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.10)) }
    }
}

private struct EditorDeck: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        Group {
            if model.showSplitEditor, let activeID = model.activeTabID {
                HStack(spacing: 1) {
                    CodeEditor(model: model, tabID: activeID)
                    VStack(spacing: 0) {
                        Picker("Split tab", selection: Binding(
                            get: { model.splitTabID ?? model.tabs.first(where: { $0.id != activeID })?.id ?? activeID },
                            set: { model.splitTabID = $0 }
                        )) {
                            ForEach(model.tabs) { Text($0.title).tag($0.id) }
                        }
                        .labelsHidden().pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading).padding(6)
                        Divider()
                        CodeEditor(model: model, tabID: model.splitTabID ?? model.tabs.first(where: { $0.id != activeID })?.id ?? activeID)
                    }
                }
            } else if let activeID = model.activeTabID { CodeEditor(model: model, tabID: activeID) }
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
        .frame(minHeight: 280, maxHeight: .infinity)
        .background(Color(nsColor: model.theme.palette.editorBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.14)) }
        .animation(.easeInOut(duration: 0.18), value: model.showSplitEditor)
    }
}

private struct CodeEditor: View {
    @Bindable var model: WorkspaceModel
    let tabID: WorkspaceModel.EditorTab.ID
    var body: some View {
        NativeCodeEditor(
            source: Binding(get: { model.source(for: tabID) }, set: { model.setSource($0, for: tabID) }),
            cursorPosition: $model.cursorPosition,
            fontSize: model.editorFontSize,
            tabSize: model.editorTabSize,
            wordWrap: model.editorWordWrap,
            backgroundColor: model.theme.palette.editorBackground,
            foregroundColor: model.theme.palette.editorForeground,
            accentColor: model.theme.palette.accent,
            onSourceChange: { model.sourceDidChange(for: tabID) },
            onCursorChange: model.updateCursor,
            requestCompletions: { line, column, reply in
                model.requestCompletions(for: tabID, line: line, column: column, reply: reply)
            }
        )
        .id("\(model.theme.rawValue)-\(model.editorFontSize)-\(model.editorTabSize)-\(model.editorWordWrap)")
    }
}

private struct TestRail: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        VStack(spacing: 7) {
            MiniPanel(title: "INPUT", subtitle: "stdin", text: $model.testInput, accent: .blue)
            MiniPanel(title: "OUTPUT", subtitle: "program result", text: $model.actualOutput, accent: .orange, isEditable: false)
            MiniPanel(title: "EXPECTED", subtitle: "judge answer", text: $model.expectedOutput, accent: .green)
            HStack(spacing: 6) {
                TextField("Test case name", text: $model.testCaseName).textFieldStyle(.roundedBorder)
                Button("Save", action: model.saveTestCase).buttonStyle(.borderedProminent).tint(Color.green)
            }
        }
        .padding(7).background(Color(nsColor: .windowBackgroundColor).opacity(0.90)).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.10)) }
    }
}

private struct MiniPanel: View {
    let title: String
    let subtitle: String
    @Binding var text: String
    let accent: Color
    var isEditable = true
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 7, height: 7)
                Text(title).font(.caption2.weight(.bold))
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if isEditable { Image(systemName: "pencil.line").font(.caption2).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 9).padding(.vertical, 8)
            Divider()
            if isEditable {
                TextEditor(text: $text)
                    .font(.system(.caption, design: .monospaced))
                    .textEditorStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.primary)
                    .focusable(true)
                    .padding(8)
            } else {
                ScrollView {
                    Text(text.isEmpty ? "Run a test to see program output." : text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(text.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .padding(9)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color.black.opacity(0.30))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

private struct BottomDeck: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(WorkspaceModel.BottomPanel.allCases) { panel in Button(panel.rawValue.uppercased()) { model.bottomPanel = panel }.font(.caption2.weight(.bold)).buttonStyle(.bordered).tint(model.bottomPanel == panel ? Color.green : Color.gray) }
                Spacer(); Button("Run All", action: model.runAllTests).buttonStyle(.borderedProminent).tint(Color.green)
            }.padding(8).background(.thinMaterial)
            Group {
                switch model.bottomPanel {
                case .tests: TestResults(model: model)
                case .terminal: TerminalOutput(model: model)
                case .problems: ProblemsView(model: model)
                case .debug: DebugView(model: model)
                }
            }
            .id(model.bottomPanel)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        .background(Color.black.opacity(0.32)).clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.18), value: model.bottomPanel)
    }
}

private struct TestResults: View {
    @Bindable var model: WorkspaceModel
    var body: some View {
        List {
            let passed = model.testCases.filter { $0.passed == true }.count
            Label("\(passed)/\(model.testCases.count) passed", systemImage: passed == model.testCases.count ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(passed == model.testCases.count ? .green : .secondary)
            ForEach(model.testCases) { test in TestResultRow(test: test, onDelete: { model.deleteTestCase(test) }) }
        }.listStyle(.plain).scrollContentBackground(.hidden)
    }
}
private struct TestResultRow: View {
    let test: WorkspaceModel.TestCase
    let onDelete: () -> Void
    private var icon: String { test.passed == nil ? "circle" : (test.passed == true ? "checkmark.seal.fill" : "xmark.seal.fill") }
    private var tint: Color { test.passed == false ? .red : .green }
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(tint)
            Text(test.name)
            Spacer()
            if let passed = test.passed { Text(passed ? "Passed" : "Failed").foregroundStyle(passed ? Color.green : Color.red) }
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }.buttonStyle(.plain)
        }
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
private struct HeaderIcon: View {
    let symbol: String
    let action: () -> Void
    init(_ symbol: String, action: @escaping () -> Void) { self.symbol = symbol; self.action = action }
    var body: some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 14, height: 14) }
            .buttonStyle(PressableChrome())
            .padding(6)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
            .overlay { RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.10)) }
    }
}
private struct WorkspaceBackdrop: View {
    let theme: WorkspaceModel.AppTheme
    private var videoName: String {
        switch theme {
        case .dracula: "dracula"
        case .monokai: "monokai"
        case .nord: "nord"
        case .kawaiiDark, .kawaiiLight, .sakura: "pink"
        case .ocean, .graphite: "darkblue"
        }
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            let accent = Color(nsColor: theme.palette.accent)
            ZStack {
                LinearGradient(colors: [Color(nsColor: theme.palette.backdropStart), Color(nsColor: theme.palette.backdropEnd)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VideoWallpaper(resourceName: videoName).opacity(0.5)
                Circle().fill(accent.opacity(0.15)).frame(width: 620).blur(radius: 100)
                    .offset(x: CGFloat(sin(phase * 0.22)) * 150, y: CGFloat(cos(phase * 0.17)) * 110)
                Circle().fill(.white.opacity(0.05)).frame(width: 440).blur(radius: 90)
                    .offset(x: CGFloat(cos(phase * 0.14)) * 230, y: CGFloat(sin(phase * 0.19)) * 160)
            }.ignoresSafeArea()
        }
    }
}

private struct SettingsSheet: View {
    @Bindable var model: WorkspaceModel
    private var selectedSection: WorkspaceModel.SettingsSection { model.settingsSection ?? .editor }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Settings").font(.title3.weight(.semibold)).padding(.horizontal, 14).padding(.bottom, 8)
                ForEach(WorkspaceModel.SettingsSection.allCases) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) { model.settingsSection = section }
                    } label: {
                        Label(section.rawValue, systemImage: icon(for: section))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(model.settingsSection == section ? Color.accentColor.opacity(0.22) : .clear, in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
                Spacer()
            }
            .padding(10).frame(width: 190)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.7))
            Divider()
            Form {
                switch selectedSection {
                case .compiler:
                    Section("Compiler") { Picker("C++ standard", selection: $model.cppStandard) { ForEach(["c++17", "c++20", "c++23", "c++26"], id: \.self) { Text($0).tag($0) } }; Picker("Optimisation", selection: $model.optimization) { ForEach(["-O0", "-O2", "-O3"], id: \.self) { Text($0).tag($0) } }; Toggle("Warnings", isOn: $model.warningsEnabled); Toggle("Single-file compile", isOn: $model.singleFileCompile); if !model.singleFileCompile { Text("Builds all .cpp, .cc and .cxx files in the workspace.").font(.caption).foregroundStyle(.secondary) }; TextField("Additional flags", text: $model.extraFlags) }
                case .snippets:
                    Section("Snippet editor") {
                        TextField("Name", text: $model.snippetName)
                        TextEditor(text: $model.snippetBody).font(.system(.body, design: .monospaced)).frame(minHeight: 110)
                        HStack {
                            Button("Save snippet", action: model.saveSnippet).buttonStyle(.borderedProminent)
                            Button("New") { model.snippetName = ""; model.snippetBody = "" }.buttonStyle(.bordered)
                        }
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
                    Section("Appearance") {
                        Picker("Color theme", selection: $model.theme) {
                            ForEach(WorkspaceModel.AppTheme.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Text("Sameko uses solid native surfaces for a stable, readable workspace.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
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
                    Section("Sameko Mac") { Text("Native SwiftUI migration"); Text("Built for macOS 26+") }
                }
            }
            .formStyle(.grouped)
            .padding()
            .id(selectedSection)
            .transition(.opacity)
        }
        .frame(minWidth: 680, minHeight: 460)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { model.settingsSection = nil }.keyboardShortcut(.defaultAction) } }
    }

    private func icon(for section: WorkspaceModel.SettingsSection) -> String {
        switch section {
        case .editor: "text.cursor"
        case .compiler: "hammer"
        case .execution: "play.circle"
        case .appearance: "paintpalette"
        case .snippets: "curlybraces.square"
        case .about: "info.circle"
        }
    }
}

private struct PressableChrome: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.76 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
