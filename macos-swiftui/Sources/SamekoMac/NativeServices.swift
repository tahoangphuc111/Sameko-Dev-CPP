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
    /// The old Electron migration keyed history by filename.  That made every
    /// `main.cpp` share a timeline; keep it scoped to the canonical file URL.
    private static func storageURL(for fileURL: URL) -> URL {
        let key = fileURL.standardizedFileURL.absoluteString
            .data(using: .utf8)!
            .base64EncodedString()
            .replacing("/", with: "_")
        return SamekoStorage.checkpoints.appendingPathComponent("\(key).json")
    }

    static func load(for fileURL: URL) -> [CheckpointRecord] {
        let file = storageURL(for: fileURL)
        guard let data = try? Data(contentsOf: file) else { return [] }
        return (try? JSONDecoder().decode([CheckpointRecord].self, from: data)) ?? []
    }

    static func save(source: String, for fileURL: URL, limit: Int = 20) {
        try? FileManager.default.createDirectory(at: SamekoStorage.checkpoints, withIntermediateDirectories: true)
        let file = storageURL(for: fileURL)
        var values = load(for: fileURL)
        values.insert(CheckpointRecord(id: UUID(), createdAt: .now, fileName: fileURL.lastPathComponent, source: source), at: 0)
        if values.count > limit { values.removeLast(values.count - limit) }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try? encoder.encode(values).write(to: file, options: .atomic)
    }

    static func clear(for fileURL: URL) {
        let file = storageURL(for: fileURL)
        try? FileManager.default.removeItem(at: file)
    }
}

enum TestCaseStore {
    private static func storageURL(for fileURL: URL) -> URL {
        let key = fileURL.standardizedFileURL.absoluteString
            .data(using: .utf8)!
            .base64EncodedString()
            .replacing("/", with: "_")
        return SamekoStorage.root.appendingPathComponent("tests-\(key).json")
    }

    static func load(for fileURL: URL) -> [WorkspaceModel.TestCase] {
        guard let data = try? Data(contentsOf: storageURL(for: fileURL)) else { return [] }
        return (try? JSONDecoder().decode([WorkspaceModel.TestCase].self, from: data)) ?? []
    }

    static func save(_ tests: [WorkspaceModel.TestCase], for fileURL: URL) {
        guard let data = try? JSONEncoder().encode(tests) else { return }
        try? data.write(to: storageURL(for: fileURL), options: .atomic)
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
            self?.receiveRequest(on: connection, buffer: Data())
        }
        listener.start(queue: .global(qos: .utility))
        self.listener = listener
    }

    func stop() { listener?.cancel(); listener = nil }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, _ in
            guard let self else { connection.cancel(); return }
            var bytes = buffer
            if let data { bytes.append(data) }

            guard let headerEnd = bytes.range(of: Data("\r\n\r\n".utf8)) else {
                guard bytes.count < 1_048_576, !isComplete else { connection.cancel(); return }
                self.receiveRequest(on: connection, buffer: bytes)
                return
            }
            let headers = String(decoding: bytes[..<headerEnd.lowerBound], as: UTF8.self)
            let length = headers.split(separator: "\n").compactMap { line -> Int? in
                let parts = line.split(separator: ":", maxSplits: 1)
                return parts.count == 2 && parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "content-length"
                    ? Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) : nil
            }.first ?? 0
            let bodyStart = headerEnd.upperBound
            guard bytes.distance(from: bodyStart, to: bytes.endIndex) >= length else {
                guard bytes.count < 1_048_576, !isComplete else { connection.cancel(); return }
                self.receiveRequest(on: connection, buffer: bytes)
                return
            }
            let bodyEnd = bytes.index(bodyStart, offsetBy: length)
            guard let payload = try? JSONDecoder().decode(Payload.self, from: bytes[bodyStart..<bodyEnd]) else {
                connection.cancel(); return
            }
            connection.send(content: Data("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK".utf8), completion: .contentProcessed { _ in connection.cancel() })
            self.onProblem?(payload)
        }
    }
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
