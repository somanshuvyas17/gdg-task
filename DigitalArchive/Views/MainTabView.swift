import SwiftUI
import SwiftData
import UniformTypeIdentifiers

public struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: Tab = .archive
    @State private var isFileImporterPresented = false
    
    enum Tab {
        case archive
        case categories
        case recent
        case settings
    }
    
    public init() {
        var initialTab: Tab = .archive
        if CommandLine.arguments.contains("-tagsTab") || UserDefaults.standard.bool(forKey: "tagsTab") {
            initialTab = .categories
        } else if CommandLine.arguments.contains("-healthTab") || UserDefaults.standard.bool(forKey: "healthTab") {
            initialTab = .recent
        } else if CommandLine.arguments.contains("-settingsTab") || UserDefaults.standard.bool(forKey: "settingsTab") {
            initialTab = .settings
        }
        _selectedTab = State(initialValue: initialTab)
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content Area
            Group {
                switch selectedTab {
                case .archive:
                    ArchiveListView()
                case .categories:
                    TagManagementView()
                case .recent:
                    IntegrityScannerView()
                case .settings:
                    SettingsAndDemoView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom Tab Bar
            customTabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.item, .image, .pdf, .text, .movie, .audio],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result: result)
        }
    }
    
    @ViewBuilder
    private var customTabBar: some View {
        HStack {
            tabBarItem(icon: "archivebox.fill", title: "Archive", tab: .archive)
            Spacer()
            tabBarItem(icon: "doc.on.doc.fill", title: "Categories", tab: .categories)
            Spacer()
            
            // Center FAB
            Button {
                isFileImporterPresented = true
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.purple, .indigo]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: .indigo.opacity(0.4), radius: 5, x: 0, y: 3)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -16)
            
            Spacer()
            tabBarItem(icon: "clock.arrow.circlepath", title: "Recent", tab: .recent)
            Spacer()
            tabBarItem(icon: "gearshape.fill", title: "Settings", tab: .settings)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            Color(UIColor.systemBackground)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Divider()
                .opacity(colorScheme == .dark ? 1 : 0)
        }
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.06), radius: 8, x: 0, y: -4)
    }
    
    private func tabBarItem(icon: String, title: String, tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(selectedTab == tab ? .indigo : .gray)
            .frame(width: 60)
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            Task {
                _ = await ImportManager.shared.importFiles(
                    from: urls,
                    modelContext: modelContext,
                    allowDuplicates: false
                )
            }
        case .failure(let error):
            print("Import selection error: \(error.localizedDescription)")
        }
    }
}
