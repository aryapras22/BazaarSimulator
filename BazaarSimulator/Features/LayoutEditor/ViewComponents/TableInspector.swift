import SwiftUI

/// A table is one of the standard models. Its size and seats come from the model, so only the model and angle
/// are edited.
struct TableInspector: View {
    @Binding var draft: InspectorDraft
    var titleIssues: [String] = []

    private var model: TableModel {
        FurnitureModels.table(draft.catalogID) ?? FurnitureModels.tables[1]
    }

    private var modelID: Binding<String> {
        Binding(
            get: { model.id },
            set: { id in
                guard let chosen = FurnitureModels.table(id) else { return }
                draft.catalogID = chosen.id
                draft.widthM = chosen.sizeM.x
                draft.lengthM = chosen.sizeM.y
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            TitleIssues(issues: titleIssues)

            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Type")
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Palette.textPrimary)
                Picker("Type", selection: modelID) {
                    ForEach(FurnitureModels.tables, id: \.id) { table in
                        Text(table.name).tag(table.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(model.seatCount) seats · \(DimensionInput.text(for: model.sizeM.x)) × "
                    + "\(DimensionInput.text(for: model.sizeM.y)) m")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            RotationControl(degrees: $draft.rotationDegrees, stepDegrees: LayoutObjectKind.table.rotationStepDegrees)
        }
    }
}

struct TitleIssues: View {
    let issues: [String]

    var body: some View {
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(issues, id: \.self) { issue in
                    Text(issue)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.destructive)
                }
            }
        }
    }
}
