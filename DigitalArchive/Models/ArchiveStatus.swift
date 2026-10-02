import Foundation
import SwiftUI

/// Status of file availability on the physical disk
public enum ArchiveStatus: String, Codable, CaseIterable, Sendable {
    case available = "available"
    case missing = "missing"
    case unreadable = "unreadable"

    public var displayName: String {
        switch self {
        case .available:
            return "Available"
        case .missing:
            return "Missing"
        case .unreadable:
            return "Unreadable"
        }
    }

    public var iconName: String {
        switch self {
        case .available:
            return "checkmark.circle.fill"
        case .missing:
            return "exclamationmark.triangle.fill"
        case .unreadable:
            return "xmark.octagon.fill"
        }
    }

    public var color: Color {
        switch self {
        case .available:
            return .green
        case .missing:
            return .red
        case .unreadable:
            return .orange
        }
    }
}
