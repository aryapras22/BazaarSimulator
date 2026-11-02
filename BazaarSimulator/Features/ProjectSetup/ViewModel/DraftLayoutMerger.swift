import Foundation

enum DraftLayoutMerger {
    /// Keeps the existing (possibly edited) layout for every imported layout whose ID is unchanged,
    /// adds new ones, drops ones whose file was removed, and clears category IDs not in the legend.
    static func merged(imported: [Layout], existing: [Layout], legend: Legend) -> [Layout] {
        let validCategoryIDs = Set(legend.entries.map(\.id))
        return imported.map { importedLayout in
            var layout = existing.first { $0.id == importedLayout.id } ?? importedLayout
            for index in layout.objects.indices {
                if let categoryID = layout.objects[index].categoryID, !validCategoryIDs.contains(categoryID) {
                    layout.objects[index].categoryID = nil
                }
            }
            return layout
        }
    }
}
