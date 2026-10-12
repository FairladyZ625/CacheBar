import Foundation
import Observation

@Observable @MainActor
public final class SessionStore {
    public private(set) var sessions: [SessionSnapshot] = []
    private let adapter = ClaudeCodeAdapter()
    private let sessionsDirectory: URL
    private let projectsDirectory: URL
    private let clock: @Sendable () -> Date
    private var transcriptSnapshots: [String: SessionSnapshot] = [:]
    private var statuslineSnapshots: [String: SessionSnapshot] = [:]
    private var pollingTask: Task<Void, Never>?

    public init(sessionsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/CacheBar/sessions"), projectsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/projects"), now: @escaping @Sendable () -> Date = Date.init) {
        self.sessionsDirectory = sessionsDirectory
        self.projectsDirectory = projectsDirectory
        clock = now
    }

    public func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            guard let self else { return }
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                await refresh()
            }
        }
    }

    public func refresh() async {
        let sessionsDirectory = self.sessionsDirectory
        let projectsDirectory = self.projectsDirectory
        let now = self.clock()
        let adapter = self.adapter
        let result = await Task.detached(priority: .utility) {
            Self.scan(sessionsDirectory: sessionsDirectory, projectsDirectory: projectsDirectory, now: now, adapter: adapter)
        }.value
        statuslineSnapshots = result.statuslines
        for snapshot in result.transcripts where snapshot.updatedAt >= (transcriptSnapshots[snapshot.sessionID]?.updatedAt ?? .distantPast) {
            transcriptSnapshots[snapshot.sessionID] = snapshot
        }
        publish(now: clock())
    }

    nonisolated private static func scan(sessionsDirectory: URL, projectsDirectory: URL, now: Date, adapter: ClaudeCodeAdapter) -> (statuslines: [String: SessionSnapshot], transcripts: [SessionSnapshot]) {
        var statuslines: [String: SessionSnapshot] = [:]
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for file in files where file.pathExtension == "json" {
                guard let data = try? Data(contentsOf: file), var value = try? adapter.snapshot(fromStatusline: data, now: now) else { continue }
                value.updatedAt = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? now
                statuslines[value.sessionID] = value
            }
        }
        var transcripts: [SessionSnapshot] = []
        if let enumerator = fm.enumerator(at: projectsDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for case let file as URL in enumerator where file.pathExtension == "jsonl" {
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                guard modified >= now.addingTimeInterval(-86_400), let data = tailData(file, limit: 64 * 1024), let values = try? adapter.snapshots(fromTranscript: data) else { continue }
                transcripts.append(contentsOf: values)
            }
        }
        return (statuslines, transcripts)
    }

    nonisolated private static func tailData(_ file: URL, limit: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let start = size > UInt64(limit) ? size - UInt64(limit) : 0
        try? handle.seek(toOffset: start)
        var data = handle.readData(ofLength: Int(size - start))
        if start > 0, let newline = data.firstIndex(of: 0x0A) { data = Data(data[data.index(after: newline)...]) }
        return data
    }

    private func publish(now: Date) {
        sessions = Set(statuslineSnapshots.keys).union(transcriptSnapshots.keys).compactMap { SessionSnapshot.merged(statusline: statuslineSnapshots[$0], transcript: transcriptSnapshots[$0]) }.filter {
            if let expiry = $0.expiresAt { return expiry >= now.addingTimeInterval(-86_400) }
            return $0.updatedAt >= now.addingTimeInterval(-86_400)
        }.sorted { left, right in
            let leftExpired = left.expiresAt.map { $0 < now } ?? false
            let rightExpired = right.expiresAt.map { $0 < now } ?? false
            if leftExpired != rightExpired { return !leftExpired }
            switch (left.expiresAt, right.expiresAt) {
            case let (a?, b?): return a < b
            case (_?, nil): return true
            case (nil, _?): return false
            default: return left.sessionID < right.sessionID
            }
        }
    }

}
