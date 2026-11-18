import Foundation
import Testing
@testable import SendaPersistence

struct NotebookBackupDestinationTests {
    @Test func rememberedFolderSavesNewVersionsWithoutReplacingPreviousCopies() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }

        let destination = try NotebookBackupDestination(folder: folder)
        let stored = try JSONEncoder().encode(destination)
        let remembered = try JSONDecoder().decode(NotebookBackupDestination.self, from: stored)
        #expect(remembered == destination)
        #expect(remembered.name == folder.lastPathComponent)

        let firstCopy = Data("First backup".utf8)
        let secondCopy = Data("Second backup".utf8)
        try await remembered.write(firstCopy, filename: "senda-backup-1.json")
        try await remembered.write(secondCopy, filename: "senda-backup-2.json")
        await #expect(throws: (any Error).self) {
            try await remembered.write(secondCopy, filename: "senda-backup-1.json")
        }
        #expect(try Data(contentsOf: folder.appendingPathComponent("senda-backup-1.json")) == firstCopy)
        #expect(try Data(contentsOf: folder.appendingPathComponent("senda-backup-2.json")) == secondCopy)
        #expect(try Set(FileManager.default.contentsOfDirectory(atPath: folder.path)) == ["senda-backup-1.json", "senda-backup-2.json"])
    }

    @Test func pathComponentsCannotEscapeTheSelectedFolder() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let folder = root.appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let destination = try NotebookBackupDestination(folder: folder)
        await #expect(throws: (any Error).self) {
            try await destination.write(Data("Backup".utf8), filename: "../outside.json")
        }
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("outside.json").path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
    }
}
