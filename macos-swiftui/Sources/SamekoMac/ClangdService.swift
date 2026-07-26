import Foundation

struct ClangdCompletion: Identifiable, Hashable, Sendable {
    let label: String
    let insertText: String
    var id: String { "\(label)\u{0}\(insertText)" }
}

/// Small JSON-RPC/LSP client for the system clangd.  It deliberately owns a
/// single document because Sameko Mac currently has one active source buffer.
final class ClangdService: @unchecked Sendable {
    typealias DiagnosticsHandler = @Sendable ([String]) -> Void

    var onDiagnostics: DiagnosticsHandler?
    private let queue = DispatchQueue(label: "me.wibu.sameko.clangd", qos: .userInitiated)
    private var process: Process?
    private var input: FileHandle?
    private var buffer = Data()
    private var nextID = 1
    private var pending: [Int: (Result<Any, Error>) -> Void] = [:]
    private var documentURL: URL?
    private var documentVersion = 0
    private var isReady = false

    func open(document: URL, source: String, root: URL?) {
        queue.async { [weak self] in
            guard let self else { return }
            self.documentURL = document
            self.documentVersion = 1
            if self.process == nil { self.launch(root: root, source: source) }
            else if self.isReady { self.didOpen(source) }
        }
    }

    func update(source: String) {
        queue.async { [weak self] in
            guard let self, self.isReady, self.documentURL != nil else { return }
            self.documentVersion += 1
            self.notify("textDocument/didChange", [
                "textDocument": ["uri": self.documentURL!.absoluteString, "version": self.documentVersion],
                "contentChanges": [["text": source]]
            ])
        }
    }

    func completions(line: Int, column: Int, source: String, reply: @escaping @Sendable ([ClangdCompletion]) -> Void) {
        queue.async { [weak self] in
            guard let self, self.isReady, let url = self.documentURL else { reply([]); return }
            self.request("textDocument/completion", [
                "textDocument": ["uri": url.absoluteString],
                "position": ["line": line, "character": column],
                "context": ["triggerKind": 1]
            ]) { result in
                let values: [[String: Any]]
                if let items = result as? [[String: Any]] { values = items }
                else if let object = result as? [String: Any], let items = object["items"] as? [[String: Any]] { values = items }
                else { values = [] }
                reply(values.compactMap { item in
                    guard let label = item["label"] as? String else { return nil }
                    return ClangdCompletion(label: label, insertText: (item["insertText"] as? String) ?? label)
                })
            }
        }
    }

    func hover(line: Int, column: Int, reply: @escaping @Sendable (String?) -> Void) {
        queue.async { [weak self] in
            guard let self, self.isReady, let url = self.documentURL else { reply(nil); return }
            self.request("textDocument/hover", [
                "textDocument": ["uri": url.absoluteString],
                "position": ["line": line, "character": column]
            ]) { result in
                guard let object = result as? [String: Any] else { reply(nil); return }
                reply(Self.hoverText(from: object["contents"]))
            }
        }
    }

    func stop() {
        queue.async { [weak self] in self?.shutdown() }
    }

    private func launch(root: URL?, source: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["clangd", "--background-index", "--clang-tidy=false"]
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        task.standardInput = stdin; task.standardOutput = stdout; task.standardError = stderr
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let service = self else { return }
            service.queue.async { service.receive(data) }
        }
        task.terminationHandler = { [weak self] _ in
            guard let service = self else { return }
            service.queue.async { service.reset() }
        }
        do {
            try task.run()
            process = task; input = stdin.fileHandleForWriting
            let rootURI = (root ?? documentURL?.deletingLastPathComponent())?.absoluteString ?? ""
            request("initialize", [
                "processId": ProcessInfo.processInfo.processIdentifier,
                "rootUri": rootURI,
                "capabilities": [
                    "textDocument": [
                        "completion": ["completionItem": ["snippetSupport": false]],
                        "publishDiagnostics": ["relatedInformation": false]
                    ]
                ]
            ]) { [weak self] result in
                guard let self else { return }
                self.isReady = true
                self.notify("initialized", [:])
                self.didOpen(source)
            }
        } catch {
            reset()
            onDiagnostics?(["clangd is unavailable. Install LLVM (for example: brew install llvm)."])
        }
    }

    private func didOpen(_ source: String) {
        guard let url = documentURL else { return }
        notify("textDocument/didOpen", [
            "textDocument": ["uri": url.absoluteString, "languageId": "cpp", "version": documentVersion, "text": source]
        ])
    }

    private func request(_ method: String, _ params: [String: Any], reply: @escaping (Any) -> Void) {
        let id = nextID; nextID += 1
        pending[id] = { result in if case let .success(value) = result { reply(value) } else { reply([]) } }
        send(["jsonrpc": "2.0", "id": id, "method": method, "params": params])
    }

    private func notify(_ method: String, _ params: [String: Any]) {
        send(["jsonrpc": "2.0", "method": method, "params": params])
    }

    private func send(_ object: [String: Any]) {
        guard let input, let json = try? JSONSerialization.data(withJSONObject: object) else { return }
        var payload = Data("Content-Length: \(json.count)\r\n\r\n".utf8)
        payload.append(json)
        try? input.write(contentsOf: payload)
    }

    private func receive(_ data: Data) {
        buffer.append(data)
        while let headerRange = buffer.range(of: Data("\r\n\r\n".utf8)) {
            let header = String(decoding: buffer[..<headerRange.lowerBound], as: UTF8.self)
            guard let match = header.range(of: "Content-Length: ", options: .caseInsensitive),
                  let length = Int(header[match.upperBound...].split(separator: "\r").first ?? "") else {
                buffer.removeSubrange(..<headerRange.upperBound); continue
            }
            let bodyStart = headerRange.upperBound
            guard buffer.distance(from: bodyStart, to: buffer.endIndex) >= length else { return }
            let bodyEnd = buffer.index(bodyStart, offsetBy: length)
            let body = buffer[bodyStart..<bodyEnd]
            buffer.removeSubrange(..<bodyEnd)
            guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { continue }
            handle(object)
        }
    }

    private func handle(_ message: [String: Any]) {
        if let id = message["id"] as? Int, let callback = pending.removeValue(forKey: id) {
            if let error = message["error"] { callback(.failure(LSPError.response("\(error)"))) }
            else { callback(.success(message["result"] ?? [])) }
            return
        }
        guard message["method"] as? String == "textDocument/publishDiagnostics",
              let params = message["params"] as? [String: Any],
              let diagnostics = params["diagnostics"] as? [[String: Any]] else { return }
        let messages = diagnostics.compactMap { item -> String? in
            guard let text = item["message"] as? String else { return nil }
            let line = ((item["range"] as? [String: Any])?["start"] as? [String: Any])?["line"] as? Int
            return line.map { "Line \($0 + 1): \(text)" } ?? text
        }
        onDiagnostics?(messages)
    }

    private static func hoverText(from value: Any?) -> String? {
        if let text = value as? String { return text }
        if let object = value as? [String: Any] { return object["value"] as? String }
        if let values = value as? [Any] {
            let text = values.compactMap { hoverText(from: $0) }.joined(separator: "\n\n")
            return text.isEmpty ? nil : text
        }
        return nil
    }

    private func shutdown() { process?.terminate(); reset() }
    private func reset() { process = nil; input = nil; isReady = false; buffer.removeAll(); pending.removeAll() }

    private enum LSPError: Error { case response(String) }
}
