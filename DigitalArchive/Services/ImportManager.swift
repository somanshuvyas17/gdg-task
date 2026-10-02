import Foundation
import SwiftData
import SwiftUI

public struct ImportResult: Sendable {
    public let successfulCount: Int
    public let failedCount: Int
    public let duplicateCount: Int
    public let errors: [String]
    public let importedItems: [UUID]
}

public struct ImportProgress: Sendable {
    public let totalCount: Int
    public let currentCompleted: Int
    public let currentFileName: String
    public let fractionCompleted: Double
}

public struct DuplicateMatch: Identifiable, Sendable {
    public let id: UUID
    public let incomingURL: URL
    public let incomingName: String
    public let existingItemTitle: String
    public let existingItemID: UUID
    public let sha256Hash: String

    public init(
        id: UUID = UUID(),
        incomingURL: URL,
        incomingName: String,
        existingItemTitle: String,
        existingItemID: UUID,
        sha256Hash: String
    ) {
        self.id = id
        self.incomingURL = incomingURL
        self.incomingName = incomingName
        self.existingItemTitle = existingItemTitle
        self.existingItemID = existingItemID
        self.sha256Hash = sha256Hash
    }
}

@MainActor
public final class ImportManager: ObservableObject {
    public static let shared = ImportManager()

    @Published public var isImporting: Bool = false
    @Published public var currentProgress: ImportProgress? = nil
    @Published public var lastResult: ImportResult? = nil
    @Published public var detectedDuplicate: DuplicateMatch? = nil

    private let storageManager = ArchiveStorageManager.shared
    private let metadataExtractor = FileMetadataExtractor.shared
    private var isCancelled: Bool = false

    public init() {}

    public func cancelCurrentImport() {
        isCancelled = true
    }

    /// Performs multi-file atomic import into SwiftData context
    public func importFiles(
        from urls: [URL],
        modelContext: ModelContext,
        allowDuplicates: Bool = false,
        tagsToAssign: [ArchiveTag] = []
    ) async -> ImportResult {
        // Case 25: Request background execution from iOS so imports survive app switching / backgrounding
        var bgTaskID: UIBackgroundTaskIdentifier = .invalid
        bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "DigitalArchiveImport") {
            UIApplication.shared.endBackgroundTask(bgTaskID)
            bgTaskID = .invalid
        }

        defer {
            if bgTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(bgTaskID)
                bgTaskID = .invalid
            }
            isImporting = false
            isCancelled = false
            currentProgress = nil
        }

        isImporting = true
        var successfulIDs: [UUID] = []
        var errors: [String] = []
        var duplicateCount = 0

        let total = urls.count

        for (index, url) in urls.enumerated() {
            if isCancelled || Task.isCancelled {
                errors.append("Import cancelled by user after processing \(index) files.")
                break
            }

            let fileName = url.lastPathComponent
            currentProgress = ImportProgress(
                totalCount: total,
                currentCompleted: index,
                currentFileName: fileName,
                fractionCompleted: Double(index) / Double(total)
            )

            // Step 1: Stage incoming file
            var stagingURL: URL?
            var committedRelativePath: String?

            do {
                let stageResult = try storageManager.stageIncomingFile(from: url)
                stagingURL = stageResult.stagingURL

                // Step 2: Extract metadata and compute SHA256 asynchronously
                let metadata = try await metadataExtractor.extractMetadata(
                    from: stageResult.stagingURL,
                    originalName: stageResult.originalName
                )

                // Step 3: Check for duplicates by cryptographic SHA-256 hash
                let hash = metadata.sha256Hash
                var fetchDescriptor = FetchDescriptor<ArchiveItem>(
                    predicate: #Predicate<ArchiveItem> { item in
                        item.sha256Hash == hash
                    }
                )
                fetchDescriptor.fetchLimit = 1
                let existingWithSameHash = try? modelContext.fetch(fetchDescriptor)

                if let existing = existingWithSameHash, let firstMatch = existing.first {
                    duplicateCount += 1
                    if !allowDuplicates {
                        // Clean up staging file
                        if let sURL = stagingURL {
                            try? FileManager.default.removeItem(at: sURL)
                        }
                        // Set detectedDuplicate for interactive prompt on single-file import
                        if total == 1 {
                            detectedDuplicate = DuplicateMatch(
                                incomingURL: url,
                                incomingName: fileName,
                                existingItemTitle: firstMatch.title,
                                existingItemID: firstMatch.id,
                                sha256Hash: hash
                            )
                        } else {
                            errors.append("Skipped duplicate file: '\(fileName)' (matches '\(firstMatch.title)')")
                        }
                        continue
                    }
                }

                // Step 4: Commit staged file to permanent storage
                let commitResult = try storageManager.commitStagedFile(
                    stagingURL: stageResult.stagingURL,
                    fileExtension: stageResult.fileExtension
                )
                committedRelativePath = commitResult.relativePath

                // Step 5: Save thumbnail if available
                if let thumbData = metadata.thumbnailData {
                    let thumbURL = storageManager.thumbnailsDirectoryURL.appendingPathComponent("\(commitResult.relativePath.replacingOccurrences(of: "Files/", with: "")).thumb")
                    try? thumbData.write(to: thumbURL)
                }

                // Step 6: Create and persist SwiftData record
                let cleanTitle = (metadata.originalFileName as NSString).deletingPathExtension
                let newItem = ArchiveItem(
                    title: cleanTitle.isEmpty ? metadata.originalFileName : cleanTitle,
                    originalFileName: metadata.originalFileName,
                    fileExtension: metadata.fileExtension,
                    utiType: metadata.utiType,
                    fileCategory: metadata.fileCategory,
                    fileSizeBytes: metadata.fileSizeBytes,
                    importDate: Date(),
                    lastModifiedDate: metadata.lastModifiedDate,
                    relativeFilePath: commitResult.relativePath,
                    sha256Hash: metadata.sha256Hash,
                    availabilityStatus: .available,
                    notes: ""
                )

                // Add specified tags
                for tag in tagsToAssign {
                    newItem.addTag(tag)
                }

                modelContext.insert(newItem)
                try modelContext.save()

                successfulIDs.append(newItem.id)

            } catch {
                // Consistency rollback: remove staging or committed file to avoid orphaned files
                if let sURL = stagingURL {
                    try? FileManager.default.removeItem(at: sURL)
                }
                if let relPath = committedRelativePath {
                    try? storageManager.deletePhysicalFile(relativePath: relPath)
                }
                errors.append("Failed to import '\(fileName)': \(error.localizedDescription)")
            }
        }

        // Clean any leftover staging artifacts
        storageManager.cleanupStagingDirectory()

        let result = ImportResult(
            successfulCount: successfulIDs.count,
            failedCount: errors.count,
            duplicateCount: duplicateCount,
            errors: errors,
            importedItems: successfulIDs
        )

        lastResult = result
        isImporting = false
        currentProgress = nil

        return result
    }
}
