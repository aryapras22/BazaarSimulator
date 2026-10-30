import SwiftUI

struct ContentView: View {
    @State private var booths: [Booth] = []
    @State private var loadError: String?

    var body: some View {
        Group {
            if let loadError {
                Text(loadError)
            } else {
                List(booths) { booth in
                    HStack {
                        Text(booth.id).monospaced()
                        Text(booth.name)
                        Spacer()
                        Text(booth.category).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task { loadBooths() }
    }

    private func loadBooths() {
        do {
            booths = try MockDataStore.load([Booth].self, from: "booths")
        } catch {
            loadError = "Could not load booths: \(error)"
        }
    }
}

#Preview {
    ContentView()
}
