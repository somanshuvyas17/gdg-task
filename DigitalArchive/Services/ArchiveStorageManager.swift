import Foundation
import UIKit

/// Manages physical file storage, relative path resolution, atomic moves, and sandboxed directories.
public final class ArchiveStorageManager: @unchecked Sendable {
    public static let shared = ArchiveStorageManager()

    private let fileManager = FileManager.default

    public let baseArchiveURL: URL
    public let filesDirectoryURL: URL
    public let stagingDirectoryURL: URL
    public let thumbnailsDirectoryURL: URL

    public init(baseDirectory: URL? = nil) {
        let documentsURL = baseDirectory ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.baseArchiveURL = documentsURL.appendingPathComponent("DigitalArchive", isDirectory: true)
        self.filesDirectoryURL = baseArchiveURL.appendingPathComponent("Files", isDirectory: true)
        self.stagingDirectoryURL = baseArchiveURL.appendingPathComponent("Staging", isDirectory: true)
        self.thumbnailsDirectoryURL = baseArchiveURL.appendingPathComponent("Thumbnails", isDirectory: true)

        createDirectoriesIfNeeded()
    }

    /// Ensures required archive directory structure exists
    public func createDirectoriesIfNeeded() {
        let dirs = [baseArchiveURL, filesDirectoryURL, stagingDirectoryURL, thumbnailsDirectoryURL]
        for dir in dirs {
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }

    /// Resolves a stored relative path to a valid absolute sandboxed URL
    public func fileURL(for relativePath: String) -> URL {
        return baseArchiveURL.appendingPathComponent(relativePath)
    }

    /// Checks the current status of the physical file on disk (missing vs unreadable vs available)
    public func checkFileStatus(for relativePath: String) -> ArchiveStatus {
        let url = fileURL(for: relativePath)
        let path = url.path

        guard fileManager.fileExists(atPath: path) else {
            return .missing
        }

        guard fileManager.isReadableFile(atPath: path) else {
            return .unreadable
        }

        // Test actual access to ensure file isn't locked, unreadable, or corrupted
        if let handle = try? FileHandle(forReadingFrom: url) {
            try? handle.close()
        } else {
            return .unreadable
        }

        return .available
    }

    /// Copies a security-scoped or local source file into staging atomically
    public func stageIncomingFile(from sourceURL: URL) throws -> (stagingURL: URL, originalName: String, fileExtension: String) {
        let isSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        createDirectoriesIfNeeded()

        let originalName = sourceURL.lastPathComponent
        let fileExtension = sourceURL.pathExtension
        let stagingFileName = "staging_\(UUID().uuidString).\(fileExtension)"
        let stagingURL = stagingDirectoryURL.appendingPathComponent(stagingFileName)

        // Ensure source exists and is readable
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw ArchiveStorageError.sourceNotFound(sourceURL.path)
        }

        // Copy atomically to staging
        try fileManager.copyItem(at: sourceURL, to: stagingURL)

        return (stagingURL, originalName, fileExtension)
    }

    /// Commits a staged file into the permanent archive files directory
    public func commitStagedFile(stagingURL: URL, fileExtension: String) throws -> (relativePath: String, absoluteURL: URL) {
        createDirectoriesIfNeeded()

        let permanentFileName = "\(UUID().uuidString).\(fileExtension)"
        let permanentRelativePath = "Files/\(permanentFileName)"
        let permanentDestinationURL = filesDirectoryURL.appendingPathComponent(permanentFileName)

        if fileManager.fileExists(atPath: permanentDestinationURL.path) {
            try? fileManager.removeItem(at: permanentDestinationURL)
        }

        try fileManager.moveItem(at: stagingURL, to: permanentDestinationURL)

        return (permanentRelativePath, permanentDestinationURL)
    }

    /// Deletes a physical file located at the specified relative path
    public func deletePhysicalFile(relativePath: String) throws {
        let url = fileURL(for: relativePath)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    /// Simulates external file deletion (for testing missing file handling)
    public func simulateExternalDeletion(relativePath: String) throws {
        let url = fileURL(for: relativePath)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        } else {
            throw ArchiveStorageError.fileAlreadyMissing
        }
    }

    /// Replaces or relinks a missing file with a newly selected physical file
    public func relinkFile(relativePath: String, newSourceURL: URL) throws {
        let isSecurityScoped = newSourceURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                newSourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let destinationURL = fileURL(for: relativePath)
        let parentDir = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: newSourceURL, to: destinationURL)
    }

    /// Cleans up any leftover staging files (e.g. after cancellation or crash)
    public func cleanupStagingDirectory() {
        if let stagingContents = try? fileManager.contentsOfDirectory(at: stagingDirectoryURL, includingPropertiesForKeys: nil) {
            for file in stagingContents {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    /// Calculates total storage size used by the archive folder
    public func totalArchiveSizeBytes() -> Int64 {
        guard let enumerator = fileManager.enumerator(at: baseArchiveURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}

public enum ArchiveStorageError: LocalizedError {
    case sourceNotFound(String)
    case commitFailed(String)
    case fileAlreadyMissing
    case cannotReadFile

    public var errorDescription: String? {
        switch self {
        case .sourceNotFound(let path):
            return "Source file not found or inaccessible at \(path)"
        case .commitFailed(let msg):
            return "Failed to commit file to permanent storage: \(msg)"
        case .fileAlreadyMissing:
            return "Physical file is already missing on disk."
        case .cannotReadFile:
            return "File exists but cannot be read."
        }
    }
}
