import Foundation
import UIKit
import PDFKit
import SwiftData

@MainActor
public final class SampleDataGenerator {
    public static let shared = SampleDataGenerator()

    private let importManager = ImportManager.shared
    private let fileManager = FileManager.default

    public init() {}

    /// Generates diverse, categorized sample files (PDFs, Images, Documents, Audio, Other)
    /// and imports them with realistic tag associations.
    public func generateAndImportSampleData(modelContext: ModelContext) async throws {
        // Step 1: Clean and deduplicate tags before setup
        ArchiveTag.deduplicate(in: modelContext)

        // Step 2: Ensure distinct taxonomy tags exist with vibrant colors
        let tagWork = ArchiveTag.findOrCreate(name: "Work", colorHex: "#007AFF", in: modelContext)
        let tagPersonal = ArchiveTag.findOrCreate(name: "Personal", colorHex: "#34C759", in: modelContext)
        let tagReceipts = ArchiveTag.findOrCreate(name: "Receipts", colorHex: "#FF9500", in: modelContext)
        let tagProject = ArchiveTag.findOrCreate(name: "Project 2026", colorHex: "#AF52DE", in: modelContext)
        let tagCollege = ArchiveTag.findOrCreate(name: "College", colorHex: "#FF3B30", in: modelContext)
        let tagFinance = ArchiveTag.findOrCreate(name: "Finance", colorHex: "#5856D6", in: modelContext)
        let tagDesign = ArchiveTag.findOrCreate(name: "Design", colorHex: "#FF2D55", in: modelContext)

        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("SampleArchiveSource_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // ==========================================
        // CATEGORY 1: PDFs (doc.richtext.fill / Red)
        // ==========================================

        // PDF 1: Academic / College
        let pdf1URL = tempDir.appendingPathComponent("DSA_Notes_Trees_Graphs.pdf")
        let pdf1Data = createSamplePDF(
            title: "Data Structures: Trees & Graph Algorithms",
            author: "Computer Science Dept",
            categoryTag: "ACADEMIC NOTES",
            content: """
            1. Binary Search Trees (BST):
            • In-order traversal yields keys in non-decreasing sorted order.
            • Search, Insertion, Deletion: Average O(log N), Worst Case O(N).
            • AVL / Red-Black Tree rotation balancing guarantees O(log N) depth.

            2. Graph Representation & Traversal:
            • Adjacency List: Space efficient O(V + E) for sparse graphs.
            • BFS (Breadth-First Search): Computes shortest path in unweighted graphs using a FIFO queue.
            • DFS (Depth-First Search): Topological sorting and cycle detection via recursion/stack.
            • Dijkstra's Algorithm: Single-source shortest path using a Min-Priority Queue in O((V + E) log V).
            """
        )
        try pdf1Data.write(to: pdf1URL)
        await importSingleFile(url: pdf1URL, tags: [tagCollege, tagProject], modelContext: modelContext)

        // PDF 2: Enterprise Financial Audit
        let pdf2URL = tempDir.appendingPathComponent("Q3_Financial_Audit_Report.pdf")
        let pdf2Data = createSamplePDF(
            title: "Q3 2026 Financial Audit & Compliance",
            author: "Enterprise Internal Audit",
            categoryTag: "CONFIDENTIAL",
            content: """
            EXECUTIVE AUDIT SUMMARY:
            This document confirms compliance and internal control adherence across operational units.

            Key Findings:
            • 100% On-device cryptographic verification using SHA-256 streaming hashing.
            • Storage efficiency: Zero-copy sandboxing with relative path persistence.
            • Operational compliance: Zero unhandled missing-file exceptions during stress tests.
            • Cash reserves and capital allocation approved for FY2026 Q4 expansion.

            CONCLUSION:
            Unqualified audit opinion issued. Systems meet enterprise digital asset standards.
            """
        )
        try pdf2Data.write(to: pdf2URL)
        await importSingleFile(url: pdf2URL, tags: [tagWork, tagFinance], modelContext: modelContext)

        // PDF 3: Personal Legal / Tenancy
        let pdf3URL = tempDir.appendingPathComponent("Apartment_Lease_Agreement.pdf")
        let pdf3Data = createSamplePDF(
            title: "Residential Tenancy & Lease Agreement",
            author: "Property Management Office",
            categoryTag: "PERSONAL LEGAL",
            content: """
            TENANCY TERMS & CONDITIONS:
            1. Property: Suite 402, Highline Residency.
            2. Term: 12-Month Fixed Lease beginning October 1, 2026.
            3. Rent: Payable on the 1st day of each calendar month.
            4. Utilities & Services: High-speed fiber internet and maintenance included.
            5. Security Deposit: Fully refundable upon satisfactory move-out inspection.
            """
        )
        try pdf3Data.write(to: pdf3URL)
        await importSingleFile(url: pdf3URL, tags: [tagPersonal, tagFinance], modelContext: modelContext)

        // PDF 4: Product Architecture Spec
        let pdf4URL = tempDir.appendingPathComponent("System_Architecture_Spec.pdf")
        let pdf4Data = createSamplePDF(
            title: "Mobile Archive Architecture Specification",
            author: "Engineering Lead",
            categoryTag: "TECHNICAL SPEC",
            content: """
            CORE ARCHITECTURAL PILLARS:
            1. Declarative UI: Pure SwiftUI with MVVM presentation layer.
            2. Local Persistence: SwiftData backed by SQLite; zero server dependency.
            3. Resilient Storage: Relative path sandboxing resolving dynamically at runtime.
            4. Integrity Engine: 64 KB streaming SHA-256 duplicate detection and unreadable file guard.
            """
        )
        try pdf4Data.write(to: pdf4URL)
        await importSingleFile(url: pdf4URL, tags: [tagWork, tagProject], modelContext: modelContext)

        // ==========================================
        // CATEGORY 2: Images (photo.fill / Purple)
        // ==========================================

        // Image 1: System Architecture Blueprint
        let img1URL = tempDir.appendingPathComponent("Cloud_Architecture_Blueprint.png")
        if let data = createSampleImage(
            title: "Cloud Architecture Blueprint",
            subtitle: "SwiftUI • SwiftData • Sandbox Filesystem • SHA-256",
            badge: "SYSTEM TOPOLOGY",
            color: UIColor.systemIndigo
        ) {
            try data.write(to: img1URL)
            await importSingleFile(url: img1URL, tags: [tagWork, tagProject], modelContext: modelContext)
        }

        // Image 2: Keynote Event Photo
        let img2URL = tempDir.appendingPathComponent("GDG_Tech_Summit_Keynote.png")
        if let data = createSampleImage(
            title: "GDG Tech Summit 2026",
            subtitle: "Keynote: Advanced Mobile Architectures & On-Device Storage",
            badge: "COMMUNITY EVENT",
            color: UIColor.systemTeal
        ) {
            try data.write(to: img2URL)
            await importSingleFile(url: img2URL, tags: [tagCollege, tagPersonal], modelContext: modelContext)
        }

        // Image 3: Store Expense Receipt
        let img3URL = tempDir.appendingPathComponent("Blue_Bottle_Coffee_Receipt.png")
        if let data = createSampleImage(
            title: "Blue Bottle Coffee • Receipt",
            subtitle: "Items: Cold Brew (2) • Pastry (1) • Total: $18.50",
            badge: "EXPENSE RECEIPT",
            color: UIColor.systemOrange
        ) {
            try data.write(to: img3URL)
            await importSingleFile(url: img3URL, tags: [tagReceipts, tagFinance], modelContext: modelContext)
        }

        // Image 4: UI/UX Wireframe Design
        let img4URL = tempDir.appendingPathComponent("Mobile_App_Design_Mockup.png")
        if let data = createSampleImage(
            title: "Mobile App Wireframe Mockup",
            subtitle: "Design Tokens • Grid System • Dark Mode Palette",
            badge: "UI/UX DESIGN",
            color: UIColor.systemPink
        ) {
            try data.write(to: img4URL)
            await importSingleFile(url: img4URL, tags: [tagDesign, tagProject], modelContext: modelContext)
        }

        // ==========================================
        // CATEGORY 3: Documents (doc.text.fill / Blue)
        // ==========================================

        // Doc 1: Markdown Notes
        let doc1URL = tempDir.appendingPathComponent("Meeting_Action_Items.md")
        let doc1Content = """
        # Sprint Planning & Architecture Review
        Date: October 2026 | Sprint 42

        ## Completed Deliverables
        - [x] Implemented relative path resolution for iOS sandbox UUID resilience.
        - [x] Integrated streaming SHA-256 cryptographic duplicate detection.
        - [x] Built integrity audit scanner for missing & unreadable files.
        - [x] Unified tag normalization and case-insensitive deduplication.

        ## Next Sprint Goals
        - [ ] Automated sync with on-device backup storage.
        - [ ] Rich text file inline editor.
        """
        try doc1Content.data(using: .utf8)?.write(to: doc1URL)
        await importSingleFile(url: doc1URL, tags: [tagWork, tagProject], modelContext: modelContext)

        // Doc 2: JSON Schema
        let doc2URL = tempDir.appendingPathComponent("Archive_Metadata_Schema.json")
        let doc2Content = """
        {
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "title": "ArchiveRecord",
          "type": "object",
          "properties": {
            "id": { "type": "string", "format": "uuid" },
            "title": { "type": "string" },
            "relativeFilePath": { "type": "string", "example": "Files/UUID.pdf" },
            "sha256Hash": { "type": "string", "pattern": "^[a-f0-9]{64}$" },
            "fileCategory": { "type": "string", "enum": ["pdf", "image", "document", "audio", "other"] },
            "availabilityStatus": { "type": "string", "enum": ["available", "missing", "unreadable"] }
          },
          "required": ["id", "title", "relativeFilePath", "sha256Hash", "fileCategory"]
        }
        """
        try doc2Content.data(using: .utf8)?.write(to: doc2URL)
        await importSingleFile(url: doc2URL, tags: [tagWork, tagProject], modelContext: modelContext)

        // Doc 3: CSV Spreadsheet
        let doc3URL = tempDir.appendingPathComponent("Expense_Report_2026.csv")
        let doc3Content = """
        Date,Merchant,Category,Amount,PaymentMethod,Status
        2026-09-12,Apple Developer Program,Software,$99.00,Corporate Card,Approved
        2026-09-18,Cloudflare Inc,Infrastructure,$20.00,Corporate Card,Approved
        2026-09-24,Blue Bottle Coffee,Meals,$18.50,Personal Card,Reimbursed
        2026-09-30,Hardware Store,Lab Equipment,$142.75,Corporate Card,Pending
        """
        try doc3Content.data(using: .utf8)?.write(to: doc3URL)
        await importSingleFile(url: doc3URL, tags: [tagReceipts, tagFinance], modelContext: modelContext)

        // Doc 4: College Course Syllabus
        let doc4URL = tempDir.appendingPathComponent("Campus_Syllabus_Fall2026.txt")
        let doc4Content = """
        SRM UNIVERSITY - DEPARTMENT OF COMPUTER SCIENCE
        COURSE: CS304 - ADVANCED MOBILE SYSTEMS DESIGN
        SEMESTER: FALL 2026

        Course Schedule:
        Week 1-3: Mobile OS Architecture, Sandbox Model & Process Lifecycles
        Week 4-6: Declarative UI Programming & State Management Patterns
        Week 7-9: On-Device Persistence Engines (SQLite, SwiftData, CoreData)
        Week 10-12: Concurrency, Background Execution & Cryptographic Hashing
        Week 13-14: Final Capstone Project Demonstrations & Peer Reviews

        Grading Scheme:
        • Practical Lab Assignments: 30%
        • Midterm Assessment: 20%
        • Architecture Capstone Project: 40%
        • Class Participation: 10%
        """
        try doc4Content.data(using: .utf8)?.write(to: doc4URL)
        await importSingleFile(url: doc4URL, tags: [tagCollege], modelContext: modelContext)

        // Doc 5: SQL Database Migration Script
        let doc5URL = tempDir.appendingPathComponent("Database_Migration_v2.sql")
        let doc5Content = """
        -- Digital Archive Database Migration Script v2.0
        BEGIN TRANSACTION;

        CREATE TABLE IF NOT EXISTS ArchiveItem (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            originalFileName TEXT NOT NULL,
            fileExtension TEXT NOT NULL,
            fileSizeBytes INTEGER NOT NULL,
            importDate REAL NOT NULL,
            relativeFilePath TEXT NOT NULL,
            sha256Hash TEXT NOT NULL,
            availabilityStatus TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_archive_sha256 ON ArchiveItem(sha256Hash);
        CREATE INDEX IF NOT EXISTS idx_archive_status ON ArchiveItem(availabilityStatus);

        COMMIT;
        """
        try doc5Content.data(using: .utf8)?.write(to: doc5URL)
        await importSingleFile(url: doc5URL, tags: [tagWork, tagProject], modelContext: modelContext)

        // ==========================================
        // CATEGORY 4: Audio (waveform / Orange)
        // ==========================================

        // Audio 1: PCM WAV voice memo
        let audio1URL = tempDir.appendingPathComponent("Voice_Memo_Sprint_Planning.wav")
        let audioData = createSampleAudioWAV(durationSeconds: 1.5, frequency: 523.25) // C5 note chime
        try audioData.write(to: audio1URL)
        await importSingleFile(url: audio1URL, tags: [tagWork], modelContext: modelContext)

        // ==========================================
        // CATEGORY 5: Other / Configuration
        // ==========================================

        // Other 1: Production Config file
        let envURL = tempDir.appendingPathComponent("Production_Config.env")
        let envContent = """
        ENVIRONMENT=production
        API_VERSION=v1
        PERSISTENCE_ENGINE=SwiftData
        CRYPTO_HASH_ALGO=SHA256
        CHUNK_SIZE_BYTES=65536
        OFFLINE_MODE_ENABLED=true
        MAX_CONCURRENT_IMPORTS=4
        """
        try envContent.data(using: .utf8)?.write(to: envURL)
        await importSingleFile(url: envURL, tags: [tagProject], modelContext: modelContext)
    }

    // MARK: - Import Helper

    private func importSingleFile(url: URL, tags: [ArchiveTag], modelContext: ModelContext) async {
        _ = await importManager.importFiles(
            from: [url],
            modelContext: modelContext,
            allowDuplicates: true,
            tagsToAssign: tags
        )
    }

    // MARK: - Asset Creators

    private func createSampleImage(title: String, subtitle: String, badge: String, color: UIColor) -> Data? {
        let size = CGSize(width: 800, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            // Draw background gradient
            let colors = [color.cgColor, color.withAlphaComponent(0.65).cgColor]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0])!
            ctx.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])

            // Overlay card
            let cardRect = CGRect(x: 40, y: 50, width: size.width - 80, height: size.height - 100)
            let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 24)
            UIColor.black.withAlphaComponent(0.25).setFill()
            path.fill()

            // Badge pill
            let badgeRect = CGRect(x: 70, y: 80, width: 170, height: 32)
            let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 16)
            UIColor.white.withAlphaComponent(0.2).setFill()
            badgePath.fill()

            let badgeAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let badgeString = NSAttributedString(string: badge, attributes: badgeAttr)
            badgeString.draw(at: CGPoint(x: 85, y: 88))

            // Draw Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let titleString = NSAttributedString(string: title, attributes: titleAttributes)
            titleString.draw(in: CGRect(x: 70, y: 140, width: size.width - 140, height: 100))

            // Draw Subtitle
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.88)
            ]
            let subtitleString = NSAttributedString(string: subtitle, attributes: subtitleAttributes)
            subtitleString.draw(in: CGRect(x: 70, y: 240, width: size.width - 140, height: 120))

            // Footer stamp
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.65)
            ]
            let footerString = NSAttributedString(string: "Verified Digital Asset • GDG Mobile Archive Evaluation", attributes: footerAttributes)
            footerString.draw(in: CGRect(x: 70, y: size.height - 110, width: size.width - 140, height: 30))
        }
        return image.pngData()
    }

    private func createSamplePDF(title: String, author: String, categoryTag: String, content: String) -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "Digital Archive App",
            kCGPDFContextAuthor: author,
            kCGPDFContextTitle: title
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth: CGFloat = 8.5 * 72.0
        let pageHeight: CGFloat = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            context.beginPage()

            // Header Banner
            let headerRect = CGRect(x: 36, y: 36, width: pageWidth - 72, height: 50)
            UIColor.systemBlue.withAlphaComponent(0.12).setFill()
            UIBezierPath(roundedRect: headerRect, cornerRadius: 10).fill()

            let headerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: UIColor.systemBlue
            ]
            "ARCHIVE REPOSITORY // \(categoryTag)".draw(at: CGPoint(x: 50, y: 52), withAttributes: headerAttr)

            // Title
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            title.draw(in: CGRect(x: 36, y: 105, width: pageWidth - 72, height: 55), withAttributes: titleAttr)

            // Date & Author
            let metaAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            let metaText = "Source: \(author) | Date: October 2026 | Verified PDF"
            metaText.draw(at: CGPoint(x: 36, y: 155), withAttributes: metaAttr)

            // Horizontal Line
            let line = UIBezierPath()
            line.move(to: CGPoint(x: 36, y: 175))
            line.addLine(to: CGPoint(x: pageWidth - 36, y: 175))
            UIColor.systemGray4.setStroke()
            line.lineWidth = 1.0
            line.stroke()

            // Body Content
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 5
            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]
            content.draw(in: CGRect(x: 36, y: 195, width: pageWidth - 72, height: pageHeight - 250), withAttributes: bodyAttr)

            // Footer
            let footerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            "Digital Archive Local Persistent Storage • SHA-256 Verified".draw(at: CGPoint(x: 36, y: pageHeight - 45), withAttributes: footerAttr)
        }
    }

    /// Creates a valid 16-bit 44.1kHz mono PCM WAV audio file
    private func createSampleAudioWAV(durationSeconds: Double = 1.5, frequency: Double = 440.0) -> Data {
        let sampleRate: Int = 44100
        let numChannels: Int = 1
        let bitsPerSample: Int = 16
        let byteRate = sampleRate * numChannels * (bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let numSamples = Int(Double(sampleRate) * durationSeconds)
        let subchunk2Size = numSamples * numChannels * (bitsPerSample / 8)
        let chunkSize = 36 + subchunk2Size

        var data = Data()
        // RIFF header
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        data.append(contentsOf: withUnsafeBytes(of: UInt32(chunkSize).littleEndian) { Array($0) })
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // "fmt " chunk
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // Subchunk1Size (16 for PCM)
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // AudioFormat (1 = PCM)
        data.append(contentsOf: withUnsafeBytes(of: UInt16(numChannels).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Array($0) })

        // "data" chunk
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.append(contentsOf: withUnsafeBytes(of: UInt32(subchunk2Size).littleEndian) { Array($0) })

        // Sine wave tone with gentle exponential decay
        for i in 0..<numSamples {
            let t = Double(i) / Double(sampleRate)
            // Two-tone chime: frequency for first half, 1.5x frequency for second half
            let currentFreq = (t < durationSeconds * 0.4) ? frequency : frequency * 1.5
            let envelope = max(0.0, 1.0 - (t / durationSeconds))
            let sample = sin(2.0 * .pi * currentFreq * t) * envelope * 0.4
            let intSample = Int16(max(-32768, min(32767, sample * 32767.0)))
            data.append(contentsOf: withUnsafeBytes(of: intSample.littleEndian) { Array($0) })
        }

        return data
    }
}
