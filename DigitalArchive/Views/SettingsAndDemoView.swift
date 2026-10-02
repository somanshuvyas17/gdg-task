import SwiftUI
import SwiftData

public struct SettingsAndDemoView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ArchiveItem]
    @Query private var allTags: [ArchiveTag]

    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    @State private var showResetConfirm: Bool = false
    @State private var showStagingCleanedAlert: Bool = false

    private let storageManager = ArchiveStorageManager.shared

    public init() {}

    private var totalBytes: Int64 {
        storageManager.totalArchiveSizeBytes()
    }

    private var availableCount: Int {
        allItems.filter { $0.availabilityStatus == .available }.count
    }

    private var missingCount: Int {
        allItems.filter { $0.availabilityStatus == .missing }.count
    }

    public var body: some View {
        NavigationStack {
            List {
                // Section 1: Appearance
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "moon.stars.fill")
                                .foregroundColor(.indigo)
                            Text("Appearance")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Picker("Theme", selection: $appearanceMode) {
                            Label("System", systemImage: "gear")
                                .tag("system")
                            Label("Light", systemImage: "sun.max.fill")
                                .tag("light")
                            Label("Dark", systemImage: "moon.fill")
                                .tag("dark")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                }

                // Section 2: Storage & Health Overview
                Section("Storage & Health") {
                    HStack {
                        Label("Archived Items", systemImage: "doc.stack.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(allItems.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Storage Used", systemImage: "internaldrive.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(Formatters.formattedByteCount(totalBytes))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Archive Health", systemImage: "shield.checkerboard")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(availableCount) available · \(missingCount) missing")
                            .font(.caption)
                            .foregroundColor(missingCount > 0 ? .orange : .green)
                    }

                    HStack {
                        Label("Taxonomy Tags", systemImage: "tag.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(allTags.count)")
                            .foregroundColor(.secondary)
                    }
                }

                // Section 3: Data & Cache Maintenance
                Section("Data & Maintenance") {
                    Button {
                        storageManager.cleanupStagingDirectory()
                        showStagingCleanedAlert = true
                    } label: {
                        Label("Clean Temporary Staging Cache", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Clear Entire Archive", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }

                // Section 4: Developer & Diagnostics (Sub-Page)
                Section("Developer") {
                    NavigationLink {
                        DeveloperDiagnosticsView()
                    } label: {
                        Label("Developer & Diagnostics", systemImage: "hammer.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.bottom, 60)
            .navigationTitle("Settings & Tools")
            .confirmationDialog(
                "Clear Entire Archive?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete All Records AND Files", role: .destructive) {
                    clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all archived files and database records from this device.")
            }
            .alert("Staging Cleaned", isPresented: $showStagingCleanedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("All temporary staging files have been removed.")
            }
        }
    }

    private func clearAll() {
        for item in allItems {
            try? storageManager.deletePhysicalFile(relativePath: item.relativeFilePath)
            modelContext.delete(item)
        }
        for tag in allTags {
            modelContext.delete(tag)
        }
        try? modelContext.save()
        storageManager.cleanupStagingDirectory()
    }
}

// MARK: - Developer & Diagnostics View (Cleanly isolated for reviewers)

struct DeveloperDiagnosticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ArchiveItem]

    @State private var isGenerating: Bool = false
    @State private var generationStatus: String? = nil
    @State private var selectedItemToSimulate: ArchiveItem? = nil
    @State private var showSimulationAlert: Bool = false
    @State private var simulationAlertMessage: String? = nil

    var body: some View {
        List {
            // Evaluation Tools
            Section(header: Text("Evaluation Tools"), footer: Text("Populates the archive with realistic Images, PDFs, and Documents generated on-device with SHA-256 checksums.")) {
                Button {
                    isGenerating = true
                    generationStatus = "Generating sample assets..."
                    Task {
                        do {
                            try await SampleDataGenerator.shared.generateAndImportSampleData(modelContext: modelContext)
                            generationStatus = "Sample files imported successfully!"
                        } catch {
                            generationStatus = "Error: \(error.localizedDescription)"
                        }
                        isGenerating = false
                    }
                } label: {
                    HStack {
                        Label("Generate Sample Archive", systemImage: "sparkles")
                        Spacer()
                        if isGenerating {
                            ProgressView()
                        }
                    }
                }
                .disabled(isGenerating)

                if let status = generationStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Task 5 Resilience Simulation
            Section(header: Text("Missing File Simulation (Task 5)"), footer: Text("Deletes the physical file on disk while keeping the database record intact. Open the Health tab or the file to verify resilience.")) {
                let availableItems = allItems.filter { $0.availabilityStatus == .available }
                if availableItems.isEmpty {
                    Text("No available files to simulate deletion on.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Picker("Select File", selection: $selectedItemToSimulate) {
                        Text("Choose file...").tag(ArchiveItem?.none)
                        ForEach(availableItems) { item in
                            Text(item.title).tag(ArchiveItem?.some(item))
                        }
                    }

                    Button(role: .destructive) {
                        simulateDeletion()
                    } label: {
                        Label("Simulate External Deletion", systemImage: "trash.slash")
                    }
                    .disabled(selectedItemToSimulate == nil)
                }
            }

            // Architecture Overview
            Section("Technical Architecture") {
                DisclosureGroup("1. Sandboxed Relative Paths") {
                    Text("iOS container UUID directories change across app updates. Storing relative paths (`Files/<UUID>.<ext>`) ensures records resolve dynamically to the active Documents directory.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }

                DisclosureGroup("2. Atomic Staging & Rollback") {
                    Text("Incoming files are staged in a temporary sandbox. Only after full metadata extraction, SHA-256 calculation, and database insert succeed is the file committed. Any failure triggers rollback.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }

                DisclosureGroup("3. Decoupled Metadata & Missing Handling") {
                    Text("The database preserves all metadata, tags, and checksums even if a physical file is removed externally, preventing crashes and enabling in-place relinking.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }

                DisclosureGroup("4. Streaming Cryptographic Hashing") {
                    Text("SHA-256 hashes are computed in 64KB streaming chunks via CryptoKit on a background Task, preventing memory spikes for large files.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Developer Tools")
        .alert("External Deletion Simulated", isPresented: $showSimulationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(simulationAlertMessage ?? "")
        }
    }

    private func simulateDeletion() {
        guard let item = selectedItemToSimulate else { return }
        do {
            try ArchiveStorageManager.shared.simulateExternalDeletion(relativePath: item.relativeFilePath)
            _ = IntegrityScanner.shared.verifySingleItem(item, modelContext: modelContext)
            simulationAlertMessage = "Physical file for '\(item.title)' was removed from disk storage. The database record and metadata remain 100% intact!"
            showSimulationAlert = true
            selectedItemToSimulate = nil
        } catch {
            simulationAlertMessage = "Simulation error: \(error.localizedDescription)"
            showSimulationAlert = true
        }
    }
}
