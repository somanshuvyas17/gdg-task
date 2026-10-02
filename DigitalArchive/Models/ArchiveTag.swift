import Foundation
import SwiftData
import SwiftUI

@Model
public final class ArchiveTag {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var colorHex: String
    public var createdDate: Date

    @Relationship(inverse: \ArchiveItem.tags)
    public var items: [ArchiveItem]? = []

    public init(name: String, colorHex: String = "#0A84FF") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdDate = Date()
        self.items = []
    }

    public var color: Color {
        Color(hex: colorHex)
    }

    /// Normalizes tag names by trimming whitespace
    public static func normalizeName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Finds an existing tag with case-insensitive match or creates a new one
    @discardableResult
    public static func findOrCreate(
        name: String,
        colorHex: String = "#0A84FF",
        in context: ModelContext
    ) -> ArchiveTag {
        let cleanName = normalizeName(name)
        let descriptor = FetchDescriptor<ArchiveTag>()
        if let existingTags = try? context.fetch(descriptor) {
            if let match = existingTags.first(where: {
                $0.name.localizedCaseInsensitiveCompare(cleanName) == .orderedSame
            }) {
                return match
            }
        }
        let newTag = ArchiveTag(name: cleanName, colorHex: colorHex)
        context.insert(newTag)
        try? context.save()
        return newTag
    }

    /// Merges all duplicate tags with case-insensitive matching, reassigning items and deleting redundant tags
    public static func deduplicate(in context: ModelContext) {
        let descriptor = FetchDescriptor<ArchiveTag>()
        guard let allTags = try? context.fetch(descriptor) else { return }

        var grouped: [String: [ArchiveTag]] = [:]
        for tag in allTags {
            let key = normalizeName(tag.name).lowercased()
            grouped[key, default: []].append(tag)
        }

        var didModify = false
        for (_, tagsGroup) in grouped where tagsGroup.count > 1 {
            // Keep the tag with the most items, or the first created
            let sorted = tagsGroup.sorted {
                ($0.items?.count ?? 0) > ($1.items?.count ?? 0)
            }
            let primary = sorted[0]
            let duplicates = sorted.dropFirst()

            // Ensure primary has clean, trimmed name
            let cleanPrimaryName = normalizeName(primary.name)
            if primary.name != cleanPrimaryName {
                primary.name = cleanPrimaryName
                didModify = true
            }

            for dup in duplicates {
                if let items = dup.items {
                    for item in items {
                        item.addTag(primary)
                        item.removeTag(dup)
                    }
                }
                context.delete(dup)
                didModify = true
            }
        }

        if didModify {
            try? context.save()
        }
    }
}

// Color hex helper
extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 10, 132, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    public func toHex() -> String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "#0A84FF"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
