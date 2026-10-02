import Foundation
import SwiftData
import SwiftUI

public struct IntegrityReport: Sendable {
    public let totalChecked: Int
    public let availableCount: Int
    public let missingCount: Int
    public let unreadableCount: Int
    public let totalDiskSizeBytes: Int64
    public let scanDate: Date

    public var healthPercentage: Double {
        guard totalChecked > 0 else { return 100.0 }
        return (Double(availableCount) / Double(totalChecked)) * 100.0
    }
}

@MainActor
public final class IntegrityScanner: ObservableObject {
    public static let shared = IntegrityScanner()

    @Published public var isScanning: Bool = false
    @Published public var progress: Double = 0.0
    @Published public var lastReport: IntegrityReport? = nil

    private let storageManager = ArchiveStorageManager.shared

    public init() {}

    /// Performs complete archive integrity scan across all records
    public func scanArchive(modelContext: ModelContext) async -> IntegrityReport {
        isScanning = true
        progress = 0.0

        let descriptor = FetchDescriptor<ArchiveItem>()
        guard let items = try? modelContext.fetch(descriptor) else {
            isScanning = false
            return IntegrityReport(totalChecked: 0, availableCount: 0, missingCount: 0, unreadableCount: 0, totalDiskSizeBytes: 0, scanDate: Date())
        }

        var available = 0
        var missing = 0
        var unreadable = 0
        let total = items.count

        for (index, item) in items.enumerated() {
            let status = storageManager.checkFileStatus(for: item.relativeFilePath)
            item.availabilityStatus = status
            item.lastIntegrityCheckDate = Date()

            switch status {
            case .available:
                available += 1
            case .missing:
                missing += 1
            case .unreadable:
                unreadable += 1
            }

            if total > 0 {
                progress = Double(index + 1) / Double(total)
            }
        }

        try? modelContext.save()

        let totalDiskBytes = storageManager.totalArchiveSizeBytes()

        let report = IntegrityReport(
            totalChecked: total,
            availableCount: available,
            missingCount: missing,
            unreadableCount: unreadable,
            totalDiskSizeBytes: totalDiskBytes,
            scanDate: Date()
        )

        lastReport = report
        isScanning = false
        return report
    }

    /// Checks and updates status of a single item
    public func verifySingleItem(_ item: ArchiveItem, modelContext: ModelContext) -> ArchiveStatus {
        let status = storageManager.checkFileStatus(for: item.relativeFilePath)
        item.availabilityStatus = status
        item.lastIntegrityCheckDate = Date()
        try? modelContext.save()
        return status
    }
}
