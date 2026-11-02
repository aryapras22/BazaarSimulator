import SwiftUI

struct BoothInspector: View {
    @Binding var draft: InspectorDraft
    let categories: [CategoryOption]
    let sizeRange: ClosedRange<Double>
    var titleIssues: [String] = []
    var openSideIssues: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            if !titleIssues.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(titleIssues, id: \.self) { issue in
                        Text(issue)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.destructive)
                    }
                }
            }

            categoryPicker

            SizeFields(
                width: $draft.widthM,
                length: $draft.lengthM,
                range: sizeRange
            )

            RotationControl(degrees: $draft.rotationDegrees)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                OpenSidesControl(
                    sides: $draft.openSides,
                    rotationDegrees: draft.rotationDegrees
                )

                ForEach(openSideIssues, id: \.self) { issue in
                    Text(issue)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.destructive)
                }
            }
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Category")
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textPrimary)

            Menu {
                ForEach(categories) { option in
                    Button {
                        draft.categoryID = option.id
                    } label: {
                        HStack {
                            Text(option.name)
                            if draft.categoryID == option.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedCategoryName)
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xs + 2)
                .background(
                    RoundedRectangle(cornerRadius: Radius.s)
                        .fill(Palette.fieldOnSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.s)
                        .stroke(Palette.fieldOnSurfaceBorder, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
        }
    }

    private var selectedCategoryName: String {
        categories.first { $0.id == draft.categoryID }?.name ?? "Unassigned"
    }
}

#Preview("Booth Inspector") {
    @Previewable @State var draft = InspectorDraft(
        object: LayoutObject(
            kind: .booth,
            label: "B7",
            placement: Placement(
                center: .init(8, 8),
                sizeM: .init(2, 2),
                rotationRadians: .pi / 2
            ),
            categoryID: PreviewLayouts.sampleLegend.entries.first?.id,
            openSides: [.right, .bottom]
        )
    )
    let options = [CategoryOption(id: nil, name: "Unassigned", color: nil)] +
        PreviewLayouts.sampleLegend.entries.map {
            CategoryOption(id: $0.id, name: $0.name, color: $0.color)
        }
    InspectorPanel(title: "Booth B-7") {
        BoothInspector(
            draft: $draft,
            categories: options,
            sizeRange: 0.5...50.0
        )
    } footer: {
        Button("Save Changes") {}
            .buttonStyle(InspectorSaveButtonStyle())
            .disabled(true)
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
