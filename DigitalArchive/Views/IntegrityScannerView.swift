import SwiftUI
import SwiftData

public struct IntegrityScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ArchiveItem]
    @StateObject private var scanner = IntegrityScanner.shared

    @State private var selectedItemToRelink: ArchiveItem? = nil
    @State private var isRelinkPickerPresented: Bool = false

    public init() {}

    private var availableCount: Int {
        allItems.filter { $0.availabilityStatus == .available }.count
    }

    private var missingItems: [ArchiveItem] {
        allItems.filter { $0.availabilityStatus == .missing }
    }

    private var totalBytes: Int64 {
        ArchiveStorageManager.shared.totalArchiveSizeBytes()
    }

    private var healthPercentage: Double {
        guard !allItems.isEmpty else { return 100.0 }
        return (Double(availableCount) / Double(allItems.count)) * 100.0
    }

    public var body: some View {
        NavigationStack {
            List {
                // Section 1: Health Summary Card
                Section {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Archive Health")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                Text(String(format: "%.0f%%", healthPercentage))
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                    .foregroundColor(healthPercentage == 100 ? .green : (healthPercentage > 75 ? .orange : .red))
                            }

                            Spacer()

                            Image(systemName: healthPercentage == 100 ? "shield.checkerboard" : "exclamationmark.shield.fill")
                                .font(.system(size: 50))
                                .foregroundColor(healthPercentage == 100 ? .green : .red)
                        }

                        // Progress bar
                        ProgressView(value: healthPercentage, total: 100.0)
                            .tint(healthPercentage == 100 ? .green : .red)

                        // 3 Column Metrics
                        HStack(spacing: 12) {
                            MetricBox(title: "Total Files", value: "\(allItems.count)", color: .primary)
                            MetricBox(title: "Available", value: "\(availableCount)", color: .green)
                            MetricBox(title: "Missing", value: "\(missingItems.count)", color: missingItems.isEmpty ? .secondary : .red)
                        }

                        // Storage Size
                        HStack {
                            Label("Physical Disk Usage", systemImage: "internaldrive.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(Formatters.formattedByteCount(totalBytes))
                                .font(.caption)
                                .bold()
                        }
                        .padding(.top, 4)

                        // Run Audit Button
                        Button {
                            Task {
                                _ = await scanner.scanArchive(modelContext: modelContext)
                            }
                        } label: {
                            HStack {
                                if scanner.isScanning {
                                    ProgressView()
                                        .tint(.white)
                                        .padding(.trailing, 6)
                                    Text("Auditing Filesystem...")
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Run Integrity Audit")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(scanner.isScanning)
                    }
                    .padding(.vertical, 8)
                }

                // Section 2: Missing Files Action List
                if !missingItems.isEmpty {
                    Section("Missing Files Requiring Attention (\(missingItems.count))") {
                        ForEach(missingItems) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)

                                    VStack(alignment: .leading) {
                                        Text(item.title)
                                            .font(.headline)
                                        Text(item.originalFileName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Button("Relink") {
                                        selectedItemToRelink = item
                                        isRelinkPickerPresented = true
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.blue)
                                }

                                Text("Path: \(item.relativeFilePath)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(.bottom, 60)
            .navigationTitle("Integrity & Health")
            .fileImporter(
                isPresented: $isRelinkPickerPresented,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                handleRelink(result: result)
            }
            .task {
                _ = await scanner.scanArchive(modelContext: modelContext)
            }
        }
    }

    private func handleRelink(result: Result<[URL], Error>) {
        guard let item = selectedItemToRelink else { return }
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                try ArchiveStorageManager.shared.relinkFile(relativePath: item.relativeFilePath, newSourceURL: url)
                _ = scanner.verifySingleItem(item, modelContext: modelContext)
            } catch {
                print("Failed to relink: \(error)")
            }
        case .failure(let error):
            print("Picker error: \(error)")
        }
        selectedItemToRelink = nil
    }
}

struct MetricBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .bold()
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }
}
