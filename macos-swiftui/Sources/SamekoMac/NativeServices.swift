import Foundation
import Network
import Darwin

/// Persistent stores replace Electron's JSON files under AppData.
enum SamekoStorage {
    static let root: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("SamekoMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let checkpoints = root.appendingPathComponent("checkpoints", isDirectory: true)
    static let snippets = root.appendingPathComponent("snippets.json")
}

struct CheckpointRecord: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let fileName: String
    let source: String
}

enum CheckpointStore {
    static func load(for fileName: String) -> [CheckpointRecord] {
        let file = SamekoStorage.checkpoints.appendingPathComponent("\(fileName).json")
        guard let data = try? Data(contentsOf: file) else { return [] }
        return (try? JSONDecoder().decode([CheckpointRecord].self, from: data)) ?? []
    }

    static func save(source: String, fileName: String, limit: Int = 20) {
        try? FileManager.default.createDirectory(at: SamekoStorage.checkpoints, withIntermediateDirectories: true)
        let file = SamekoStorage.checkpoints.appendingPathComponent("\(fileName).json")
        var values = load(for: fileName)
        values.insert(CheckpointRecord(id: UUID(), createdAt: .now, fileName: fileName, source: source), at: 0)
        if values.count > limit { values.removeLast(values.count - limit) }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try? encoder.encode(values).write(to: file, options: .atomic)
    }

    static func clear(for fileName: String) {
        let file = SamekoStorage.checkpoints.appendingPathComponent("\(fileName).json")
        try? FileManager.default.removeItem(at: file)
    }
}

enum SnippetStore {
    static func load() -> [WorkspaceModel.Snippet] {
        guard let data = try? Data(contentsOf: SamekoStorage.snippets) else { return [] }
        return (try? JSONDecoder().decode([WorkspaceModel.Snippet].self, from: data)) ?? []
    }

    static func save(_ snippets: [WorkspaceModel.Snippet]) {
        guard let data = try? JSONEncoder().encode(snippets) else { return }
        try? data.write(to: SamekoStorage.snippets, options: .atomic)
    }
}

struct WorkspaceSession: Codable {
    struct Tab: Codable {
        var title: String
        var path: String?
        var source: String
        var isDirty: Bool
    }
    var workspacePath: String?
    var tabs: [Tab]
    var activeIndex: Int
}

enum WorkspaceSessionStore {
    private static let key = "workspaceSession"
    static func load() -> WorkspaceSession? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WorkspaceSession.self, from: data)
    }
    static func save(_ session: WorkspaceSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// Coalesces filesystem events for an open workspace. The model decides whether
/// a changed active buffer should be reloaded, so an editor never loses edits.
final class WorkspaceWatcher {
    var onChange: (@Sendable () -> Void)?
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1

    func watch(_ directory: URL) {
        stop()
        descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler { [weak self] in self?.onChange?() }
        source.setCancelHandler { [descriptor] in if descriptor >= 0 { close(descriptor) } }
        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
        descriptor = -1
    }

    deinit { stop() }
}

/// Receives standard Competitive Companion JSON posts at localhost:10043.
final class CompetitiveCompanionServer: @unchecked Sendable {
    struct Payload: Codable, Sendable {
        struct Test: Codable, Sendable { let input: String; let output: String }
        let name: String
        let url: String?
        let tests: [Test]
    }

    var onProblem: (@Sendable (Payload) -> Void)?
    private var listener: NWListener?

    func start() throws {
        guard listener == nil else { return }
        let listener = try NWListener(using: .tcp, on: 10043)
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .global(qos: .utility))
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, _, _ in
                defer { connection.cancel() }
                guard let server = self else { return }
                guard let data,
                      let request = String(data: data, encoding: .utf8),
                      let separator = request.range(of: "\r\n\r\n") else { return }
                let body = Data(request[separator.upperBound...].utf8)
                guard let payload = try? JSONDecoder().decode(Payload.self, from: body) else { return }
                connection.send(content: Data("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK".utf8), completion: .contentProcessed { _ in })
                server.onProblem?(payload)
            }
        }
        listener.start(queue: .global(qos: .utility))
        self.listener = listener
    }

    func stop() { listener?.cancel(); listener = nil }
}

enum ToolchainService {
    struct Toolchain: Sendable {
        let compiler: URL
        let debugger: URL?
        let formatter: URL?
        let label: String
    }

    static var detected: Toolchain? {
        let manager = FileManager.default
        let candidates = [
            ("Xcode Command Line Tools", "/usr/bin/clang++", "/usr/bin/lldb", "/usr/bin/clang-format"),
            ("Homebrew LLVM (Apple Silicon)", "/opt/homebrew/opt/llvm/bin/clang++", "/opt/homebrew/opt/llvm/bin/lldb", "/opt/homebrew/opt/llvm/bin/clang-format"),
            ("Homebrew LLVM (Intel)", "/usr/local/opt/llvm/bin/clang++", "/usr/local/opt/llvm/bin/lldb", "/usr/local/opt/llvm/bin/clang-format")
        ]
        for (label, compiler, debugger, formatter) in candidates where manager.isExecutableFile(atPath: compiler) {
            return Toolchain(
                compiler: URL(fileURLWithPath: compiler),
                debugger: manager.isExecutableFile(atPath: debugger) ? URL(fileURLWithPath: debugger) : nil,
                formatter: manager.isExecutableFile(atPath: formatter) ? URL(fileURLWithPath: formatter) : nil,
                label: label
            )
        }
        return nil
    }

    static var statusDescription: String {
        guard let toolchain = detected else { return "No C++ toolchain found — install Xcode Command Line Tools or LLVM." }
        return "\(toolchain.label): \(toolchain.compiler.path)"
    }

    static func diagnose(file: URL, standard: String, completion: @escaping @Sendable (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let compiler = detected?.compiler else { completion("No C++ compiler found. Install Xcode Command Line Tools or LLVM."); return }
            let process = Process(); process.executableURL = compiler
            process.arguments = ["-std=\(standard)", "-fsyntax-only", file.path]
            let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe
            guard (try? process.run()) != nil else { completion("Unable to start clang++."); return }
            process.waitUntilExit()
            completion(String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
        }
    }
}
