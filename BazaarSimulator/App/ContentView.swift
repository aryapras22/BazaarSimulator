import SwiftUI

struct ContentView: View {
    private static let layoutFiles = ["annyeong-market-layout", "beyond-market-layout"]

    @State private var selectedFile = ContentView.layoutFiles[0]
    @State private var layout: BazaarLayout?
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading) {
            Picker("Layout", selection: $selectedFile) {
                ForEach(Self.layoutFiles, id: \.self) { Text($0).tag($0) }
            }
            if let loadError {
                Text(loadError)
            } else if let layout {
                summary(of: layout)
                List(layout.booths) { booth in
                    HStack {
                        Text(booth.id).monospaced()
                        Text(booth.type).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(booth.w, specifier: "%.1f") x \(booth.h, specifier: "%.1f") m")
                    }
                }
            }
        }
        .padding()
        .task(id: selectedFile) { loadLayout() }
    }

    private func summary(of layout: BazaarLayout) -> some View {
        VStack(alignment: .leading) {
            Text(layout.meta.name).font(.headline)
            Text(layout.meta.sheet).foregroundStyle(.secondary)
            Text("\(layout.meta.world.w, specifier: "%.1f") x \(layout.meta.world.h, specifier: "%.1f") m")
            Text("\(layout.booths.count) booths, \(layout.tables.count) tables, \(layout.doors.count) doors")
        }
    }

    private func loadLayout() {
        do {
            layout = try MockDataStore.load(BazaarLayout.self, from: selectedFile)
            loadError = nil
        } catch {
            loadError = "Could not load \(selectedFile): \(error)"
        }
    }
}

#Preview {
    ContentView()
}
