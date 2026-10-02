import Foundation
import SwiftUI
import SwiftData

public enum ArchiveSortOption: String, CaseIterable, Identifiable {
    case newestImport = "Newest First"
    case oldestImport = "Oldest First"
    case nameAscending = "Name (A → Z)"
    case nameDescending = "Name (Z → A)"
    case sizeLargest = "Largest First"
    case sizeSmallest = "Smallest First"

    public var id: String { rawValue }
}

public enum SizeFilterPreset: String, CaseIterable, Identifiable {
    case all = "Any Size"
    case small = "< 1 MB"
    case medium = "1 MB - 10 MB"
    case large = "> 10 MB"

    public var id: String { rawValue }
}

public enum DateFilterPreset: String, CaseIterable, Identifiable {
    case allTime = "All Time"
    case past24Hours = "Past 24 Hours"
    case past7Days = "Past 7 Days"
    case past30Days = "Past 30 Days"

    public var id: String { rawValue }
}

@MainActor
public final class ArchiveListViewModel: ObservableObject {
    @Published public var searchText: String = ""
    @Published public var selectedCategory: FileCategory = .all
    @Published public var selectedTag: ArchiveTag? = nil
    @Published public var selectedStatus: ArchiveStatus? = nil
    @Published public var sortOption: ArchiveSortOption = .newestImport
    @Published public var sizeFilter: SizeFilterPreset = .all
    @Published public var dateFilter: DateFilterPreset = .allTime

    // Multi-selection state
    @Published public var isSelectionMode: Bool = false
    @Published public var selectedItemIDs: Set<UUID> = []

    // Sheets and dialogs
    @Published public var isFilterSheetPresented: Bool = false
    @Published public var isFileImporterPresented: Bool = false
    @Published public var isTagAssignSheetPresented: Bool = false
    @Published public var itemPendingDeletion: ArchiveItem? = nil
    @Published public var showDeleteOptionsAlert: Bool = false
    @Published public var showBatchDeleteAlert: Bool = false

    public init() {}

    public var activeFilterCount: Int {
        var count = 0
        if selectedCategory != .all { count += 1 }
        if selectedTag != nil { count += 1 }
        if selectedStatus != nil { count += 1 }
        if sizeFilter != .all { count += 1 }
        if dateFilter != .allTime { count += 1 }
        return count
    }

    public func resetFilters() {
        selectedCategory = .all
        selectedTag = nil
        selectedStatus = nil
        sizeFilter = .all
        dateFilter = .allTime
        sortOption = .newestImport
        searchText = ""
    }

    /// Filters and sorts a given collection of ArchiveItem objects
    public func filterAndSort(items: [ArchiveItem]) -> [ArchiveItem] {
        var filtered = items

        // 1. Text Search across Title, Original Name, Extension, and Tag names
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmedQuery.isEmpty {
            filtered = filtered.filter { item in
                let titleMatch = item.title.lowercased().contains(trimmedQuery)
                let originalMatch = item.originalFileName.lowercased().contains(trimmedQuery)
                let extMatch = item.fileExtension.lowercased().contains(trimmedQuery)
                let tagsMatch = item.safeTags.contains { $0.name.lowercased().contains(trimmedQuery) }
                let notesMatch = item.notes.lowercased().contains(trimmedQuery)
                return titleMatch || originalMatch || extMatch || tagsMatch || notesMatch
            }
        }

        // 2. Category Filter
        if selectedCategory != .all {
            filtered = filtered.filter { $0.fileCategory == selectedCategory }
        }

        // 3. Tag Filter
        if let targetTag = selectedTag {
            filtered = filtered.filter { item in
                item.safeTags.contains(where: { $0.id == targetTag.id })
            }
        }

        // 4. Availability Status Filter
        if let targetStatus = selectedStatus {
            filtered = filtered.filter { $0.availabilityStatus == targetStatus }
        }

        // 5. Size Range Filter
        switch sizeFilter {
        case .all:
            break
        case .small:
            filtered = filtered.filter { $0.fileSizeBytes < 1_000_000 }
        case .medium:
            filtered = filtered.filter { $0.fileSizeBytes >= 1_000_000 && $0.fileSizeBytes <= 10_000_000 }
        case .large:
            filtered = filtered.filter { $0.fileSizeBytes > 10_000_000 }
        }

        // 6. Date Filter
        let now = Date()
        switch dateFilter {
        case .allTime:
            break
        case .past24Hours:
            let dayAgo = Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? now
            filtered = filtered.filter { $0.importDate >= dayAgo }
        case .past7Days:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            filtered = filtered.filter { $0.importDate >= weekAgo }
        case .past30Days:
            let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
            filtered = filtered.filter { $0.importDate >= monthAgo }
        }

        // 7. Sorting
        switch sortOption {
        case .newestImport:
            filtered.sort { $0.importDate > $1.importDate }
        case .oldestImport:
            filtered.sort { $0.importDate < $1.importDate }
        case .nameAscending:
            filtered.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .nameDescending:
            filtered.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        case .sizeLargest:
            filtered.sort { $0.fileSizeBytes > $1.fileSizeBytes }
        case .sizeSmallest:
            filtered.sort { $0.fileSizeBytes < $1.fileSizeBytes }
        }

        return filtered
    }

    /// Deletes an entry with user choice regarding physical file
    public func deleteItem(
        _ item: ArchiveItem,
        deletePhysicalFile: Bool,
        modelContext: ModelContext
    ) {
        if deletePhysicalFile {
            try? ArchiveStorageManager.shared.deletePhysicalFile(relativePath: item.relativeFilePath)
        }
        modelContext.delete(item)
        try? modelContext.save()
    }

    /// Batch delete selected items
    public func batchDelete(
        items: [ArchiveItem],
        deletePhysicalFiles: Bool,
        modelContext: ModelContext
    ) {
        let itemsToDelete = items.filter { selectedItemIDs.contains($0.id) }
        for item in itemsToDelete {
            if deletePhysicalFiles {
                try? ArchiveStorageManager.shared.deletePhysicalFile(relativePath: item.relativeFilePath)
            }
            modelContext.delete(item)
        }
        try? modelContext.save()
        selectedItemIDs.removeAll()
        isSelectionMode = false
    }
}
