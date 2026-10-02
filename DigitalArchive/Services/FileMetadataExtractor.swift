import Foundation
import CryptoKit
import UniformTypeIdentifiers
import UIKit
import PDFKit

public struct ExtractedFileMetadata: Sendable {
    public let originalFileName: String
    public let fileExtension: String
    public let utiType: String
    public let fileCategory: FileCategory
    public let fileSizeBytes: Int64
    public let lastModifiedDate: Date
    public let sha256Hash: String
    public let thumbnailData: Data?
}

public final class FileMetadataExtractor: @unchecked Sendable {
    public static let shared = FileMetadataExtractor()

    private let fileManager = FileManager.default

    public init() {}

    /// Extracts all metadata from a given file URL asynchronously
    public func extractMetadata(from fileURL: URL, originalName: String? = nil) async throws -> ExtractedFileMetadata {
        let name = originalName ?? fileURL.lastPathComponent
        let ext = fileURL.pathExtension.lowercased()

        // Size & modification date
        var fileSize: Int64 = 0
        var modDate: Date = Date()

        if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path) {
            if let size = attrs[.size] as? NSNumber {
                fileSize = size.int64Value
            }
            if let date = attrs[.modificationDate] as? Date {
                modDate = date
            }
        }

        // UTType & Category
        let utType = UTType(filenameExtension: ext) ?? .data
        let utiString = utType.identifier
        let category = FileCategory.determineCategory(from: utType, fileExtension: ext)

        // Compute SHA-256 hash asynchronously using streaming chunks
        let hash = try await computeSHA256(for: fileURL)

        // Generate thumbnail if appropriate
        let thumbnail = await generateThumbnail(for: fileURL, category: category)

        return ExtractedFileMetadata(
            originalFileName: name,
            fileExtension: ext,
            utiType: utiString,
            fileCategory: category,
            fileSizeBytes: fileSize,
            lastModifiedDate: modDate,
            sha256Hash: hash,
            thumbnailData: thumbnail
        )
    }

    /// Computes SHA-256 hash in 64KB streaming chunks to keep memory usage minimal
    public func computeSHA256(for fileURL: URL) async throws -> String {
        return try await Task.detached(priority: .userInitiated) {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer {
                try? handle.close()
            }

            var hasher = SHA256()
            let chunkSize = 64 * 1024 // 64 KB

            while true {
                let data = handle.readData(ofLength: chunkSize)
                if data.isEmpty {
                    break
                }
                hasher.update(data: data)
            }

            let digest = hasher.finalize()
            return digest.map { String(format: "%02hhx", $0) }.joined()
        }.value
    }

    /// Generates thumbnail for image or PDF
    public func generateThumbnail(for fileURL: URL, category: FileCategory, maxPixelDimension: CGFloat = 200) async -> Data? {
        return await Task.detached(priority: .utility) { () -> Data? in
            switch category {
            case .image:
                guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
                    return nil
                }
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension
                ]
                guard let thumbnailImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
                    return nil
                }
                let uiImage = UIImage(cgImage: thumbnailImage)
                return uiImage.jpegData(compressionQuality: 0.7)

            case .pdf:
                guard let document = PDFDocument(url: fileURL),
                      let page = document.page(at: 0) else {
                    return nil
                }
                let pageRect = page.bounds(for: .mediaBox)
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: maxPixelDimension, height: maxPixelDimension * (pageRect.height / maxPixelDimension)))
                let image = renderer.image { ctx in
                    UIColor.white.set()
                    ctx.fill(CGRect(x: 0, y: 0, width: maxPixelDimension, height: maxPixelDimension * (pageRect.height / maxPixelDimension)))
                    ctx.cgContext.translateBy(x: 0.0, y: maxPixelDimension * (pageRect.height / maxPixelDimension))
                    ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                    page.draw(with: .mediaBox, to: ctx.cgContext)
                }
                return image.jpegData(compressionQuality: 0.7)

            default:
                return nil
            }
        }.value
    }
}
