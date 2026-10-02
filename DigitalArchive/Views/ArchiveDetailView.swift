import SwiftUI
import SwiftData
import UniformTypeIdentifiers

public struct ArchiveDetailView: View {
    @Bindable var item: ArchiveItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ArchiveTag.name) private var allTags: [ArchiveTag]

    @State private var isEditingTitle: Bool = false
    @State private var editedTitle: String = ""
    @State private var isPreviewPresented: Bool = false
    @State private var isRelinkPickerPresented: Bool = false
    @State private var showDeleteConfirmDialog: Bool = false
    @State private var isSharePresented: Bool = false
    @State private var showCopiedAlert: Bool = false
    @State private var newTagName: String = ""
    @State private var isAddingNewTag: Bool = false

    private var physicalFileURL: URL {
        ArchiveStorageManager.shared.fileURL(for: item.relativeFilePath)
    }

    private var physicalFileExists: Bool {
        FileManager.default.fileExists(atPath: physicalFileURL.path)
    }

    public init(item: ArchiveItem) {
        self.item = item
    }

    public var body: some View {
        List {
            heroSection
            fileInformationSection
            tagsSection
            locationSection
            actionsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("File Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .bold()
            }
        }
        .sheet(isPresented: $isPreviewPresented) {
            FilePreviewView(item: item)
        }
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(items: [physicalFileURL])
        }
        .fileImporter(
            isPresented: $isRelinkPickerPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleRelink(result: result)
        }
        .confirmationDialog(
            "Remove Archive Entry",
            isPresented: $showDeleteConfirmDialog,
            titleVisibility: .visible
        ) {
            Button("Delete Record AND Physical File", role: .destructive) {
                deleteEntry(deletePhysicalFile: true)
            }
            Button("Remove from Archive Only (Keep File)") {
                deleteEntry(deletePhysicalFile: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose whether to permanently delete the file from device storage, or only remove its database entry.")
        }
        .alert("Checksum Copied", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("SHA-256 hash copied to clipboard.")
        }
        .alert("Rename File Entry", isPresented: $isEditingTitle) {
            TextField("File Name", text: $editedTitle)
            Button("Save") {
                let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    item.title = trimmed
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a new display name for this archived file.")
        }
        .onAppear {
            verifyStatus()
        }
    }

    // MARK: - Hero Section

    @ViewBuilder
    private var heroSection: some View {
        Section {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(item.fileCategory.color.opacity(0.12))
                        .frame(width: 80, height: 80)

                    Image(systemName: item.fileCategory.iconName)
                        .font(.system(size: 38))
                        .foregroundColor(item.fileCategory.color)
                }

                Text(item.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(item.availabilityStatus.color)
                        .frame(width: 8, height: 8)
                    Text(item.availabilityStatus.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(item.availabilityStatus.color)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(item.availabilityStatus.color.opacity(0.12))
                .cornerRadius(12)

                if item.availabilityStatus == .missing || !physicalFileExists {
                    Text("The physical file is not accessible at its expected location. Database metadata, tags, and checksum remain 100% preserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)

                    Button {
                        isRelinkPickerPresented = true
                    } label: {
                        Label("Relink Replacement File", systemImage: "link.badge.plus")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    // MARK: - File Information

    @ViewBuilder
    private var fileInformationSection: some View {
        Section("File Information") {
            infoRow(label: "Name", value: item.originalFileName)
            infoRow(label: "Type", value: "\(item.fileCategory.displayName) (\(item.fileExtension.uppercased()))")
            infoRow(label: "Size", value: item.formattedSize)
            infoRow(label: "Imported", value: Formatters.standardDate.string(from: item.importDate))
            infoRow(label: "Modified", value: Formatters.standardDate.string(from: item.lastModifiedDate))

            HStack {
                Text("SHA-256")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                Spacer()
                Text(String(item.sha256Hash.prefix(12)) + "...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)

                Button {
                    UIPasteboard.general.string = item.sha256Hash
                    showCopiedAlert = true
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.indigo)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    // MARK: - Tags Section

    @ViewBuilder
    private var tagsSection: some View {
        Section("Tags") {
            VStack(alignment: .leading, spacing: 10) {
                if item.safeTags.isEmpty {
                    Text("No tags assigned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    FlowTagLayout(spacing: 8) {
                        ForEach(item.safeTags) { tag in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(tag.color)
                                    .frame(width: 8, height: 8)
                                Text(tag.name)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Button {
                                    item.removeTag(tag)
                                    try? modelContext.save()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(tag.color.opacity(0.12))
                            .foregroundColor(tag.color)
                            .cornerRadius(12)
                        }
                    }
                }

                // Add Tag Button / Menu
                let unassignedTags = allTags.filter { tag in
                    !(item.tags?.contains(where: { $0.id == tag.id }) ?? false)
                }

                HStack {
                    if !unassignedTags.isEmpty {
                        Menu {
                            ForEach(unassignedTags) { tag in
                                Button {
                                    item.addTag(tag)
                                    try? modelContext.save()
                                } label: {
                                    Label(tag.name, systemImage: "tag.fill")
                                }
                            }
                        } label: {
                            Label("Add Tag", systemImage: "plus.circle.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }

                    Spacer()
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Location Section

    @ViewBuilder
    private var locationSection: some View {
        Section("Location") {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.relativeFilePath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)

                Text("Sandboxed App Container Documents")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Actions Section

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            if physicalFileExists {
                Button {
                    isPreviewPresented = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Open File", systemImage: "doc.text.magnifyingglass")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }

                Button {
                    isSharePresented = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Share File", systemImage: "square.and.arrow.up")
                        Spacer()
                    }
                }
            }

            Button {
                editedTitle = item.title
                isEditingTitle = true
            } label: {
                HStack {
                    Spacer()
                    Label("Rename Entry", systemImage: "pencil")
                    Spacer()
                }
            }

            Button(role: .destructive) {
                showDeleteConfirmDialog = true
            } label: {
                HStack {
                    Spacer()
                    Label("Remove from Archive", systemImage: "trash")
                        .foregroundColor(.red)
                        Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    private func verifyStatus() {
        _ = IntegrityScanner.shared.verifySingleItem(item, modelContext: modelContext)
    }

    private func handleRelink(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                try ArchiveStorageManager.shared.relinkFile(relativePath: item.relativeFilePath, newSourceURL: url)
                Task {
                    let meta = try await FileMetadataExtractor.shared.extractMetadata(from: physicalFileURL, originalName: url.lastPathComponent)
                    await MainActor.run {
                        item.fileSizeBytes = meta.fileSizeBytes
                        item.sha256Hash = meta.sha256Hash
                        item.lastModifiedDate = meta.lastModifiedDate
                        verifyStatus()
                    }
                }
            } catch {
                print("Relink failed: \(error)")
            }
        case .failure(let error):
            print("Picker error: \(error)")
        }
    }

    private func deleteEntry(deletePhysicalFile: Bool) {
        if deletePhysicalFile {
            try? ArchiveStorageManager.shared.deletePhysicalFile(relativePath: item.relativeFilePath)
        }
        modelContext.delete(item)
        try? modelContext.save()
        dismiss()
    }
}

// Flow Tag Layout for wrapping badges
struct FlowTagLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeightInRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            maxHeightInRow = max(maxHeightInRow, size.height)
            currentX += size.width + spacing
        }
        height = currentY + maxHeightInRow
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxHeightInRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            maxHeightInRow = max(maxHeightInRow, size.height)
            currentX += size.width + spacing
        }
    }
}
