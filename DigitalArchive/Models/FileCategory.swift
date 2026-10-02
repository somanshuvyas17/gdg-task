import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Categorization of archived files
public enum FileCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case all = "all"
    case image = "image"
    case pdf = "pdf"
    case document = "document"
    case audio = "audio"
    case video = "video"
    case other = "other"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: return "All Files"
        case .image: return "Images"
        case .pdf: return "PDFs"
        case .document: return "Documents"
        case .audio: return "Audio"
        case .video: return "Video"
        case .other: return "Other"
        }
    }

    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .image: return "photo.fill"
        case .pdf: return "doc.richtext.fill"
        case .document: return "doc.text.fill"
        case .audio: return "waveform"
        case .video: return "film.fill"
        case .other: return "doc.fill"
        }
    }

    public var color: Color {
        switch self {
        case .all: return .primary
        case .image: return .purple
        case .pdf: return .red
        case .document: return .blue
        case .audio: return .orange
        case .video: return .pink
        case .other: return .gray
        }
    }

    public static func determineCategory(from utType: UTType?, fileExtension: String) -> FileCategory {
        let ext = fileExtension.lowercased()

        if let utType = utType {
            if utType.conforms(to: .image) { return .image }
            if utType.conforms(to: .pdf) { return .pdf }
            if utType.conforms(to: .text) || utType.conforms(to: .plainText) || utType.conforms(to: .sourceCode) || utType.conforms(to: .presentation) || utType.conforms(to: .spreadsheet) {
                return .document
            }
            if utType.conforms(to: .audio) { return .audio }
            if utType.conforms(to: .movie) || utType.conforms(to: .video) { return .video }
        }

        // Fallback by extension
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff", "bmp", "svg":
            return .image
        case "pdf":
            return .pdf
        case "txt", "md", "markdown", "rtf", "doc", "docx", "pages", "csv", "json", "xml", "html", "swift", "py", "js":
            return .document
        case "mp3", "m4a", "wav", "aac", "flac", "ogg", "aiff":
            return .audio
        case "mp4", "mov", "m4v", "avi", "mkv", "webm":
            return .video
        default:
            return .other
        }
    }
}
