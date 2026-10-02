import Foundation
import SwiftUI
import PDFKit
import QuickLook

public struct FilePreviewView: View {
    let item: ArchiveItem
    @Environment(\.dismiss) private var dismiss
    @State private var textContent: String? = nil
    @State private var isLoadingText: Bool = false
    @State private var isSharePresented: Bool = false

    private var fileURL: URL {
        ArchiveStorageManager.shared.fileURL(for: item.relativeFilePath)
    }

    private var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    public init(item: ArchiveItem) {
        self.item = item
    }

    public var body: some View {
        NavigationStack {
            Group {
                if !fileExists || item.availabilityStatus == .missing {
                    MissingFilePlaceholder(item: item)
                } else if item.availabilityStatus == .unreadable {
                    UnreadableFilePlaceholder(item: item)
                } else {
                    switch item.fileCategory {
                    case .image:
                        ZoomableImageView(url: fileURL)
                    case .pdf:
                        PDFKitRepresentedView(url: fileURL)
                    case .document:
                        if isLoadingText {
                            ProgressView("Loading document...")
                        } else if let content = textContent {
                            ScrollView {
                                Text(content)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            DocumentFallbackView(item: item, fileURL: fileURL)
                        }
                    default:
                        DocumentFallbackView(item: item, fileURL: fileURL)
                    }
                }
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if fileExists {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isSharePresented = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $isSharePresented) {
                ShareSheet(items: [fileURL])
            }
            .task {
                if fileExists && item.fileCategory == .document {
                    loadTextContent()
                }
            }
        }
    }

    private func loadTextContent() {
        isLoadingText = true
        DispatchQueue.global(qos: .userInitiated).async {
            // Read up to 2MB text for preview
            if let handle = try? FileHandle(forReadingFrom: fileURL) {
                let data = handle.readData(ofLength: 2 * 1024 * 1024)
                try? handle.close()
                let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
                DispatchQueue.main.async {
                    self.textContent = string
                    self.isLoadingText = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoadingText = false
                }
            }
        }
    }
}

// PDFKit UIViewControllerRepresentable
struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}

// Zoomable Image View
struct ZoomableImageView: View {
    let url: URL
    @State private var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { proxy in
            if let uiImage = UIImage(contentsOfFile: url.path) {
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width * max(scale, 1.0), height: proxy.size.height * max(scale, 1.0))
                }
            } else {
                ContentUnavailableView("Unable to load image", systemImage: "photo")
            }
        }
    }
}

// Fallback Document View
struct DocumentFallbackView: View {
    let item: ArchiveItem
    let fileURL: URL

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: item.fileCategory.iconName)
                .font(.system(size: 64))
                .foregroundColor(item.fileCategory.color)

            Text(item.title)
                .font(.title2)
                .bold()

            Text("Format: \(item.fileExtension.uppercased()) • \(item.formattedSize)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ShareLink(item: fileURL) {
                Label("Export / Open In...", systemImage: "square.and.arrow.up")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

// Missing File Warning Placeholder
struct MissingFilePlaceholder: View {
    let item: ArchiveItem

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("File Unavailable on Disk")
                .font(.title2)
                .bold()

            Text("The physical file '\(item.originalFileName)' was deleted or moved from storage. All metadata, tags, and checksums remain safely preserved in the database.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Expected Path:")
                        .bold()
                    Text(item.relativeFilePath)
                }
                .font(.caption)
                .foregroundColor(.secondary)

                HStack {
                    Text("SHA-256 Hash:")
                        .bold()
                    Text(item.sha256Hash.prefix(16) + "...")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 24)
        }
        .padding()
    }
}

// Unreadable File Warning Placeholder (Case 5)
struct UnreadableFilePlaceholder: View {
    let item: ArchiveItem

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Unable to Open File")
                .font(.title2)
                .bold()

            Text("The file '\(item.originalFileName)' exists on disk but cannot be accessed or opened by the system. All database metadata, tags, and checksums remain safely preserved.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Storage Path:")
                        .bold()
                    Text(item.relativeFilePath)
                }
                .font(.caption)
                .foregroundColor(.secondary)

                HStack {
                    Text("SHA-256 Hash:")
                        .bold()
                    Text(item.sha256Hash.prefix(16) + "...")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 24)
        }
        .padding()
    }
}

// UIActivityViewController wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiView: UIActivityViewController, context: Context) {}
}
