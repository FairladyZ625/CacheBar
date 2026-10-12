import Foundation
import Observation

@Observable @MainActor
public final class SessionStore {
    public private(set) var sessions: [SessionSnapshot] = []
    private let adapter = ClaudeCodeAdapter()
    private let fileManager = FileManager.default
    private let sessionsDirectory: URL
    private let projectsDirectory: URL
    private let clock: () -> Date
    private var offsets: [URL: UInt64] = [:]
    private var partialLines: [URL: Data] = [:]
    private var transcriptSnapshots: [String: SessionSnapshot] = [:]
    private var statuslineSnapshots: [String: SessionSnapshot] = [:]
    private var sources: [DispatchSourceFileSystemObject] = []

    public init(sessionsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/CacheBar/sessions"), projectsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/projects"), now: @escaping () -> Date = Date.init) {
        self.sessionsDirectory = sessionsDirectory
        self.projectsDirectory = projectsDirectory
        clock = now
    }

    public func start() {
        refresh()
        watch(sessionsDirectory)
        watch(projectsDirectory)
    }

    public func refresh() {
        var latestStatuslines: [String: SessionSnapshot] = [:]
        if let files = try? fileManager.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                guard let data = try? Data(contentsOf: file), var value = try? adapter.snapshot(fromStatusline: data, now: clock()) else { continue }
                value.updatedAt = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? clock()
                latestStatuslines[value.sessionID] = value
            }
        }
        statuslineSnapshots = latestStatuslines
        if let enumerator = fileManager.enumerator(at: projectsDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let file as URL in enumerator where file.pathExtension == "jsonl" { consumeTail(file) }
        }
        publish()
    }

    private func consumeTail(_ file: URL) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return }
        defer { try? handle.close() }
        let offset = offsets[file] ?? 0
        try? handle.seek(toOffset: offset)
        let data = handle.readDataToEndOfFile()
        guard !data.isEmpty else { return }
        offsets[file] = offset + UInt64(data.count)
        var pending = partialLines[file, default: Data()]
        pending.append(data)
        let bytes = [UInt8](pending)
        let newlineOffsets = bytes.indices.filter { bytes[$0] == 0x0A }
        var start = 0
        for end in newlineOffsets {
            let line = Data(bytes[start..<end])
            start = end + 1
            var completeLine = line
            completeLine.append(0x0A)
            guard let records = try? adapter.snapshots(fromTranscript: completeLine), let snapshot = records.first else { continue }
            if snapshot.updatedAt >= (transcriptSnapshots[snapshot.sessionID]?.updatedAt ?? .distantPast) {
                transcriptSnapshots[snapshot.sessionID] = snapshot
            }
        }
        partialLines[file] = Data(bytes.dropFirst(start))
    }

    private func publish() {
        let now = clock()
        sessions = Set(statuslineSnapshots.keys).union(transcriptSnapshots.keys).compactMap {
            SessionSnapshot.merged(statusline: statuslineSnapshots[$0], transcript: transcriptSnapshots[$0])
        }.filter { snapshot in
            guard let expiry = snapshot.expiresAt else { return true }
            return expiry >= now.addingTimeInterval(-86_400)
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

    private func watch(_ directory: URL) {
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in self?.refresh() }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        sources.append(source)
    }
}
