import Darwin
import Foundation

/// A user-selected Files folder. Writing a copy does not confirm the provider uploaded it.
public struct NotebookBackupDestination: Codable, Equatable, Sendable {
    public let name: String
    private let bookmark: Data
    private let requiresScope: Bool

    public init(folder: URL, validate: (URL) throws -> Void = { _ in }) throws {
        guard folder.isFileURL else { throw DestinationError.notAFolder }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        try validate(folder)
        try self.init(accessing: folder, scoped: scoped)
    }

    private init(accessing folder: URL, scoped: Bool) throws {
        guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
            throw DestinationError.notAFolder
        }
        #if os(macOS)
        let options: URL.BookmarkCreationOptions = scoped ? .withSecurityScope : .minimalBookmark
        #else
        let options: URL.BookmarkCreationOptions = .minimalBookmark
        #endif
        do {
            bookmark = try folder.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            throw DestinationError.folderUnavailable
        }
        name = folder.lastPathComponent
        requiresScope = scoped
    }

    public static func requirePrivateICloud(_ folder: URL) throws {
        var current = folder
        current.removeAllCachedResourceValues()
        let values = try current.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemIsSharedKey])
        guard values.isUbiquitousItem == true, values.ubiquitousItemIsShared == false else {
            throw DestinationError.privateICloudRequired
        }
    }

    /// Returns the current bookmark after Files moves or renames the selected folder.
    @discardableResult
    public func write(_ data: Data, filename: String,
                      validate: @escaping @Sendable (URL) throws -> Void = { _ in }) async throws -> Self {
        guard filename.utf8.count <= 255, !filename.hasPrefix("."), filename.hasSuffix(".json"),
              filename.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) ||
                  (97...122).contains($0) || $0 == 45 || $0 == 46 || $0 == 95 }) else {
            throw DestinationError.invalidFilename
        }
        guard data.count <= NotebookBackupCodec.maxImportBytes else { throw NotebookBackupError.tooLarge }
        try Task.checkCancellation()
        let task = Task.detached(priority: .utility) {
            var stale = false
            #if os(macOS)
            let options: URL.BookmarkResolutionOptions = requiresScope ? .withSecurityScope : []
            #else
            let options: URL.BookmarkResolutionOptions = []
            #endif
            guard let folder = try? URL(resolvingBookmarkData: bookmark, options: options, bookmarkDataIsStale: &stale)
            else { throw DestinationError.folderUnavailable }
            let scoped = folder.startAccessingSecurityScopedResource()
            defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
            guard scoped || !requiresScope else { throw DestinationError.folderUnavailable }
            try validate(folder)
            let destination = stale || folder.lastPathComponent != name
                ? try Self(accessing: folder, scoped: scoped) : self

            var coordinationError: NSError?
            var result: Result<Void, any Error>?
            NSFileCoordinator().coordinate(writingItemAt: folder, error: &coordinationError) { coordinatedFolder in
                result = Result {
                    try Task.checkCancellation()
                    try validate(coordinatedFolder)
                    try Self.writeCopy(data, filename: filename, to: coordinatedFolder)
                }
            }
            guard coordinationError == nil, let result else { throw DestinationError.folderUnavailable }
            try result.get()
            return destination
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func writeCopy(_ data: Data, filename: String, to folder: URL) throws {
        let directory = open(folder.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard directory >= 0 else { throw DestinationError.folderUnavailable }
        defer { close(directory) }
        // Stage and publish within the same directory. Exclusive rename never replaces a prior copy.
        let scratch = ".senda-\(UUID().uuidString).tmp"
        let descriptor = openat(directory, scratch, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw DestinationError.writeFailed }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        var published = false
        defer {
            if !published { unlinkat(directory, scratch, 0) }
        }
        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
        } catch {
            throw DestinationError.writeFailed
        }
        try Task.checkCancellation()
        guard renameatx_np(directory, scratch, directory, filename, UInt32(RENAME_EXCL)) == 0 else {
            throw errno == EEXIST ? DestinationError.alreadyExists : DestinationError.writeFailed
        }
        published = true
    }

    private enum DestinationError: LocalizedError {
        case notAFolder, folderUnavailable, privateICloudRequired, invalidFilename, alreadyExists, writeFailed

        var errorDescription: String? {
            switch self {
            case .notAFolder: "Choose a folder that Senda can open."
            case .folderUnavailable: "Senda can’t open the backup folder. Choose the folder again."
            case .privateICloudRequired: "Choose a private folder in iCloud Drive."
            case .invalidFilename: "This backup filename is invalid."
            case .alreadyExists: "A backup with this filename already exists. Try again to save a new copy."
            case .writeFailed: "Check the backup folder’s available space and permissions, then try again."
            }
        }
    }
}
