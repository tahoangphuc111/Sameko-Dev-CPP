import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
final class WorkspaceModel {
    struct EditorTab: Identifiable, Hashable {
        let id = UUID()
        var title: String
        var url: URL?
        var source = ""
        var isDirty = false
    }

    struct TestCase: Identifiable, Hashable {
        let id = UUID()
        var name: String
        var input: String
        var expected: String
        var actual = ""
        var passed: Bool?
    }

    struct Snippet: Identifiable, Hashable, Codable {
        let id = UUID()
        var name: String
        var body: String
    }
    struct Breakpoint: Identifiable, Hashable, Sendable {
        let id = UUID()
        var line: Int
        var enabled = true
    }
    struct SourceFile: Identifiable, Hashable {
        let id: URL
        var depth = 0
        var name: String { id.lastPathComponent }
    }

    var workspaceURL: URL?
    var files: [SourceFile] = []
    var selectedFile: SourceFile?
    var source = """
    #include <iostream>

    int main() {
        std::cout << "Hello from Sameko\\n";
        return 0;
    }
    """
    var output = "Ready. Open a C++ folder or create a new file."
    var isRunning = false
    var terminalInput = ""
    var glassEnabled = true
    var glassStyle: GlassStyle = .regular
    var tabs: [EditorTab] = [EditorTab(title: "untitled.cpp", source: "")]
    var activeTabID: EditorTab.ID?
    var showExplorer = true
    var showSplitEditor = false
    var showTests = true
    var bottomPanel: BottomPanel = .tests
    var testInput = "3\n1 1 8\n1 2 8\n1 3 8"
    var expectedOutput = "1\n1\n1"
    var actualOutput = ""
    var testCases: [TestCase] = [
        TestCase(name: "Test Case 1", input: "3\n1 1 8\n1 2 8\n1 3 8", expected: "1\n1\n1"),
        TestCase(name: "Test Case 2", input: "1\n5", expected: "")
    ]
    var snippets = [
        Snippet(name: "Fast I/O", body: "ios::sync_with_stdio(false);\ncin.tie(nullptr);"),
        Snippet(name: "DFS", body: "void dfs(int u) {\n    for (int v : graph[u]) dfs(v);\n}"),
        Snippet(name: "Segment Tree", body: "struct SegmentTree {\n    // TODO\n};")
    ]
    var snippetName = ""
    var snippetBody = ""
    var cppStandard = "c++20"
    var optimization = "-O0"
    var warningsEnabled = true
    var extraFlags = ""
    var singleFileCompile = true
    var editorFontSize: Double = 14
    var editorTabSize = 4
    var editorWordWrap = false
    var cursorPosition = "Ln 1, Col 1"
    var cursorLine = 0
    var cursorColumn = 0
    var autoSaveEnabled = true
    var autoSaveDelay = 2.0
    var checkpoints: [CheckpointRecord] = []
    var companionStatus = "Companion offline"
    var toolchainStatus = ToolchainService.statusDescription
    var diagnostics: [String] = []
    var symbolInfo: String?
    var externalChangeNotice: String?
    var debugOutput = "Debugger is ready."
    var isDebugging = false
    var breakpoints: [Breakpoint] = []
    var breakpointLine = 1
    var settingsSection: SettingsSection?
    var theme: AppTheme = .ocean
    var commandPaletteVisible = false
    var commandPaletteQuery = ""

    private var activeTask: Process?
    private var activeInput: FileHandle?
    private var debugTask: Process?
    private var debugInput: FileHandle?
    private var autoSaveTask: Task<Void, Never>?
    private let clangd = ClangdService()
    private let workspaceWatcher = WorkspaceWatcher()

    enum GlassStyle: String, CaseIterable, Identifiable {
        case regular = "Regular"
        case clear = "Clear"
        var id: String { rawValue }
    }

    enum BottomPanel: String, CaseIterable, Identifiable {
        case problems = "Problems"
        case terminal = "Terminal"
        case tests = "Tests"
        case debug = "Debug"
        var id: String { rawValue }
    }

    enum SettingsSection: String, CaseIterable, Identifiable {
        case editor = "Editor", compiler = "Compiler", execution = "Execution"
        case appearance = "Appearance", snippets = "Snippets", about = "About"
        var id: String { rawValue }
    }

    struct ThemePalette {
        let backdropStart: NSColor
        let backdropEnd: NSColor
        let editorBackground: NSColor
        let editorForeground: NSColor
        let accent: NSColor
    }

    enum AppTheme: String, CaseIterable, Identifiable {
        case ocean = "Ocean"
        case graphite = "Graphite"
        case kawaiiDark = "Kawaii Dark"
        case kawaiiLight = "Kawaii Light"
        case dracula = "Dracula"
        case monokai = "Monokai"
        case nord = "Nord"
        case sakura = "Sakura"
        var id: String { rawValue }

        var palette: ThemePalette {
            switch self {
            case .ocean: ThemePalette(hex: "071514", "142118", "101d1c", "d9f4ea", "b7f34b")
            case .graphite: ThemePalette(hex: "111111", "252525", "1b1b1b", "eeeeee", "b7f34b")
            case .kawaiiDark: ThemePalette(hex: "201524", "3a1e3e", "251a2a", "ffe5f3", "ff8fbd")
            case .kawaiiLight: ThemePalette(hex: "fff0f6", "e7f6ff", "fffafd", "412a3a", "e95b96")
            case .dracula: ThemePalette(hex: "282a36", "44475a", "282a36", "f8f8f2", "bd93f9")
            case .monokai: ThemePalette(hex: "1e1f1c", "36362e", "272822", "f8f8f2", "a6e22e")
            case .nord: ThemePalette(hex: "2e3440", "3b4252", "242933", "d8dee9", "88c0d0")
            case .sakura: ThemePalette(hex: "2a101d", "4a1f35", "211019", "ffe8f0", "ff8fb8")
            }
        }
    }

    enum PaletteCommand: String, CaseIterable, Identifiable {
        case newFile = "New C++ File"
        case openFolder = "Open Folder…"
        case save = "Save"
        case buildRun = "Build & Run"
        case debug = "Start Debugging"
        case format = "Format Source"
        case syntax = "Check Syntax"
        case inspect = "Inspect Symbol"
        case explorer = "Toggle Explorer"
        case split = "Toggle Split Editor"
        case tests = "Toggle Test Rail"
        case settings = "Open Settings"
        var id: String { rawValue }
    }

    var filteredCommands: [PaletteCommand] {
        let query = commandPaletteQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return PaletteCommand.allCases.filter { query.isEmpty || $0.rawValue.localizedCaseInsensitiveContains(query) }
    }

    init() {
        loadPreferences()
        let savedSnippets = SnippetStore.load()
        if !savedSnippets.isEmpty { snippets = savedSnippets }
        tabs[0].source = source
        activeTabID = tabs[0].id
        clangd.onDiagnostics = { [weak self] values in
            Task { @MainActor in self?.diagnostics = values.isEmpty ? ["No syntax problems found."] : values }
        }
        let server = CompetitiveCompanionServer()
        server.onProblem = { [weak self] problem in
            Task { @MainActor in self?.importCompanionProblem(problem) }
        }
        do { try server.start(); companionServer = server; companionStatus = "Companion listening on :10043" }
        catch { companionStatus = "Companion unavailable" }
        workspaceWatcher.onChange = { [weak self] in
            Task { @MainActor in self?.workspaceDidChangeOnDisk() }
        }
        restoreSession()
    }

    private var companionServer: CompetitiveCompanionServer?

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        workspaceURL = url
        reloadFiles()
        workspaceWatcher.watch(url)
        persistSession()
    }

    func reloadFiles(selectFirst: Bool = true) {
        guard let workspaceURL else { return }
        let enumerator = FileManager.default.enumerator(at: workspaceURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        let urls = (enumerator?.allObjects as? [URL] ?? [])
        files = urls
            .filter { ["cpp", "cc", "cxx", "h", "hpp"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            .map { SourceFile(id: $0, depth: max(0, $0.pathComponents.count - workspaceURL.pathComponents.count - 1)) }

        if selectFirst, selectedFile == nil, let first = files.first { select(first) }
    }

    func select(_ file: SourceFile) {
        let contents = (try? String(contentsOf: file.id, encoding: .utf8)) ?? ""
        checkpoints = CheckpointStore.load(for: file.name)
        output = "Opened \(file.name)"
        openTab(title: file.name, url: file.id, contents: contents)
    }

    func newFile() {
        let contents = """
        #include <iostream>

        int main() {
            return 0;
        }
        """
        output = "New unsaved file"
        openTab(title: "untitled-\(tabs.count + 1).cpp", url: nil, contents: contents)
    }

    func sourceDidChange() {
        if let index = tabs.firstIndex(where: { $0.id == activeTabID }) {
            tabs[index].source = source
            tabs[index].isDirty = true
        }
        clangd.update(source: source)
        scheduleAutoSave()
        persistSession()
    }

    func execute(_ command: PaletteCommand) {
        commandPaletteVisible = false
        commandPaletteQuery = ""
        switch command {
        case .newFile: newFile()
        case .openFolder: openFolder()
        case .save: try? save()
        case .buildRun: buildAndRun()
        case .debug: startDebugging()
        case .format: formatSource()
        case .syntax: checkSyntax()
        case .inspect: inspectSymbolAtCursor()
        case .explorer: showExplorer.toggle()
        case .split: showSplitEditor.toggle()
        case .tests: showTests.toggle()
        case .settings: settingsSection = .editor
        }
    }

    func requestCompletions(line: Int, column: Int, reply: @escaping @Sendable ([ClangdCompletion]) -> Void) {
        clangd.completions(line: line, column: column, source: source, reply: reply)
    }

    func updateCursor(line: Int, column: Int) {
        cursorLine = line
        cursorColumn = column
    }

    func inspectSymbolAtCursor() {
        symbolInfo = "Looking up symbol…"
        bottomPanel = .problems
        clangd.hover(line: cursorLine, column: cursorColumn) { [weak self] result in
            Task { @MainActor in self?.symbolInfo = result ?? "No symbol information at the cursor." }
        }
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "cpp")!]
        panel.nameFieldStringValue = selectedFile?.name ?? "main.cpp"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try source.write(to: url, atomically: true, encoding: .utf8)
            selectedFile = SourceFile(id: url)
            updateActiveTab(title: url.lastPathComponent, url: url, contents: source, dirty: false)
            if workspaceURL != nil { reloadFiles() }
            output = "Saved \(url.lastPathComponent)"
        } catch { output = "Could not save: \(error.localizedDescription)" }
    }

    func createFileInWorkspace() {
        guard let workspaceURL else { newFile(); return }
        var index = 1
        var url = workspaceURL.appendingPathComponent("main.cpp")
        while FileManager.default.fileExists(atPath: url.path) {
            index += 1
            url = workspaceURL.appendingPathComponent("main-\(index).cpp")
        }
        do {
            try "#include <iostream>\n\nint main() {\n    return 0;\n}\n".write(to: url, atomically: true, encoding: .utf8)
            reloadFiles()
            select(SourceFile(id: url))
        } catch { output = "Could not create file: \(error.localizedDescription)" }
    }

    func createFolderInWorkspace() {
        guard let workspaceURL else { output = "Open a workspace first."; return }
        var index = 1
        var url = workspaceURL.appendingPathComponent("New Folder")
        while FileManager.default.fileExists(atPath: url.path) { index += 1; url = workspaceURL.appendingPathComponent("New Folder \(index)") }
        do { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false); reloadFiles(); output = "Created \(url.lastPathComponent)" }
        catch { output = "Could not create folder: \(error.localizedDescription)" }
    }

    func moveSelectedFileToTrash() {
        guard let selectedFile else { return }
        do {
            _ = try FileManager.default.trashItem(at: selectedFile.id, resultingItemURL: nil)
            self.selectedFile = nil
            reloadFiles()
            output = "Moved \(selectedFile.name) to Trash."
        } catch { output = "Could not move file to Trash: \(error.localizedDescription)" }
    }

    func rename(_ file: SourceFile) {
        let alert = NSAlert()
        alert.messageText = "Rename \(file.name)"
        alert.informativeText = "Enter a new file name."
        let input = NSTextField(string: file.name)
        input.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        alert.accessoryView = input
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != file.name else { return }
        let destination = file.id.deletingLastPathComponent().appendingPathComponent(name)
        do {
            try FileManager.default.moveItem(at: file.id, to: destination)
            for index in tabs.indices where tabs[index].url == file.id {
                tabs[index].url = destination
                tabs[index].title = destination.lastPathComponent
            }
            reloadFiles(selectFirst: false)
            select(SourceFile(id: destination))
            output = "Renamed to \(name)"
        } catch { output = "Could not rename file: \(error.localizedDescription)" }
    }

    func duplicate(_ file: SourceFile) {
        let directory = file.id.deletingLastPathComponent()
        let stem = file.id.deletingPathExtension().lastPathComponent
        let ext = file.id.pathExtension
        var number = 2
        var destination = directory.appendingPathComponent("\(stem)-copy.\(ext)")
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = directory.appendingPathComponent("\(stem)-copy-\(number).\(ext)")
            number += 1
        }
        do {
            try FileManager.default.copyItem(at: file.id, to: destination)
            reloadFiles(selectFirst: false)
            select(SourceFile(id: destination))
            output = "Duplicated \(file.name)"
        } catch { output = "Could not duplicate file: \(error.localizedDescription)" }
    }

    func formatSource() {
        guard let formatter = ToolchainService.detected?.formatter else {
            output = "clang-format is unavailable in the detected toolchain. Install LLVM to use native formatting."
            return
        }
        Task.detached { [weak self] in
            let process = Process(); process.executableURL = formatter; process.arguments = ["-style=file"]
            let input = Pipe(); let response = Pipe(); process.standardInput = input; process.standardOutput = response; process.standardError = response
            do {
                try process.run()
                let source = await self?.source ?? ""
                input.fileHandleForWriting.write(source.data(using: .utf8) ?? Data()); input.fileHandleForWriting.closeFile()
                process.waitUntilExit()
                let formatted = String(data: response.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                guard process.terminationStatus == 0 else { await self?.finish("Formatting failed:\n\(formatted)"); return }
                await self?.applyFormattedSource(formatted)
            } catch { await self?.finish("Could not start clang-format: \(error.localizedDescription)") }
        }
    }

    func checkSyntax() {
        guard let selectedFile else { diagnostics = ["Save the file before checking syntax."]; return }
        do { try save() } catch { diagnostics = [error.localizedDescription]; return }
        diagnostics = ["Checking \(selectedFile.name)…"]
        ToolchainService.diagnose(file: selectedFile.id, standard: cppStandard) { [weak self] result in
            Task { @MainActor in
                self?.diagnostics = result.isEmpty ? ["No syntax problems found."] : result.split(separator: "\n").map(String.init)
            }
        }
    }

    func startDebugging() {
        guard !isDebugging, let selectedFile else { debugOutput = "Save the file before debugging."; return }
        guard let toolchain = ToolchainService.detected, let debuggerURL = toolchain.debugger else { debugOutput = "LLDB is unavailable. Install Xcode Command Line Tools or LLVM."; return }
        do { try save() } catch { debugOutput = error.localizedDescription; return }
        isDebugging = true; debugOutput = "Building debug target…"; bottomPanel = .debug
        let executable = FileManager.default.temporaryDirectory.appendingPathComponent("sameko-debug-\(UUID().uuidString)")
        Task.detached { [weak self] in
            let compiler = Process(); compiler.executableURL = toolchain.compiler
            let baseArguments = await self?.compilerArguments(for: selectedFile.id, executable: executable) ?? []
            compiler.arguments = Array(baseArguments.dropLast(2)) + ["-g", "-o", executable.path]
            let buildPipe = Pipe(); compiler.standardOutput = buildPipe; compiler.standardError = buildPipe
            do {
                try compiler.run(); compiler.waitUntilExit()
                let buildLog = String(data: buildPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                guard compiler.terminationStatus == 0 else { await self?.finishDebug("Build failed:\n\(buildLog)"); return }
                let debugger = Process(); debugger.executableURL = debuggerURL
                debugger.arguments = ["--no-lldbinit", executable.path]
                let debugInput = Pipe(), debugPipe = Pipe()
                debugger.standardInput = debugInput
                debugger.standardOutput = debugPipe
                debugger.standardError = debugPipe
                debugPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                    Task { @MainActor in self?.appendDebugOutput(text) }
                }
                let activeBreakpoints = await self?.breakpoints.filter(\.enabled) ?? []
                debugger.terminationHandler = { [weak self] _ in Task { @MainActor in self?.finishDebugSession() } }
                try debugger.run()
                await self?.setDebugSession(debugger, input: debugInput.fileHandleForWriting)
                await self?.sendDebugCommand("settings set auto-confirm true")
                for breakpoint in activeBreakpoints {
                    await self?.sendDebugCommand("breakpoint set --file \(selectedFile.name) --line \(breakpoint.line)")
                }
                await self?.sendDebugCommand("run")
            } catch { await self?.finishDebug("Could not start LLDB: \(error.localizedDescription)") }
        }
    }

    func save() throws {
        guard let selectedFile else {
            throw CocoaError(.fileNoSuchFile)
        }
        try source.write(to: selectedFile.id, atomically: true, encoding: .utf8)
        CheckpointStore.save(source: source, fileName: selectedFile.name)
        checkpoints = CheckpointStore.load(for: selectedFile.name)
        updateActiveTab(title: selectedFile.name, url: selectedFile.id, contents: source, dirty: false)
        output = "Saved \(selectedFile.name)"
    }

    func buildAndRun() {
        guard !isRunning else { return }
        guard let selectedFile else {
            output = "Save the file before building."
            return
        }
        guard let compilerURL = ToolchainService.detected?.compiler else { output = "No C++ compiler found. Install Xcode Command Line Tools or LLVM."; return }

        do {
            try save()
        } catch {
            output = "Could not save: \(error.localizedDescription)"
            return
        }

        let executable = FileManager.default.temporaryDirectory
            .appendingPathComponent("sameko-\(UUID().uuidString)")
        let compiler = Process()
        compiler.executableURL = compilerURL
        compiler.arguments = compilerArguments(for: selectedFile.id, executable: executable)

        let compilerPipe = Pipe()
        compiler.standardOutput = compilerPipe
        compiler.standardError = compilerPipe
        isRunning = true
        bottomPanel = .terminal
        output = "Building \(selectedFile.name)…"
        activeTask = compiler

        Task.detached { [weak self] in
            do {
                try compiler.run()
                compiler.waitUntilExit()
                let buildLog = String(data: compilerPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                guard compiler.terminationStatus == 0 else {
                    await self?.finish("Build failed\\n\(buildLog)")
                    return
                }

                let runner = Process()
                runner.executableURL = executable
                let input = Pipe(), runPipe = Pipe()
                runner.standardInput = input
                runner.standardOutput = runPipe
                runner.standardError = runPipe
                runPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                    Task { @MainActor in self?.appendTerminalOutput(text) }
                }
                await self?.setActiveTask(runner)
                await self?.setActiveInput(input.fileHandleForWriting)
                await self?.startTerminalOutput()
                try runner.run()
                runner.waitUntilExit()
                runPipe.fileHandleForReading.readabilityHandler = nil
                let finalData = runPipe.fileHandleForReading.readDataToEndOfFile()
                if let finalText = String(data: finalData, encoding: .utf8), !finalText.isEmpty { await self?.appendTerminalOutput(finalText) }
                await self?.finishTerminal(exitCode: runner.terminationStatus)
            } catch {
                await self?.finish("Could not start compiler: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        activeTask?.terminate()
        endDebugging()
        activeInput?.closeFile()
        activeInput = nil
        output += "\nStopped."
    }

    func continueDebugging() { sendDebugCommand("continue") }
    func stepOverDebugging() { sendDebugCommand("thread step-over") }
    func stepIntoDebugging() { sendDebugCommand("thread step-in") }
    func refreshDebugVariables() {
        sendDebugCommand("thread backtrace all")
        sendDebugCommand("frame variable")
    }

    func endDebugging() {
        guard let debugTask else { return }
        sendDebugCommand("quit")
        debugTask.terminate()
        finishDebugSession()
    }

    func addBreakpoint() {
        guard breakpointLine > 0, !breakpoints.contains(where: { $0.line == breakpointLine }) else { return }
        breakpoints.append(Breakpoint(line: breakpointLine))
        breakpoints.sort { $0.line < $1.line }
    }

    func removeBreakpoint(_ breakpoint: Breakpoint) {
        breakpoints.removeAll { $0.id == breakpoint.id }
    }

    func sendTerminalInput() {
        guard isRunning, !terminalInput.isEmpty, let activeInput else { return }
        let text = terminalInput + "\n"
        activeInput.write(text.data(using: .utf8) ?? Data())
        output += "> \(terminalInput)\n"
        terminalInput = ""
    }

    func runAllTests() {
        guard !isRunning, let selectedFile else {
            output = "Save the file before running tests."
            return
        }
        guard let compilerURL = ToolchainService.detected?.compiler else { output = "No C++ compiler found. Install Xcode Command Line Tools or LLVM."; return }
        do { try save() } catch { output = "Could not save: \(error.localizedDescription)"; return }

        let executable = FileManager.default.temporaryDirectory.appendingPathComponent("sameko-tests-\(UUID().uuidString)")
        isRunning = true
        output = "Building test cases…"
        Task.detached { [weak self] in
            let compiler = Process()
            compiler.executableURL = compilerURL
            compiler.arguments = await self?.compilerArguments(for: selectedFile.id, executable: executable) ?? []
            let buildPipe = Pipe()
            compiler.standardOutput = buildPipe
            compiler.standardError = buildPipe
            do {
                try compiler.run()
                compiler.waitUntilExit()
                let buildLog = String(data: buildPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                guard compiler.terminationStatus == 0 else { await self?.finish("Build failed\\n\(buildLog)"); return }
                let cases = await self?.testCases ?? []
                var results: [TestCase] = []
                for test in cases {
                    let process = Process()
                    process.executableURL = executable
                    let input = Pipe(); let response = Pipe()
                    process.standardInput = input; process.standardOutput = response; process.standardError = response
                    try process.run()
                    input.fileHandleForWriting.write(test.input.data(using: .utf8) ?? Data())
                    input.fileHandleForWriting.closeFile()
                    process.waitUntilExit()
                    var result = test
                    result.actual = String(data: response.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    result.passed = Self.normalized(result.actual) == Self.normalized(result.expected)
                    results.append(result)
                }
                await self?.finishTests(results)
            } catch { await self?.finish("Could not run tests: \(error.localizedDescription)") }
        }
    }

    func insertSnippet(_ snippet: Snippet) {
        source += (source.hasSuffix("\n") ? "\n" : "\n\n") + snippet.body + "\n"
        sourceDidChange()
    }

    func saveSnippet() {
        let name = snippetName.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = snippetBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !body.isEmpty else { return }
        if let index = snippets.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            snippets[index].body = body
        } else {
            snippets.append(Snippet(name: name, body: body))
            snippets.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        SnippetStore.save(snippets)
        snippetName = ""
        snippetBody = ""
    }

    func editSnippet(_ snippet: Snippet) {
        snippetName = snippet.name
        snippetBody = snippet.body
    }

    func deleteSnippet(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        SnippetStore.save(snippets)
    }

    func restoreCheckpoint(_ value: String) {
        source = value
        output = "Restored checkpoint. Save to write it to disk."
    }

    func clearCheckpoints() {
        guard let selectedFile else { return }
        CheckpointStore.clear(for: selectedFile.name)
        checkpoints = []
    }

    func refreshToolchainStatus() { toolchainStatus = ToolchainService.statusDescription }

    func reloadActiveFileFromDisk() {
        guard let selectedFile else { return }
        source = (try? String(contentsOf: selectedFile.id, encoding: .utf8)) ?? source
        externalChangeNotice = nil
        output = "Reloaded \(selectedFile.name) from disk."
    }

    func keepEditorVersion() { externalChangeNotice = nil }

    private func workspaceDidChangeOnDisk() {
        reloadFiles(selectFirst: false)
        guard let selectedFile,
              let diskSource = try? String(contentsOf: selectedFile.id, encoding: .utf8),
              diskSource != source else { return }
        externalChangeNotice = "\(selectedFile.name) was modified outside Sameko."
    }

    private func importCompanionProblem(_ problem: CompetitiveCompanionServer.Payload) {
        testCases = problem.tests.enumerated().map { index, test in
            TestCase(name: "Test Case \(index + 1)", input: test.input, expected: test.output)
        }
        output = "Imported \(testCases.count) tests from \(problem.name)."
    }

    func persistPreferences() {
        let defaults = UserDefaults.standard
        defaults.set(glassEnabled, forKey: "glassEnabled")
        defaults.set(glassStyle.rawValue, forKey: "glassStyle")
        defaults.set(cppStandard, forKey: "cppStandard")
        defaults.set(optimization, forKey: "optimization")
        defaults.set(warningsEnabled, forKey: "warningsEnabled")
        defaults.set(extraFlags, forKey: "extraFlags")
        defaults.set(singleFileCompile, forKey: "singleFileCompile")
        defaults.set(theme.rawValue, forKey: "theme")
        defaults.set(editorFontSize, forKey: "editorFontSize")
        defaults.set(editorTabSize, forKey: "editorTabSize")
        defaults.set(editorWordWrap, forKey: "editorWordWrap")
        defaults.set(autoSaveEnabled, forKey: "autoSaveEnabled")
        defaults.set(autoSaveDelay, forKey: "autoSaveDelay")
    }

    private func loadPreferences() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "glassEnabled") != nil { glassEnabled = defaults.bool(forKey: "glassEnabled") }
        glassStyle = GlassStyle(rawValue: defaults.string(forKey: "glassStyle") ?? "") ?? .regular
        cppStandard = defaults.string(forKey: "cppStandard") ?? cppStandard
        optimization = defaults.string(forKey: "optimization") ?? optimization
        if defaults.object(forKey: "warningsEnabled") != nil { warningsEnabled = defaults.bool(forKey: "warningsEnabled") }
        extraFlags = defaults.string(forKey: "extraFlags") ?? ""
        if defaults.object(forKey: "singleFileCompile") != nil { singleFileCompile = defaults.bool(forKey: "singleFileCompile") }
        theme = AppTheme(rawValue: defaults.string(forKey: "theme") ?? "") ?? .ocean
        if defaults.object(forKey: "editorFontSize") != nil { editorFontSize = defaults.double(forKey: "editorFontSize") }
        if defaults.object(forKey: "editorTabSize") != nil { editorTabSize = defaults.integer(forKey: "editorTabSize") }
        if defaults.object(forKey: "editorWordWrap") != nil { editorWordWrap = defaults.bool(forKey: "editorWordWrap") }
        if defaults.object(forKey: "autoSaveEnabled") != nil { autoSaveEnabled = defaults.bool(forKey: "autoSaveEnabled") }
        if defaults.object(forKey: "autoSaveDelay") != nil { autoSaveDelay = defaults.double(forKey: "autoSaveDelay") }
    }

    func openTab(title: String, url: URL?, contents: String) {
        if let existing = tabs.first(where: { $0.url == url && (url != nil || $0.title == title) }) {
            activateTab(existing)
            return
        }
        let tab = EditorTab(title: title, url: url, source: contents)
        tabs.append(tab)
        activateTab(tab)
        persistSession()
    }

    func activateTab(_ tab: EditorTab) {
        if let current = tabs.firstIndex(where: { $0.id == activeTabID }) { tabs[current].source = source }
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        activeTabID = tab.id
        source = tabs[index].source
        if let url = tabs[index].url {
            selectedFile = SourceFile(id: url)
            checkpoints = CheckpointStore.load(for: url.lastPathComponent)
            clangd.open(document: url, source: source, root: workspaceURL)
        } else {
            selectedFile = nil
            checkpoints = []
        }
        persistSession()
    }

    private func updateActiveTab(title: String, url: URL?, contents: String, dirty: Bool) {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        tabs[index].title = title
        tabs[index].url = url
        tabs[index].source = contents
        tabs[index].isDirty = dirty
        persistSession()
    }

    func closeTab(_ tab: EditorTab) {
        let closingIndex = tabs.firstIndex(where: { $0.id == tab.id }) ?? 0
        tabs.removeAll { $0.id == tab.id }
        if tabs.isEmpty { newFile(); return }
        if activeTabID == tab.id { activateTab(tabs[min(closingIndex, tabs.count - 1)]) }
        persistSession()
    }

    private func persistSession() {
        let activeIndex = tabs.firstIndex(where: { $0.id == activeTabID }) ?? 0
        WorkspaceSessionStore.save(WorkspaceSession(
            workspacePath: workspaceURL?.path,
            tabs: tabs.map { WorkspaceSession.Tab(title: $0.title, path: $0.url?.path, source: $0.source, isDirty: $0.isDirty) },
            activeIndex: activeIndex
        ))
    }

    private func restoreSession() {
        guard let session = WorkspaceSessionStore.load(), !session.tabs.isEmpty else { return }
        if let path = session.workspacePath, FileManager.default.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            workspaceURL = url
            reloadFiles(selectFirst: false)
            workspaceWatcher.watch(url)
        }
        tabs = session.tabs.map { EditorTab(title: $0.title, url: $0.path.map(URL.init(fileURLWithPath:)), source: $0.source, isDirty: $0.isDirty) }
        activateTab(tabs[min(max(0, session.activeIndex), tabs.count - 1)])
    }

    private func setActiveTask(_ process: Process) {
        activeTask = process
    }

    private func setActiveInput(_ input: FileHandle) { activeInput = input }

    private func setDebugSession(_ process: Process, input: FileHandle) {
        debugTask = process
        debugInput = input
        debugOutput = "LLDB session started.\n"
    }

    private func sendDebugCommand(_ command: String) {
        guard isDebugging, let debugInput else { return }
        debugInput.write(Data("\(command)\n".utf8))
    }

    private func appendDebugOutput(_ text: String) {
        debugOutput += text
        if debugOutput.count > 200_000 { debugOutput = String(debugOutput.suffix(200_000)) }
    }

    private func finishDebugSession() {
        debugTask = nil
        debugInput?.closeFile()
        debugInput = nil
        isDebugging = false
    }

    private func startTerminalOutput() { output = "Running…\n" }

    private func appendTerminalOutput(_ text: String) {
        output += text
        if output.count > 200_000 { output = String(output.suffix(200_000)) }
    }

    private func finishTerminal(exitCode: Int32) {
        appendTerminalOutput("\nProcess finished (exit code \(exitCode)).")
        isRunning = false
        activeTask = nil
        activeInput?.closeFile()
        activeInput = nil
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        guard autoSaveEnabled, let selectedFile else { return }
        let delay = autoSaveDelay
        let snapshot = source
        autoSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.source == snapshot else { return }
            do {
                try snapshot.write(to: selectedFile.id, atomically: true, encoding: .utf8)
                if !self.isRunning { self.output = "Autosaved \(selectedFile.name)" }
            } catch {
                if !self.isRunning { self.output = "Auto-save failed: \(error.localizedDescription)" }
            }
        }
    }

    private func finish(_ message: String) {
        output = message
        isRunning = false
        activeTask = nil
        activeInput?.closeFile()
        activeInput = nil
    }

    private func applyFormattedSource(_ formatted: String) {
        source = formatted
        output = "Formatted source."
    }

    private func finishDebug(_ value: String) {
        debugOutput = value
        output = value
        finishDebugSession()
    }

    private func compilerArguments(for file: URL, executable: URL) -> [String] {
        let inputs: [String]
        if singleFileCompile || workspaceURL == nil {
            inputs = [file.path]
        } else {
            let projectSources = files
                .map(\.id)
                .filter { ["cpp", "cc", "cxx"].contains($0.pathExtension.lowercased()) }
                .map(\.path)
            inputs = projectSources.isEmpty ? [file.path] : projectSources
        }
        var flags = inputs + ["-std=\(cppStandard)", optimization]
        if warningsEnabled { flags += ["-Wall", "-Wextra"] }
        flags += extraFlags.split(separator: " ").map(String.init)
        flags += ["-o", executable.path]
        return flags
    }

    private func finishTests(_ results: [TestCase]) {
        testCases = results
        let passed = results.filter { $0.passed == true }.count
        output = "\(passed)/\(results.count) test cases passed."
        isRunning = false
        activeTask = nil
    }

    private static func normalized(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

private extension WorkspaceModel.ThemePalette {
    init(hex start: String, _ end: String, _ editor: String, _ foreground: String, _ accent: String) {
        self.init(backdropStart: .samekoHex(start), backdropEnd: .samekoHex(end), editorBackground: .samekoHex(editor), editorForeground: .samekoHex(foreground), accent: .samekoHex(accent))
    }
}

private extension NSColor {
    static func samekoHex(_ value: String) -> NSColor {
        let hex = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var number: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&number)
        return NSColor(red: CGFloat((number >> 16) & 0xff) / 255, green: CGFloat((number >> 8) & 0xff) / 255, blue: CGFloat(number & 0xff) / 255, alpha: 1)
    }
}
