//
//  CacheService.swift
//  celon-compass
//
//  Measures and clears downloaded, re-creatable files (offline maps, photos, URL cache)
//  no impact on Core Data, trips, notes and memories 
//

import Foundation

nonisolated protocol CacheManaging: Sendable {
    func totalSize() async -> Int64
    func clear() async throws
}

nonisolated struct CacheService: CacheManaging {
    private let directories: [URL]
    private let includesURLCache: Bool

    // Cache folders the app writes to
    static var defaultDirectories: [URL] {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return ["OfflineMaps", "Photos"].map { caches.appendingPathComponent($0, isDirectory: true) }
    }

    init(directories: [URL] = CacheService.defaultDirectories, includesURLCache: Bool = true) {
        self.directories = directories
        self.includesURLCache = includesURLCache
    }

    func totalSize() async -> Int64 {
        let directories = directories
        let includesURLCache = includesURLCache
        return await Task.detached(priority: .utility) {
            var total = directories.reduce(Int64(0)) { $0 + Self.size(of: $1) }
            if includesURLCache {
                total += Int64(URLCache.shared.currentDiskUsage)
            }
            return total
        }.value
    }

    func clear() async throws {
        let directories = directories
        let includesURLCache = includesURLCache
        try await Task.detached(priority: .utility) {
            var firstError: Error?
            for directory in directories {
                do {
                    try Self.removeContents(of: directory)
                } catch {
                    firstError = firstError ?? error
                }
            }
            if includesURLCache {
                URLCache.shared.removeAllCachedResponses()
            }
            if let firstError { throw firstError }
        }.value
    }

    private static func size(of directory: URL) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys
        ) else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }

    private static func removeContents(of directory: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else { return }
        for item in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try fileManager.removeItem(at: item)
        }
    }
}
