import SwiftUI

struct BoothInspector: View {
    @Binding var draft: InspectorDraft
    let categories: [CategoryOption]
    let sizeRange: ClosedRange<Double>
    var titleIssues: [String] = []
    var openSideIssues: [String] = []
    var groupActions: BoothGroupActions?

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

            if let groupActions {
                groupSection(groupActions)
            }

            SizeFields(
                width: $draft.widthM,
                length: $draft.lengthM,
                range: sizeRange
            )

            HeightField(height: $draft.heightM)

            AttractivenessField(value: $draft.attractiveness)

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
        CategoryPicker(
            categories: categories,
            title: categories.first { $0.id == draft.boothType }?.name ?? "Unassigned",
            currentChoice: draft.categoryChoice,
            onSelect: { draft.choose($0) }
        )
    }

    private func groupSection(_ actions: BoothGroupActions) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Group")
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textPrimary)
            groupButton(actions.nameTitle, action: actions.onSelectName)
            groupButton(actions.sizeTitle, action: actions.onSelectSize)
        }
    }

    private func groupButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(Typography.body)
            .foregroundStyle(Palette.accentText)
    }
}

struct BoothGroupActions {
    let nameTitle: String
    let sizeTitle: String
    let onSelectName: () -> Void
    let onSelectSize: () -> Void
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
            boothType: .fnb,
            openSides: [.right, .bottom]
        )
    )
    InspectorPanel(title: "Booth B-7") {
        BoothInspector(
            draft: $draft,
            categories: CategoryOption.boothOptions,
            sizeRange: 0.5...50.0,
            groupActions: BoothGroupActions(
                nameTitle: "Select group B · 30",
                sizeTitle: "Select size 2 × 2 m · 91",
                onSelectName: {},
                onSelectSize: {}
            )
        )
    } footer: {
        EmptyView()
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
