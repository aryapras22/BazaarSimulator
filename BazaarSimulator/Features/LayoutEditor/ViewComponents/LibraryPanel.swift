import SwiftUI

struct LibraryPanel: View {
    let layer: EditorLayer
    let rows: [LibraryRowDisplay]
    @Binding var searchText: String
    @Binding var selectedCategory: CatalogCategory?
    let onSelect: (LibraryRowDisplay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            TextField("Search library", text: $searchText)
                .textFieldStyle(FieldOnSurfaceStyle())

            categoryChips

            if rows.isEmpty {
                Text("No items found")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, Spacing.m)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.m) {
                        ForEach(categoriesWithRows, id: \.self) { category in
                            Section {
                                ForEach(rows(for: category)) { row in
                                    LibraryRow(row: row) {
                                        onSelect(row)
                                    }
                                }
                            } header: {
                                Text(category.title)
                                    .font(Typography.inspectorLabel)
                                    .foregroundStyle(Palette.textSecondary)
                                    .padding(.top, Spacing.xs)
                            }
                        }
                    }
                }
            }
        }
    }

    private var availableCategories: [CatalogCategory] {
        CatalogCategory.categories(for: layer)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                chipButton(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(availableCategories, id: \.self) { category in
                    chipButton(title: category.title, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    private func chipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(isSelected ? Palette.textPrimary : Palette.textSecondary)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(isSelected ? Palette.segmentedSelected : Palette.surface)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Palette.highlight : Palette.surfaceBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var categoriesWithRows: [CatalogCategory] {
        availableCategories.filter { category in
            rows.contains { $0.category == category }
        }
    }

    private func rows(for category: CatalogCategory) -> [LibraryRowDisplay] {
        rows.filter { $0.category == category }
    }
}
