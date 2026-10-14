import SwiftUI
import SwiftData
import UniformTypeIdentifiers

public struct ArchiveListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ArchiveItem]
    @Query(sort: \ArchiveTag.name) private var allTags: [ArchiveTag]
    @StateObject private var viewModel = ArchiveListViewModel()
    @StateObject private var importManager = ImportManager.shared

    @State private var selectedFileForDetail: ArchiveItem? = nil
    @State private var showSettingsSheet = false
    @State private var showImportIssuesAlert = false
    @State private var showImportDetailsSheet = false

    public init() {}

    private var filteredItems: [ArchiveItem] {
        viewModel.filterAndSort(items: allItems)
    }

    private var totalStorageBytes: Int64 {
        ArchiveStorageManager.shared.totalArchiveSizeBytes()
    }

    public var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            if allItems.isEmpty {
                EmptyArchiveView {
                    viewModel.isFileImporterPresented = true
                }
            } else {
                mainContent
            }
        }
        .sheet(item: $selectedFileForDetail) { item in
            NavigationStack {
                ArchiveDetailView(item: item)
            }
        }
        .sheet(isPresented: $viewModel.isFilterSheetPresented) {
            FilterSheetView(viewModel: viewModel)
        }
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                SettingsAndDemoView()
            }
        }
        .fileImporter(
            isPresented: $viewModel.isFileImporterPresented,
            allowedContentTypes: [.item, .image, .pdf, .text, .movie, .audio],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result: result)
        }
        .confirmationDialog(
            "Delete Archive Entry",
            isPresented: $viewModel.showDeleteOptionsAlert,
            presenting: viewModel.itemPendingDeletion
        ) { item in
            Button("Delete Record AND Physical File", role: .destructive) {
                viewModel.deleteItem(item, deletePhysicalFile: true, modelContext: modelContext)
            }
            Button("Remove from Archive Only", role: .none) {
                viewModel.deleteItem(item, deletePhysicalFile: false, modelContext: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("Choose how to remove '\(item.title)' from the archive.")
        }
        .confirmationDialog(
            "Batch Delete",
            isPresented: $viewModel.showBatchDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("Delete Records AND Files", role: .destructive) {
                viewModel.batchDelete(items: allItems, deletePhysicalFiles: true, modelContext: modelContext)
            }
            Button("Remove Records Only", role: .none) {
                viewModel.batchDelete(items: allItems, deletePhysicalFiles: false, modelContext: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Duplicate File Detected", isPresented: Binding(
            get: { importManager.detectedDuplicate != nil },
            set: { if !$0 { importManager.detectedDuplicate = nil } }
        )) {
            if let match = importManager.detectedDuplicate {
                Button("View Existing") {
                    let targetID = match.existingItemID
                    if let item = allItems.first(where: { $0.id == targetID }) {
                        selectedFileForDetail = item
                    }
                    importManager.detectedDuplicate = nil
                }
                Button("Import Anyway") {
                    Task {
                        _ = await importManager.importFiles(
                            from: [match.incomingURL],
                            modelContext: modelContext,
                            allowDuplicates: true
                        )
                        importManager.detectedDuplicate = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    importManager.detectedDuplicate = nil
                }
            }
        }
        .sheet(isPresented: $showImportDetailsSheet) {
            if let result = importManager.lastResult {
                ImportIssuesSheetView(result: result)
            }
        }
        .alert("Import Summary", isPresented: $showImportIssuesAlert) {
            Button("View Details") {
                showImportDetailsSheet = true
            }
            Button("OK", role: .cancel) {}
        } message: {
            if let result = importManager.lastResult {
                Text("\(result.successfulCount) file(s) imported successfully.\n\(result.failedCount) file(s) failed.")
            }
        }
        .task {
            ArchiveTag.deduplicate(in: modelContext)
            if CommandLine.arguments.contains("-detailFirstItem") {
                try? await Task.sleep(nanoseconds: 500_000_000)
                selectedFileForDetail = allItems.first
            }
        }
        .overlay { importProgressOverlay }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                searchBarSection
                categoryChipsSection
                statsCardSection
                recentFilesHeader
                fileCardsSection
            }
            .padding(.bottom, 100) // Space for custom tab bar
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ArchiveX")
                    .font(.system(size: 28, weight: .bold))
                Text("Your files, organized.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Avatar
            Circle()
                .fill(Color.indigo)
                .frame(width: 36, height: 36)
                .overlay(
                    Text("AR")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                )

            // Settings gear
            Button {
                showSettingsSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.systemGray5))
                        .frame(width: 36, height: 36)
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Search Bar

    @ViewBuilder
    private var searchBarSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))

            TextField("Search files, tags, or categories...", text: $viewModel.searchText)
                .font(.subheadline)

            Image(systemName: "mic.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }

    // MARK: - Category Chips

    @ViewBuilder
    private var categoryChipsSection: some View {
        ZStack(alignment: .trailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    FilterChip(
                        title: "All",
                        isSelected: viewModel.selectedCategory == .all && viewModel.selectedStatus == nil
                    ) {
                        withAnimation(.spring()) {
                            viewModel.selectedCategory = .all
                            viewModel.selectedStatus = nil
                        }
                    }

                    FilterChip(
                        title: "PDFs",
                        isSelected: viewModel.selectedCategory == .pdf
                    ) {
                        withAnimation(.spring()) {
                            viewModel.selectedCategory = .pdf
                            viewModel.selectedStatus = nil
                        }
                    }

                    FilterChip(
                        title: "Images",
                        isSelected: viewModel.selectedCategory == .image
                    ) {
                        withAnimation(.spring()) {
                            viewModel.selectedCategory = .image
                            viewModel.selectedStatus = nil
                        }
                    }

                    FilterChip(
                        title: "Documents",
                        isSelected: viewModel.selectedCategory == .document
                    ) {
                        withAnimation(.spring()) {
                            viewModel.selectedCategory = .document
                            viewModel.selectedStatus = nil
                        }
                    }

                    FilterChip(
                        title: "Audio",
                        isSelected: viewModel.selectedCategory == .audio
                    ) {
                        withAnimation(.spring()) {
                            viewModel.selectedCategory = .audio
                            viewModel.selectedStatus = nil
                        }
                    }

                    FilterChip(
                        title: "Missing",
                        isSelected: viewModel.selectedStatus == .missing
                    ) {
                        withAnimation(.spring()) {
                            viewModel.selectedCategory = .all
                            viewModel.selectedStatus = .missing
                        }
                    }

                    // Subtle scroll spacer
                    Color.clear.frame(width: 16)
                }
                .padding(.horizontal, 20)
            }

            // Subtle trailing fade gradient indicating horizontal scrollability
            LinearGradient(
                colors: [Color(UIColor.systemGroupedBackground).opacity(0), Color(UIColor.systemGroupedBackground)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 28)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Stats Card

    @ViewBuilder
    private var statsCardSection: some View {
        HStack(spacing: 0) {
            statsColumn(value: "\(allItems.count)", label: "Files")
            statsColumn(value: "\(allTags.count)", label: "Categories")
            statsColumn(value: Formatters.formattedByteCount(totalStorageBytes), label: "Storage")
        }
        .padding(.vertical, 16)
        .background(Color.indigo.opacity(0.08))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }

    private func statsColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Recent Files Header

    @ViewBuilder
    private var recentFilesHeader: some View {
        HStack {
            Text("Recent files")
                .font(.headline)

            Spacer()

            Menu {
                Section("Sort By") {
                    ForEach(ArchiveSortOption.allCases) { option in
                        Button {
                            viewModel.sortOption = option
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if viewModel.sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.sortOption.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - File Cards

    @ViewBuilder
    private var fileCardsSection: some View {
        if filteredItems.isEmpty {
            noResultsView
        } else {
            LazyVStack(spacing: 10) {
                ForEach(filteredItems) { item in
                    FileCardView(
                        item: item,
                        onTap: { selectedFileForDetail = item },
                        onDelete: { deletePhysical in
                            if deletePhysical {
                                viewModel.deleteItem(item, deletePhysicalFile: true, modelContext: modelContext)
                            } else {
                                viewModel.itemPendingDeletion = item
                                viewModel.showDeleteOptionsAlert = true
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundColor(.secondary)

            Text("No files found")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Try searching with another filename, tag, or category.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if !viewModel.searchText.isEmpty || viewModel.selectedCategory != .all || viewModel.selectedStatus != nil {
                Button("Clear Filters & Search") {
                    viewModel.resetFilters()
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
        .padding(.top, 48)
    }

    // MARK: - Import Progress

    @ViewBuilder
    private var importProgressOverlay: some View {
        if importManager.isImporting, let progress = importManager.currentProgress {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView(value: progress.fractionCompleted)
                        .progressViewStyle(.linear)
                        .frame(width: 220)

                    Text("Importing \(progress.currentCompleted + 1) of \(progress.totalCount)...")
                        .font(.headline)

                    Text(progress.currentFileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 240)

                    Button("Cancel Import", role: .destructive) {
                        importManager.cancelCurrentImport()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(24)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 10)
            }
        }
    }

    // MARK: - Helpers

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            Task {
                let importResult = await importManager.importFiles(
                    from: urls,
                    modelContext: modelContext,
                    allowDuplicates: false
                )
                if importResult.failedCount > 0 {
                    showImportIssuesAlert = true
                }
            }
        case .failure(let error):
            print("Import selection error: \(error.localizedDescription)")
        }
    }
}

// MARK: - File Card View

struct FileCardView: View {
    let item: ArchiveItem
    let onTap: () -> Void
    let onDelete: (Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                fileIcon
                fileInfo
                Spacer()
                menuButton
            }
            .padding(14)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(colorScheme == .dark ? Color(UIColor.systemGray4) : .clear, lineWidth: 0.5)
            )
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var fileIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(item.fileCategory.color.opacity(0.12))
                .frame(width: 48, height: 48)

            Image(systemName: item.fileCategory.iconName)
                .font(.title3)
                .foregroundColor(item.fileCategory.color)
        }
    }

    @ViewBuilder
    private var fileInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            metadataLine

            tagsOrStatusLine
        }
    }

    @ViewBuilder
    private var metadataLine: some View {
        HStack(spacing: 4) {
            Text(item.fileCategory.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("·")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(item.formattedSize)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("·")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(Formatters.shortDate.string(from: item.importDate))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var tagsOrStatusLine: some View {
        HStack(spacing: 5) {
            // Case 13: Always prominently display missing/unreadable status badge
            if item.availabilityStatus != .available {
                HStack(spacing: 3) {
                    Circle()
                        .fill(item.availabilityStatus.color)
                        .frame(width: 6, height: 6)
                    Text(item.availabilityStatus.displayName)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(item.availabilityStatus.color)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(item.availabilityStatus.color.opacity(0.15))
                .cornerRadius(6)
            }

            ForEach(item.safeTags.prefix(2)) { tag in
                Text(tag.name)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tag.color.opacity(0.12))
                    .foregroundColor(tag.color)
                    .cornerRadius(8)
            }
            if item.safeTags.count > 2 {
                Text("+\(item.safeTags.count - 2)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if item.safeTags.isEmpty && item.availabilityStatus == .available {
                statusBadge
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(item.availabilityStatus.color)
                .frame(width: 6, height: 6)
            Text(item.availabilityStatus.displayName)
                .font(.caption2)
                .foregroundColor(item.availabilityStatus.color)
        }
    }

    @ViewBuilder
    private var menuButton: some View {
        Menu {
            Button {
                onTap()
            } label: {
                Label("View Details", systemImage: "info.circle")
            }

            Button(role: .destructive) {
                onDelete(false)
            } label: {
                Label("Remove from Archive", systemImage: "trash")
            }

            Button(role: .destructive) {
                onDelete(true)
            } label: {
                Label("Delete Record & File", systemImage: "trash.fill")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.indigo : Color(UIColor.systemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color(UIColor.systemGray4), lineWidth: 1)
                )
        }
    }
}

// MARK: - Active Filter Badge

struct ActiveFilterBadge: View {
    let title: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Button(action: onRemove) {
                Image(systemName: "xmark")
            }
        }
        .font(.caption2)
        .bold()
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(8)
    }
}

// MARK: - Empty Archive

struct EmptyArchiveView: View {
    let onImport: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var isGenerating: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "archivebox")
                .font(.system(size: 64))
                .foregroundColor(.indigo)

            Text("Your Archive is Empty")
                .font(.title2)
                .bold()

            Text("Import files from your device or generate sample files to get started.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            VStack(spacing: 12) {
                Button {
                    onImport()
                } label: {
                    Label("Import Files", systemImage: "plus.circle.fill")
                        .frame(maxWidth: 240)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)

                Button {
                    isGenerating = true
                    Task {
                        try? await SampleDataGenerator.shared.generateAndImportSampleData(modelContext: modelContext)
                        isGenerating = false
                    }
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .padding(.trailing, 4)
                        }
                        Label("Generate Samples", systemImage: "sparkles")
                    }
                    .frame(maxWidth: 240)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .disabled(isGenerating)
            }

            Spacer()
        }
        .padding()
        .padding(.bottom, 50)
    }
}

// MARK: - Import Issues Details Sheet (Case 2)

struct ImportIssuesSheetView: View {
    let result: ImportResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    HStack {
                        Text("Successfully Imported")
                        Spacer()
                        Text("\(result.successfulCount)")
                            .bold()
                            .foregroundColor(.green)
                    }
                    HStack {
                        Text("Failed Files")
                        Spacer()
                        Text("\(result.failedCount)")
                            .bold()
                            .foregroundColor(.red)
                    }
                    if result.duplicateCount > 0 {
                        HStack {
                            Text("Duplicates Skipped")
                            Spacer()
                            Text("\(result.duplicateCount)")
                                .bold()
                                .foregroundColor(.orange)
                        }
                    }
                }

                if !result.errors.isEmpty {
                    Section("Issue Details") {
                        ForEach(result.errors, id: \.self) { error in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Import Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
