import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class WorkspaceModel {
    struct SourceFile: Identifiable, Hashable {
        let id: URL
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
    var glassEnabled = true
    var glassStyle: GlassStyle = .regular

    private var activeTask: Process?

    enum GlassStyle: String, CaseIterable, Identifiable {
        case regular = "Regular"
        case clear = "Clear"
        var id: String { rawValue }
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        workspaceURL = url
        reloadFiles()
    }

    func reloadFiles() {
        guard let workspaceURL else { return }
        let keys: Set<URLResourceKey> = [.isRegularFileKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: workspaceURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )) ?? []

        files = urls
            .filter { ["cpp", "cc", "cxx", "h", "hpp"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map(SourceFile.init)

        if let first = files.first { select(first) }
    }

    func select(_ file: SourceFile) {
        selectedFile = file
        source = (try? String(contentsOf: file.id, encoding: .utf8)) ?? ""
        output = "Opened \(file.name)"
    }

    func newFile() {
        selectedFile = nil
        source = """
        #include <iostream>

        int main() {
            return 0;
        }
        """
        output = "New unsaved file"
    }

    func save() throws {
        guard let selectedFile else {
            throw CocoaError(.fileNoSuchFile)
        }
        try source.write(to: selectedFile.id, atomically: true, encoding: .utf8)
        output = "Saved \(selectedFile.name)"
    }

    func buildAndRun() {
        guard !isRunning else { return }
        guard let selectedFile else {
            output = "Save the file before building."
            return
        }

        do {
            try save()
        } catch {
            output = "Could not save: \(error.localizedDescription)"
            return
        }

        let executable = FileManager.default.temporaryDirectory
            .appendingPathComponent("sameko-\(UUID().uuidString)")
        let compiler = Process()
        compiler.executableURL = URL(fileURLWithPath: "/usr/bin/clang++")
        compiler.arguments = [selectedFile.id.path, "-std=c++20", "-O0", "-o", executable.path]

        let pipe = Pipe()
        compiler.standardOutput = pipe
        compiler.standardError = pipe
        isRunning = true
        output = "Building \(selectedFile.name)…"
        activeTask = compiler

        Task.detached { [weak self] in
            do {
                try compiler.run()
                compiler.waitUntilExit()
                let buildLog = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                guard compiler.terminationStatus == 0 else {
                    await self?.finish("Build failed\\n\(buildLog)")
                    return
                }

                let runner = Process()
                runner.executableURL = executable
                let runPipe = Pipe()
                runner.standardOutput = runPipe
                runner.standardError = runPipe
                await self?.setActiveTask(runner)
                try runner.run()
                runner.waitUntilExit()
                let runLog = String(data: runPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                await self?.finish(runLog.isEmpty ? "Program finished." : runLog)
            } catch {
                await self?.finish("Could not start compiler: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        activeTask?.terminate()
        output += "\\nStopped."
    }

    private func setActiveTask(_ process: Process) {
        activeTask = process
    }

    private func finish(_ message: String) {
        output = message
        isRunning = false
        activeTask = nil
    }
}
