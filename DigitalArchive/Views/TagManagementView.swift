import SwiftUI
import SwiftData

public struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ArchiveTag.name) private var tags: [ArchiveTag]

    @State private var newTagName: String = ""
    @State private var selectedColorHex: String = "#007AFF"
    @State private var tagPendingDeletion: ArchiveTag? = nil
    @State private var showDeleteConfirm: Bool = false

    private let presetColors: [String] = [
        "#007AFF", // Blue
        "#34C759", // Green
        "#FF9500", // Orange
        "#FF3B30", // Red
        "#AF52DE", // Purple
        "#FF2D55", // Pink
        "#5856D6", // Indigo
        "#00C7BE"  // Teal
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Section 1: Create New Tag
                Section("Create New Tag") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Circle()
                                .fill(Color(hex: selectedColorHex))
                                .frame(width: 24, height: 24)

                            TextField("Tag Name (e.g. Invoices, Contracts)", text: $newTagName)
                                .textFieldStyle(.plain)

                            Button("Add") {
                                createTag()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        // Color swatches
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(presetColors, id: \.self) { hex in
                                    ColorSwatchView(
                                        hex: hex,
                                        isSelected: selectedColorHex == hex,
                                        onSelect: { selectedColorHex = hex }
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Section 2: Existing Tags
                Section("Existing Tags (\(tags.count))") {
                    if tags.isEmpty {
                        ContentUnavailableView(
                            "No Tags Created",
                            systemImage: "tag",
                            description: Text("Add tags above to organize your archived files.")
                        )
                    } else {
                        ForEach(tags) { tag in
                            HStack {
                                Circle()
                                    .fill(tag.color)
                                    .frame(width: 14, height: 14)

                                Text(tag.name)
                                    .font(.headline)

                                Spacer()

                                Text("\(tag.items?.count ?? 0) files")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.12))
                                    .cornerRadius(8)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    tagPendingDeletion = tag
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 60)
            .navigationTitle("Tags & Categories")
            .task {
                ArchiveTag.deduplicate(in: modelContext)
            }
            .confirmationDialog(
                "Delete Tag?",
                isPresented: $showDeleteConfirm,
                presenting: tagPendingDeletion
            ) { tag in
                Button("Delete '\(tag.name)'", role: .destructive) {
                    deleteTag(tag)
                }
                Button("Cancel", role: .cancel) {}
            } message: { tag in
                Text("Deleting this tag will remove it from all \(tag.items?.count ?? 0) associated files. The files themselves will remain in the archive.")
            }
        }
    }

    private func createTag() {
        let trimmed = ArchiveTag.normalizeName(newTagName)
        guard !trimmed.isEmpty else { return }

        // Enforce case-insensitive uniqueness at data layer
        _ = ArchiveTag.findOrCreate(name: trimmed, colorHex: selectedColorHex, in: modelContext)
        newTagName = ""
    }

    private func deleteTag(_ tag: ArchiveTag) {
        // Remove tag from items
        if let items = tag.items {
            for item in items {
                item.removeTag(tag)
            }
        }
        modelContext.delete(tag)
        try? modelContext.save()
    }
}

struct ColorSwatchView: View {
    let hex: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: 28, height: 28)
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: isSelected ? 2.5 : 0)
            )
            .onTapGesture(perform: onSelect)
    }
}
