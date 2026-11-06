import SwiftUI

struct InspectorFields: Sendable {
    var showsLabel: Bool
    var showsSingleDimension: Bool
    var primarySizeTitle: String
    var sizeDetailText: String?
    var showsRotation: Bool
    var showsHeight: Bool

    static func forKind(_ kind: LayoutObjectKind) -> InspectorFields {
        switch kind {
        case .wall, .block:
            return InspectorFields(sizeDetailText: "(length x thickness)", showsRotation: true, showsHeight: true)
        case .closedArea, .floor:
            return InspectorFields(showsLabel: true, showsRotation: true)
        case .booth, .door:
            return InspectorFields()
        }
    }

    init(
        showsLabel: Bool = false,
        showsSingleDimension: Bool = false,
        primarySizeTitle: String = "Size",
        sizeDetailText: String? = "(width x length)",
        showsRotation: Bool = false,
        showsHeight: Bool = false
    ) {
        self.showsLabel = showsLabel
        self.showsSingleDimension = showsSingleDimension
        self.primarySizeTitle = primarySizeTitle
        self.sizeDetailText = sizeDetailText
        self.showsRotation = showsRotation
        self.showsHeight = showsHeight
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

            if fields.showsHeight {
                HeightField(height: $draft.heightM)
            }
        }
    }
}

#Preview("Block Inspector") {
    @Previewable @State var draft = InspectorDraft(
        object: LayoutObject(
            kind: .block,
            label: "Block 1",
            placement: Placement(center: .init(10, 10), sizeM: .init(4, 2))
        )
    )
    InspectorPanel(title: "Block") {
        GenericInspector(
            draft: $draft,
            fields: .forKind(.block),
            sizeRange: 0.1...50.0
        )
    } footer: {
        Button("Save Changes") {}
            .buttonStyle(InspectorSaveButtonStyle())
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
