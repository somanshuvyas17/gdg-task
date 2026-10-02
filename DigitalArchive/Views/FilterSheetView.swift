import SwiftUI
import SwiftData

public struct FilterSheetView: View {
    @ObservedObject var viewModel: ArchiveListViewModel
    @Query(sort: \ArchiveTag.name) private var tags: [ArchiveTag]
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: ArchiveListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Sort Order
                Section("Sort By") {
                    Picker("Order", selection: $viewModel.sortOption) {
                        ForEach(ArchiveSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Section 2: File Category
                Section("File Type") {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        ForEach(FileCategory.allCases) { category in
                            Label(category.displayName, systemImage: category.iconName)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Section 3: Availability Status
                Section("Availability Status") {
                    Picker("Status", selection: $viewModel.selectedStatus) {
                        Text("All Statuses").tag(ArchiveStatus?.none)
                        ForEach(ArchiveStatus.allCases, id: \.self) { status in
                            Label(status.displayName, systemImage: status.iconName)
                                .tag(ArchiveStatus?.some(status))
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Section 4: Tags
                Section("Filter By Tag") {
                    Picker("Tag", selection: $viewModel.selectedTag) {
                        Text("All Tags").tag(ArchiveTag?.none)
                        ForEach(tags) { tag in
                            HStack {
                                Circle()
                                    .fill(tag.color)
                                    .frame(width: 8, height: 8)
                                Text(tag.name)
                            }
                            .tag(ArchiveTag?.some(tag))
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Section 5: File Size Range
                Section("File Size") {
                    Picker("Size Range", selection: $viewModel.sizeFilter) {
                        ForEach(SizeFilterPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Section 6: Date Range
                Section("Import Date") {
                    Picker("Date Added", selection: $viewModel.dateFilter) {
                        ForEach(DateFilterPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Section 7: Actions
                Section {
                    Button(role: .destructive) {
                        viewModel.resetFilters()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset All Filters")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
