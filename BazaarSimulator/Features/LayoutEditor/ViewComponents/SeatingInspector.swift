import SwiftUI

/// A seating block holds one chair per standard seat pitch, so its rows and seats per row set its size.
struct SeatingInspector: View {
    @Binding var draft: InspectorDraft
    var titleIssues: [String] = []

    private static let seatRange = 1...60

    private var seatsPerRow: Binding<Int> {
        Binding(
            get: { FurnitureModels.seatsAlong(draft.widthM) },
            set: { draft.widthM = Double($0) * FurnitureModels.seatPitchM }
        )
    }

    private var rows: Binding<Int> {
        Binding(
            get: { FurnitureModels.seatsAlong(draft.lengthM) },
            set: { draft.lengthM = Double($0) * FurnitureModels.seatPitchM }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            TitleIssues(issues: titleIssues)

            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Seating")
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Palette.textPrimary)
                Picker("Seating", selection: .constant(FurnitureModels.seatingBlockID)) {
                    Text("Audience Seating").tag(FurnitureModels.seatingBlockID)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: Spacing.s) {
                Stepper("Rows: \(rows.wrappedValue)", value: rows, in: Self.seatRange)
                Stepper("Seats per row: \(seatsPerRow.wrappedValue)", value: seatsPerRow, in: Self.seatRange)
                Text("\(rows.wrappedValue * seatsPerRow.wrappedValue) seats")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .font(Typography.body)
            .foregroundStyle(Palette.textPrimary)

            RotationControl(degrees: $draft.rotationDegrees, stepDegrees: LayoutObjectKind.seating.rotationStepDegrees)
        }
    }
}
