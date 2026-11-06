import SwiftUI

struct ViewPresetPicker: View {
    @Binding var selection: ViewPreset
    var onSelect: (ViewPreset) -> Void
    var showsBackground = true

    var body: some View {
        SegmentedTabs(
            selection: Binding(
                get: { selection },
                set: { newPreset in
                    selection = newPreset
                    onSelect(newPreset)
                }
            ),
            tabs: ViewPreset.allCases,
            title: \.title,
            showsBackground: showsBackground
        )
    }
}
