import SwiftUI

struct LibraryPanel: View {
    let rows: [LibraryRowDisplay]
    @Binding var searchText: String
    let onSelect: (LibraryRowDisplay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            TextField("Search library", text: $searchText)
                .textFieldStyle(FieldOnSurfaceStyle())

            if rows.isEmpty {
                Text("No items found")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, Spacing.m)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.m) {
                        ForEach(rows) { row in
                            LibraryRow(row: row) {
                                onSelect(row)
                            }
                        }
                    }
                }
            }
        }
    }
}
