import Foundation
import SwiftData
import SwiftUI

@Model
public final class ArchiveItem {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var originalFileName: String
    public var fileExtension: String
    public var utiType: String
    public var fileCategoryRaw: String
    public var fileSizeBytes: Int64
    public var importDate: Date
    public var lastModifiedDate: Date
    public var relativeFilePath: String
    public var sha256Hash: String
    public var availabilityStatusRaw: String
    public var lastIntegrityCheckDate: Date?
    public var notes: String
    
    // Cached tag names string for fast text searching in predicate
    public var cachedTagNames: String

    @Relationship
    public var tags: [ArchiveTag]? = []

    public init(
        title: String,
        originalFileName: String,
        fileExtension: String,
        utiType: String,
        fileCategory: FileCategory,
        fileSizeBytes: Int64,
        importDate: Date = Date(),
        lastModifiedDate: Date = Date(),
        relativeFilePath: String,
        sha256Hash: String,
        availabilityStatus: ArchiveStatus = .available,
        notes: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.originalFileName = originalFileName
        self.fileExtension = fileExtension.lowercased()
        self.utiType = utiType
        self.fileCategoryRaw = fileCategory.rawValue
        self.fileSizeBytes = fileSizeBytes
        self.importDate = importDate
        self.lastModifiedDate = lastModifiedDate
        self.relativeFilePath = relativeFilePath
        self.sha256Hash = sha256Hash
        self.availabilityStatusRaw = availabilityStatus.rawValue
        self.lastIntegrityCheckDate = Date()
        self.notes = notes
        self.cachedTagNames = ""
        self.tags = []
    }

    public var fileCategory: FileCategory {
        get { FileCategory(rawValue: fileCategoryRaw) ?? .other }
        set { fileCategoryRaw = newValue.rawValue }
    }

    public var availabilityStatus: ArchiveStatus {
        get { ArchiveStatus(rawValue: availabilityStatusRaw) ?? .available }
        set { availabilityStatusRaw = newValue.rawValue }
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    public var safeTags: [ArchiveTag] {
        tags ?? []
    }

    public func updateCachedTags() {
        cachedTagNames = safeTags.map { $0.name }.joined(separator: ", ")
    }

    public func addTag(_ tag: ArchiveTag) {
        if tags == nil { tags = [] }
        if !(tags?.contains(where: { $0.id == tag.id }) ?? false) {
            tags?.append(tag)
            updateCachedTags()
        }
    }

    public func removeTag(_ tag: ArchiveTag) {
        tags?.removeAll(where: { $0.id == tag.id })
        updateCachedTags()
    }
}
