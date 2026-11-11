import SwiftUI

struct ImportLogPanel: View {
    let entries: [ImportLogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("IMPORT LOG")
                .sectionLabel()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.xs) {
                        if entries.isEmpty {
                            Text("Add a legend or floor plan to see each step here.")
                                .font(Typography.logLine)
                                .foregroundColor(Palette.textTertiary)
                        }

                        ForEach(entries) { entry in
                            logLine(entry)
                                .id(entry.id)
                        }
                    }
                    .textSelection(.enabled)
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: entries.last?.id, initial: true) { _, lastID in
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
            .frame(height: 180)
            .card()
        }
    }

    private func logLine(_ entry: ImportLogEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Text(entry.date.formatted(date: .omitted, time: .standard))
                .foregroundColor(Palette.textTertiary)

            Text(entry.fileName)
                .foregroundColor(Palette.accentText)

            Text(entry.message)
                .foregroundColor(entry.severity == .failure ? Palette.destructive : Palette.textPrimary)
        }
        .font(Typography.logLine)
    }
}
