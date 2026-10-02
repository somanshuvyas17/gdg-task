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

    /// Generates sample files across Images, PDFs, and Documents, and imports them into the archive
    public func generateAndImportSampleData(modelContext: ModelContext) async throws {
        // Deduplicate before creating
        ArchiveTag.deduplicate(in: modelContext)

        // Find or create default tags without duplicates
        let tagWork = ArchiveTag.findOrCreate(name: "Work", colorHex: "#007AFF", in: modelContext)
        let tagPersonal = ArchiveTag.findOrCreate(name: "Personal", colorHex: "#34C759", in: modelContext)
        let tagReceipts = ArchiveTag.findOrCreate(name: "Receipts", colorHex: "#FF9500", in: modelContext)
        let tagProject = ArchiveTag.findOrCreate(name: "Project 2026", colorHex: "#AF52DE", in: modelContext)

        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("SampleArchiveSource_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var sampleURLs: [URL] = []

        // 1. Generate Sample Image 1: Architecture Blueprint
        let image1URL = tempDir.appendingPathComponent("System_Architecture_Diagram.png")
        if let imgData = createSampleImage(title: "Digital Archive Architecture", subtitle: "SwiftUI + SwiftData + Sandbox Filesystem", color: UIColor.systemIndigo) {
            try imgData.write(to: image1URL)
            sampleURLs.append(image1URL)
        }

        // 2. Generate Sample Image 2: Photo Capture
        let image2URL = tempDir.appendingPathComponent("Conference_Photo_2026.png")
        if let imgData2 = createSampleImage(title: "GDG Tech Summit 2026", subtitle: "Keynote presentation snapshot", color: UIColor.systemTeal) {
            try imgData2.write(to: image2URL)
            sampleURLs.append(image2URL)
        }

        // 3. Generate Sample PDF 1: Annual Financial Report
        let pdf1URL = tempDir.appendingPathComponent("Q3_Financial_Audit_Report.pdf")
        let pdf1Data = createSamplePDF(
            title: "Q3 2026 Financial Audit Report",
            author: "Digital Archive System",
            content: """
            EXECUTIVE SUMMARY:
            This document represents a verified PDF archived within the local mobile storage container.
            
            Key Highlights:
            • 100% On-device cryptographic verification using SHA-256 streaming hashing.
            • Multi-category taxonomy support with instant metadata extraction.
            • Persistent sandboxed file isolation preventing external unauthorized modifications.
            • Dynamic availability check ensures data consistency even across simulated storage failures.
            
            AUDIT CONCLUSION:
            All archived records adhere to digital asset preservation standards.
            """
        )
        try pdf1Data.write(to: pdf1URL)
        sampleURLs.append(pdf1URL)

        // 4. Generate Sample PDF 2: Product Specifications
        let pdf2URL = tempDir.appendingPathComponent("Product_Specification_Doc.pdf")
        let pdf2Data = createSamplePDF(
            title: "Mobile Archive Architecture Specification",
            author: "Engineering Lead",
            content: """
            TECHNICAL SPECIFICATIONS:
            1. Framework: SwiftUI + SwiftData
            2. Sandboxing: Container Documents/DigitalArchive/Files
            3. Error Handling: Missing file resilience and atomic staged commit
            4. Performance: Non-blocking asynchronous I/O with progress streaming
            """
        )
        try pdf2Data.write(to: pdf2URL)
        sampleURLs.append(pdf2URL)

        // 5. Generate Sample Document: Markdown Notes
        let doc1URL = tempDir.appendingPathComponent("Meeting_Action_Items.md")
        let doc1Content = """
        # Strategic Initiatives Meeting Notes
        Date: October 2026
        
        ## Priority Tasks:
        1. [x] Complete local persistence layer using SwiftData.
        2. [x] Implement multi-file import with cancellation tokens.
        3. [x] Implement missing file integrity detection and relinking.
        4. [x] Complete search and multifaceted filtering.
        5. [x] Add SHA-256 duplicate detection.
        """
        try doc1Content.data(using: .utf8)?.write(to: doc1URL)
        sampleURLs.append(doc1URL)

        // 6. Generate Sample Document: JSON Data
        let doc2URL = tempDir.appendingPathComponent("Archive_Metadata_Schema.json")
        let doc2Content = """
        {
          "system": "DigitalArchive",
          "version": "1.0.0",
          "storageStrategy": "sandboxed-relative-paths",
          "hashAlgorithm": "SHA-256",
          "supportedFileTypes": ["Images", "PDFs", "Documents", "Audio", "Video"]
        }
        """
        try doc2Content.data(using: .utf8)?.write(to: doc2URL)
        sampleURLs.append(doc2URL)

        // 7. Generate Sample Document: CSV Spreadsheet
        let doc3URL = tempDir.appendingPathComponent("Expense_Report_2026.csv")
        let doc3Content = """
        Date,Category,Description,Amount,Status
        2026-09-15,Software,Apple Developer Program,99.00,Approved
        2026-09-20,Cloud,Cloudflare Domain,12.00,Approved
        2026-09-28,Hardware,Storage Backup Drive,149.99,Pending
        """
        try doc3Content.data(using: .utf8)?.write(to: doc3URL)
        sampleURLs.append(doc3URL)

        // Batch import all generated files
        _ = await importManager.importFiles(
            from: sampleURLs,
            modelContext: modelContext,
            allowDuplicates: true,
            tagsToAssign: [tagWork, tagProject]
        )

        // Clean up temporary sample generation folder
        try? fileManager.removeItem(at: tempDir)
    }

    private func createSampleImage(title: String, subtitle: String, color: UIColor) -> Data? {
        let size = CGSize(width: 800, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            // Draw background gradient
            let colors = [color.cgColor, color.withAlphaComponent(0.6).cgColor]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0])!
            ctx.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])

            // Overlay card
            let cardRect = CGRect(x: 40, y: 60, width: size.width - 80, height: size.height - 120)
            let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 24)
            UIColor.black.withAlphaComponent(0.25).setFill()
            path.fill()

            // Draw Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let titleString = NSAttributedString(string: title, attributes: titleAttributes)
            titleString.draw(in: CGRect(x: 70, y: 120, width: size.width - 140, height: 100))

            // Draw Subtitle
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
            let subtitleString = NSAttributedString(string: subtitle, attributes: subtitleAttributes)
            subtitleString.draw(in: CGRect(x: 70, y: 220, width: size.width - 140, height: 100))

            // Footer stamp
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6)
            ]
            let footerString = NSAttributedString(string: "Verified Digital Asset • Generated for Evaluation", attributes: footerAttributes)
            footerString.draw(in: CGRect(x: 70, y: size.height - 130, width: size.width - 140, height: 40))
        }
        return image.pngData()
    }

    private func createSamplePDF(title: String, author: String, content: String) -> Data {
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
            let headerRect = CGRect(x: 36, y: 36, width: pageWidth - 72, height: 60)
            UIColor.systemBlue.withAlphaComponent(0.12).setFill()
            UIBezierPath(roundedRect: headerRect, cornerRadius: 10).fill()

            let headerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: UIColor.systemBlue
            ]
            "OFFICIAL ARCHIVE DOCUMENT".draw(at: CGPoint(x: 50, y: 56), withAttributes: headerAttr)

            // Title
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            title.draw(in: CGRect(x: 36, y: 120, width: pageWidth - 72, height: 60), withAttributes: titleAttr)

            // Date & Author
            let metaAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            let metaText = "Author: \(author) | Date: October 2026 | Format: PDF"
            metaText.draw(at: CGPoint(x: 36, y: 175), withAttributes: metaAttr)

            // Horizontal Line
            let line = UIBezierPath()
            line.move(to: CGPoint(x: 36, y: 200))
            line.addLine(to: CGPoint(x: pageWidth - 36, y: 200))
            UIColor.lightGray.setStroke()
            line.lineWidth = 1.0
            line.stroke()

            // Body Content
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6
            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]
            content.draw(in: CGRect(x: 36, y: 220, width: pageWidth - 72, height: pageHeight - 280), withAttributes: bodyAttr)

            // Footer
            let footerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            "Page 1 of 1 • Digital Archive Local Persistent Storage".draw(at: CGPoint(x: 36, y: pageHeight - 45), withAttributes: footerAttr)
        }
    }
}
