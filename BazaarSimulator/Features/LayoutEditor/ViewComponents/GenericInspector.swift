import SwiftUI

struct InspectorFields: Sendable {
    var showsLabel: Bool
    var showsSingleDimension: Bool
    var primarySizeTitle: String
    var sizeDetailText: String?
    var showsRotation: Bool
    var showsStageFront: Bool

    static func forKind(_ kind: LayoutObjectKind) -> InspectorFields {
        switch kind {
        case .table:
            return InspectorFields(showsRotation: true)
        case .fixture:
            return InspectorFields(showsLabel: true, showsRotation: true)
        case .stage:
            return InspectorFields(showsRotation: true, showsStageFront: true)
        case .audienceArea:
            return InspectorFields(showsLabel: true)
        case .wall, .rail, .block:
            return InspectorFields(sizeDetailText: "(length x thickness)", showsRotation: true)
        case .pillar:
            return InspectorFields(showsSingleDimension: true, primarySizeTitle: "Diameter", sizeDetailText: nil)
        case .booth, .door, .closedArea:
            return InspectorFields()
        }
    }

    init(
        showsLabel: Bool = false,
        showsSingleDimension: Bool = false,
        primarySizeTitle: String = "Size",
        sizeDetailText: String? = "(width x length)",
        showsRotation: Bool = false,
        showsStageFront: Bool = false
    ) {
        self.showsLabel = showsLabel
        self.showsSingleDimension = showsSingleDimension
        self.primarySizeTitle = primarySizeTitle
        self.sizeDetailText = sizeDetailText
        self.showsRotation = showsRotation
        self.showsStageFront = showsStageFront
    }
}

struct GenericInspector: View {
    @Binding var draft: InspectorDraft
    let fields: InspectorFields
    let sizeRange: ClosedRange<Double>
    var titleIssues: [String] = []

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

            if fields.showsLabel {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Label")
                        .font(Typography.inspectorLabel)
                        .foregroundStyle(Palette.textPrimary)

                    TextField("Label", text: $draft.label)
                        .textFieldStyle(FieldOnSurfaceStyle())
                }
            }

            SizeFields(
                width: $draft.widthM,
                length: $draft.lengthM,
                range: sizeRange,
                showsSingleDimension: fields.showsSingleDimension,
                primaryTitle: fields.primarySizeTitle,
                detailText: fields.sizeDetailText
            )

            if fields.showsRotation {
                RotationControl(degrees: $draft.rotationDegrees)
            }

            if fields.showsStageFront {
                OpenSidesControl(
                    sides: $draft.openSides,
                    rotationDegrees: draft.rotationDegrees,
                    allowsMultiple: false,
                    title: "Front"
                )
            }
        }
    }
}

#Preview("Table Inspector") {
    @Previewable @State var draft = InspectorDraft(
        object: LayoutObject(
            kind: .table,
            label: "T1",
            placement: Placement(center: .init(10, 10), sizeM: .init(1, 1))
        )
    )
    InspectorPanel(title: "Table T1") {
        GenericInspector(
            draft: $draft,
            fields: .forKind(.table),
            sizeRange: 0.5...50.0
        )
    } footer: {
        Button("Save Changes") {}
            .buttonStyle(InspectorSaveButtonStyle())
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

#Preview("Fixture Inspector") {
    @Previewable @State var draft = InspectorDraft(
        object: LayoutObject(
            kind: .fixture,
            label: "CLAW MACHINES",
            placement: Placement(center: .init(10, 10), sizeM: .init(4, 2))
        )
    )
    InspectorPanel(title: "CLAW MACHINES") {
        GenericInspector(
            draft: $draft,
            fields: .forKind(.fixture),
            sizeRange: 0.5...50.0
        )
    } footer: {
        Button("Save Changes") {}
            .buttonStyle(InspectorSaveButtonStyle())
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
