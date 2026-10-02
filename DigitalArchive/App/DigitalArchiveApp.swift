import SwiftUI
import SwiftData

@main
struct DigitalArchiveApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ArchiveItem.self,
            ArchiveTag.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Requirement 7: Clean up any staging artifacts on application launch
        ArchiveStorageManager.shared.cleanupStagingDirectory()
    }

    private var resolvedColorScheme: ColorScheme? {
        switch appearanceMode {
        case "dark": return .dark
        case "light": return .light
        default: return nil // system
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(resolvedColorScheme)
                .task {
                    // Clean up and merge any duplicate tags on launch
                    ArchiveTag.deduplicate(in: sharedModelContainer.mainContext)
                    
                    if CommandLine.arguments.contains("-generateSamples") {
                        try? await SampleDataGenerator.shared.generateAndImportSampleData(modelContext: sharedModelContainer.mainContext)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
