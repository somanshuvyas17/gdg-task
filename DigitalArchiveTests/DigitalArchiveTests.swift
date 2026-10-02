import XCTest
import SwiftData
@testable import DigitalArchive

@MainActor
final class DigitalArchiveTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let schema = Schema([
            ArchiveItem.self,
            ArchiveTag.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)

        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        modelContainer = nil
        modelContext = nil
        try super.tearDownWithError()
    }

    // Helper to create sample file
    private func createTestFile(named name: String, content: String) throws -> URL {
        let fileURL = tempDirectory.appendingPathComponent(name)
        try content.data(using: .utf8)?.write(to: fileURL)
        return fileURL
    }

    // Test 1: File import, metadata extraction & physical storage
    func testAtomicImportAndMetadataExtraction() async throws {
        let testContent = "Hello Digital Archive! Testing atomic import and SHA-256."
        let sourceURL = try createTestFile(named: "test_document.txt", content: testContent)

        let result = await ImportManager.shared.importFiles(
            from: [sourceURL],
            modelContext: modelContext,
            allowDuplicates: true
        )

        XCTAssertEqual(result.successfulCount, 1)
        XCTAssertEqual(result.failedCount, 0)

        // Query persisted item
        let descriptor = FetchDescriptor<ArchiveItem>()
        let items = try modelContext.fetch(descriptor)
        XCTAssertEqual(items.count, 1)

        let item = items[0]
        XCTAssertEqual(item.originalFileName, "test_document.txt")
        XCTAssertEqual(item.fileExtension, "txt")
        XCTAssertEqual(item.fileCategory, .document)
        XCTAssertEqual(item.availabilityStatus, .available)
        XCTAssertFalse(item.sha256Hash.isEmpty)
        XCTAssertGreaterThan(item.fileSizeBytes, 0)

        // Verify physical file exists in permanent archive location
        let physicalURL = ArchiveStorageManager.shared.fileURL(for: item.relativeFilePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: physicalURL.path))
    }

    // Test 2: External deletion resilience (Task 5)
    func testMissingFileHandlingAndIntegrityScan() async throws {
        let sourceURL = try createTestFile(named: "sample_report.pdf", content: "PDF Sample Data")
        _ = await ImportManager.shared.importFiles(from: [sourceURL], modelContext: modelContext)

        let descriptor = FetchDescriptor<ArchiveItem>()
        guard let item = try modelContext.fetch(descriptor).first else {
            XCTFail("Item not found")
            return
        }

        XCTAssertEqual(item.availabilityStatus, .available)

        // Simulate external deletion
        try ArchiveStorageManager.shared.simulateExternalDeletion(relativePath: item.relativeFilePath)

        // Run integrity scan
        let report = await IntegrityScanner.shared.scanArchive(modelContext: modelContext)

        XCTAssertEqual(report.missingCount, 1)
        XCTAssertEqual(item.availabilityStatus, .missing)

        // Verify metadata is preserved despite physical file deletion!
        XCTAssertEqual(item.originalFileName, "sample_report.pdf")
        XCTAssertFalse(item.sha256Hash.isEmpty)

        // Test Relinking
        let replacementURL = try createTestFile(named: "replacement_report.pdf", content: "Restored PDF Sample Data")
        try ArchiveStorageManager.shared.relinkFile(relativePath: item.relativeFilePath, newSourceURL: replacementURL)

        let statusAfterRelink = IntegrityScanner.shared.verifySingleItem(item, modelContext: modelContext)
        XCTAssertEqual(statusAfterRelink, .available)
        XCTAssertEqual(item.availabilityStatus, .available)
    }

    // Test 3: Clear definition of physical file vs record removal (Task 3)
    func testDeleteRecordOnlyVsDeleteWithPhysicalFile() async throws {
        let fileA = try createTestFile(named: "docA.txt", content: "Content A")
        let fileB = try createTestFile(named: "docB.txt", content: "Content B")

        _ = await ImportManager.shared.importFiles(from: [fileA, fileB], modelContext: modelContext)

        var items = try modelContext.fetch(FetchDescriptor<ArchiveItem>())
        XCTAssertEqual(items.count, 2)

        let itemA = items.first(where: { $0.originalFileName == "docA.txt" })!
        let itemB = items.first(where: { $0.originalFileName == "docB.txt" })!

        let pathA = itemA.relativeFilePath
        let pathB = itemB.relativeFilePath

        let listVM = ArchiveListViewModel()

        // 1. Delete Item A WITHOUT deleting physical file
        listVM.deleteItem(itemA, deletePhysicalFile: false, modelContext: modelContext)

        items = try modelContext.fetch(FetchDescriptor<ArchiveItem>())
        XCTAssertEqual(items.count, 1)
        // Physical file A should STILL exist on disk!
        XCTAssertTrue(FileManager.default.fileExists(atPath: ArchiveStorageManager.shared.fileURL(for: pathA).path))

        // 2. Delete Item B AND delete physical file
        listVM.deleteItem(itemB, deletePhysicalFile: true, modelContext: modelContext)

        items = try modelContext.fetch(FetchDescriptor<ArchiveItem>())
        XCTAssertEqual(items.count, 0)
        // Physical file B should be REMOVED from disk!
        XCTAssertFalse(FileManager.default.fileExists(atPath: ArchiveStorageManager.shared.fileURL(for: pathB).path))

        // Clean up remaining file A
        try? ArchiveStorageManager.shared.deletePhysicalFile(relativePath: pathA)
    }

    // Test 4: Tag organization and relationships
    func testTagAssignmentAndRemoval() throws {
        let item = ArchiveItem(
            title: "Test Receipt",
            originalFileName: "receipt.png",
            fileExtension: "png",
            utiType: "public.png",
            fileCategory: .image,
            fileSizeBytes: 1024,
            relativeFilePath: "Files/receipt.png",
            sha256Hash: "abcdef123456"
        )
        modelContext.insert(item)

        let tag1 = ArchiveTag(name: "Finance", colorHex: "#007AFF")
        let tag2 = ArchiveTag(name: "2026", colorHex: "#34C759")
        modelContext.insert(tag1)
        modelContext.insert(tag2)

        item.addTag(tag1)
        item.addTag(tag2)
        try modelContext.save()

        XCTAssertEqual(item.safeTags.count, 2)
        XCTAssertTrue(item.safeTags.contains(where: { $0.name == "Finance" }))

        item.removeTag(tag1)
        try modelContext.save()

        XCTAssertEqual(item.safeTags.count, 1)
        XCTAssertFalse(item.safeTags.contains(where: { $0.name == "Finance" }))
        XCTAssertTrue(item.safeTags.contains(where: { $0.name == "2026" }))
    }

    // Test 5: Search and Multi-Filtering
    func testSearchAndFilteringLogic() throws {
        let item1 = ArchiveItem(
            title: "Project Alpha Plan",
            originalFileName: "alpha_plan.pdf",
            fileExtension: "pdf",
            utiType: "com.adobe.pdf",
            fileCategory: .pdf,
            fileSizeBytes: 500_000,
            relativeFilePath: "Files/1.pdf",
            sha256Hash: "hash1"
        )
        let item2 = ArchiveItem(
            title: "Company Logo High Res",
            originalFileName: "logo.png",
            fileExtension: "png",
            utiType: "public.png",
            fileCategory: .image,
            fileSizeBytes: 5_000_000,
            relativeFilePath: "Files/2.png",
            sha256Hash: "hash2"
        )
        let item3 = ArchiveItem(
            title: "Meeting Summary Notes",
            originalFileName: "notes.txt",
            fileExtension: "txt",
            utiType: "public.plain-text",
            fileCategory: .document,
            fileSizeBytes: 10_000,
            relativeFilePath: "Files/3.txt",
            sha256Hash: "hash3"
        )

        let tag = ArchiveTag(name: "Important")
        item1.addTag(tag)

        let allItems = [item1, item2, item3]
        let vm = ArchiveListViewModel()

        // Search by keyword "logo"
        vm.searchText = "Logo"
        var results = vm.filterAndSort(items: allItems)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Company Logo High Res")

        // Search by tag
        vm.searchText = "Important"
        results = vm.filterAndSort(items: allItems)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Project Alpha Plan")

        // Filter by Category: Image
        vm.searchText = ""
        vm.selectedCategory = .image
        results = vm.filterAndSort(items: allItems)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.fileCategory, .image)

        // Filter by Size Preset (< 1 MB)
        vm.selectedCategory = .all
        vm.sizeFilter = .small
        results = vm.filterAndSort(items: allItems)
        XCTAssertEqual(results.count, 2) // item1 (500KB) and item3 (10KB)
    }

    // Test 6: Duplicate detection using SHA-256
    func testDuplicateDetectionBySHA256() async throws {
        let identicalContent = "Exact duplicate content to test SHA-256 detection."
        let file1 = try createTestFile(named: "original.txt", content: identicalContent)
        let file2 = try createTestFile(named: "duplicate_copy.txt", content: identicalContent)

        // First import
        _ = await ImportManager.shared.importFiles(from: [file1], modelContext: modelContext)

        // Second import with allowDuplicates = false
        let secondResult = await ImportManager.shared.importFiles(
            from: [file2],
            modelContext: modelContext,
            allowDuplicates: false
        )

        XCTAssertEqual(secondResult.duplicateCount, 1)
        XCTAssertEqual(secondResult.successfulCount, 0)
    }

    // Test 7: Tag normalization and deduplication
    func testTagDeduplicationAndNormalization() throws {
        // Insert duplicate tags with varying case and whitespace
        let tag1 = ArchiveTag(name: "Project 2026", colorHex: "#007AFF")
        let tag2 = ArchiveTag(name: "  project 2026  ", colorHex: "#34C759")
        let tag3 = ArchiveTag(name: "PROJECT 2026", colorHex: "#FF9500")
        let tag4 = ArchiveTag(name: "Personal", colorHex: "#AF52DE")

        modelContext.insert(tag1)
        modelContext.insert(tag2)
        modelContext.insert(tag3)
        modelContext.insert(tag4)
        try modelContext.save()

        // Associate an item with tag2
        let item = ArchiveItem(
            title: "Test File",
            originalFileName: "file.txt",
            fileExtension: "txt",
            utiType: "public.text",
            fileCategory: .document,
            fileSizeBytes: 100,
            relativeFilePath: "Files/test.txt",
            sha256Hash: "testhash"
        )
        modelContext.insert(item)
        item.addTag(tag2)
        try modelContext.save()

        // Run deduplication
        ArchiveTag.deduplicate(in: modelContext)

        let allTags = try modelContext.fetch(FetchDescriptor<ArchiveTag>())
        let projectTags = allTags.filter { $0.name.localizedCaseInsensitiveCompare("Project 2026") == .orderedSame }

        XCTAssertEqual(projectTags.count, 1, "Duplicate project tags should be merged into exactly 1 tag")
        XCTAssertEqual(allTags.count, 2, "Should only have Project 2026 and Personal")

        // Verify the item retained the tag relationship on the merged primary tag
        if let remainingProjectTag = projectTags.first {
            XCTAssertTrue(item.safeTags.contains(where: { $0.id == remainingProjectTag.id }))
        }
    }

    // Test 8: Import Cancellation (Edge Case 1)
    func testImportCancellation() async throws {
        let file1 = try createTestFile(named: "file1.txt", content: "Content 1")
        let file2 = try createTestFile(named: "file2.txt", content: "Content 2")

        // Trigger cancellation immediately
        ImportManager.shared.cancelCurrentImport()

        let result = await ImportManager.shared.importFiles(
            from: [file1, file2],
            modelContext: modelContext,
            allowDuplicates: false
        )

        // Staging directory should be clean
        let stagingFiles = try? FileManager.default.contentsOfDirectory(at: ArchiveStorageManager.shared.stagingDirectoryURL, includingPropertiesForKeys: nil)
        XCTAssertEqual(stagingFiles?.count ?? 0, 0, "Staging directory must be cleaned up on cancel")
        XCTAssertTrue(result.errors.contains(where: { $0.contains("cancelled") }))
    }

    // Test 9: Partial Import Failure (Edge Case 2)
    func testPartialImportFailure() async throws {
        let validFile = try createTestFile(named: "valid.txt", content: "Valid file content")
        let nonExistentFile = tempDirectory.appendingPathComponent("does_not_exist_\(UUID().uuidString).txt")

        let result = await ImportManager.shared.importFiles(
            from: [validFile, nonExistentFile],
            modelContext: modelContext,
            allowDuplicates: false
        )

        XCTAssertEqual(result.successfulCount, 1)
        XCTAssertEqual(result.failedCount, 1)

        // Ensure database contains only the valid file
        let items = try modelContext.fetch(FetchDescriptor<ArchiveItem>())
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.originalFileName, "valid.txt")
    }

    // Test 10: Zero-byte file import (Edge Case 17)
    func testZeroByteFileImport() async throws {
        let emptyFile = try createTestFile(named: "empty.pdf", content: "")

        let result = await ImportManager.shared.importFiles(
            from: [emptyFile],
            modelContext: modelContext,
            allowDuplicates: false
        )

        XCTAssertEqual(result.successfulCount, 1)
        let items = try modelContext.fetch(FetchDescriptor<ArchiveItem>())
        guard let item = items.first(where: { $0.originalFileName == "empty.pdf" }) else {
            XCTFail("Zero-byte file should be archived")
            return
        }

        XCTAssertEqual(item.fileSizeBytes, 0)
        XCTAssertEqual(item.formattedSize, "Zero KB")
        XCTAssertFalse(item.sha256Hash.isEmpty, "Zero-byte file must have valid SHA-256")
    }

    // Test 11: Same filename with different content (Edge Case 9)
    func testSameFilenameDifferentContent() async throws {
        let fileA = try createTestFile(named: "Report.pdf", content: "Content Version A")
        let tempDir2 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir2, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir2) }

        let fileB = tempDir2.appendingPathComponent("Report.pdf")
        try "Content Version B - Different".data(using: .utf8)?.write(to: fileB)

        let resultA = await ImportManager.shared.importFiles(from: [fileA], modelContext: modelContext, allowDuplicates: false)
        let resultB = await ImportManager.shared.importFiles(from: [fileB], modelContext: modelContext, allowDuplicates: false)

        XCTAssertEqual(resultA.successfulCount, 1)
        XCTAssertEqual(resultB.successfulCount, 1, "Different content must not be rejected as duplicate")

        let items = try modelContext.fetch(FetchDescriptor<ArchiveItem>())
        let reports = items.filter { $0.originalFileName == "Report.pdf" }
        XCTAssertEqual(reports.count, 2)
        XCTAssertNotEqual(reports[0].sha256Hash, reports[1].sha256Hash)
    }

    // Test 12: Unicode and extremely long filenames (Edge Cases 14 & 15)
    func testLongAndUnicodeFilenames() async throws {
        let longName = "This_is_an_extremely_long_filename_that_should_not_break_the_user_interface_2026_test_archive_specification.pdf"
        let unicodeName = "Résumé – Final_合同_₹500.pdf"

        let file1 = try createTestFile(named: longName, content: "Long filename test")
        let file2 = try createTestFile(named: unicodeName, content: "Unicode filename test")

        let result = await ImportManager.shared.importFiles(from: [file1, file2], modelContext: modelContext, allowDuplicates: false)
        XCTAssertEqual(result.successfulCount, 2)

        let items = try modelContext.fetch(FetchDescriptor<ArchiveItem>())
        XCTAssertTrue(items.contains(where: { $0.originalFileName == longName }))
        XCTAssertTrue(items.contains(where: { $0.originalFileName == unicodeName }))
    }

    // Test 13: Deleting a tag preserves associated files (Edge Case 19)
    func testDeleteTagPreservesFiles() throws {
        let tag = ArchiveTag(name: "TemporaryTag", colorHex: "#FF0000")
        modelContext.insert(tag)

        let item = ArchiveItem(
            title: "ImportantDoc",
            originalFileName: "ImportantDoc.pdf",
            fileExtension: "pdf",
            utiType: "com.adobe.pdf",
            fileCategory: .pdf,
            fileSizeBytes: 2048,
            relativeFilePath: "Files/ImportantDoc.pdf",
            sha256Hash: "dochash"
        )
        modelContext.insert(item)
        item.addTag(tag)
        try modelContext.save()

        XCTAssertTrue(item.safeTags.contains(where: { $0.name == "TemporaryTag" }))

        // Delete tag
        item.removeTag(tag)
        modelContext.delete(tag)
        try modelContext.save()

        // File must remain in archive
        let remainingItems = try modelContext.fetch(FetchDescriptor<ArchiveItem>())
        XCTAssertTrue(remainingItems.contains(where: { $0.id == item.id }), "File must remain in archive when its tag is deleted")
        XCTAssertFalse(item.safeTags.contains(where: { $0.name == "TemporaryTag" }))
    }
}
