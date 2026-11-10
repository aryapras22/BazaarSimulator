import SwiftUI

struct WallInspector: View {
    @Binding var draft: InspectorDraft
    let lengthRange: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SizeFields(
                width: $draft.widthM,
                length: $draft.lengthM,
                range: lengthRange,
                showsSingleDimension: true,
                primaryTitle: "Length",
                detailText: nil
            )

            RotationControl(degrees: $draft.rotationDegrees)
            HeightField(height: $draft.heightM)
        }
    }
}
