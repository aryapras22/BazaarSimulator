import SwiftUI

struct InspectorFields: Sendable {
    var showsLabel: Bool
    var showsSingleDimension: Bool
    var primarySizeTitle: String
    var sizeDetailText: String?
    var showsRotation: Bool
    var showsHeight: Bool
    var showsShape: Bool
    var showsOpenSides: Bool
    var showsAttractiveness: Bool
    var showsEntertainmentType: Bool

    static func forObject(_ object: LayoutObject) -> InspectorFields {
        switch object.kind {
        case .wall:
            return InspectorFields(sizeDetailText: "(length x thickness)", showsRotation: true, showsHeight: true)
        case .block:
            return InspectorFields(
                showsLabel: !object.isColumn,
                sizeDetailText: "(length x thickness)",
                showsRotation: true,
                showsHeight: true,
                showsShape: true
            )
        case .closedArea:
            return InspectorFields(showsLabel: true, showsRotation: true, showsShape: true)
        case .entertainment:
            return InspectorFields(
                showsLabel: true,
                showsRotation: true,
                showsHeight: true,
                showsOpenSides: true,
                showsAttractiveness: true,
                showsEntertainmentType: true
            )
        case .booth, .door, .table, .seating:
            return InspectorFields()
        }
    }

    init(
        showsLabel: Bool = false,
        showsSingleDimension: Bool = false,
        primarySizeTitle: String = "Size",
        sizeDetailText: String? = "(width x length)",
        showsRotation: Bool = false,
        showsHeight: Bool = false,
        showsShape: Bool = false,
        showsOpenSides: Bool = false,
        showsAttractiveness: Bool = false,
        showsEntertainmentType: Bool = false
    ) {
        self.showsLabel = showsLabel
        self.showsSingleDimension = showsSingleDimension
        self.primarySizeTitle = primarySizeTitle
        self.sizeDetailText = sizeDetailText
        self.showsRotation = showsRotation
        self.showsHeight = showsHeight
        self.showsShape = showsShape
        self.showsOpenSides = showsOpenSides
        self.showsAttractiveness = showsAttractiveness
        self.showsEntertainmentType = showsEntertainmentType
    }
}

struct GenericInspector: View {
    @Binding var draft: InspectorDraft
    let fields: InspectorFields
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

            if fields.showsLabel {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Label")
                        .font(Typography.inspectorLabel)
                        .foregroundStyle(Palette.textPrimary)

                    TextField("Label", text: $draft.label)
                        .textFieldStyle(FieldOnSurfaceStyle())
                }
            }

            if fields.showsEntertainmentType {
                entertainmentTypePicker
            }

            if fields.showsShape {
                shapePicker
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

            if fields.showsAttractiveness {
                AttractivenessField(value: $draft.attractiveness)
            }

            if fields.showsOpenSides {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    OpenSidesControl(sides: $draft.openSides, rotationDegrees: draft.rotationDegrees)
                    ForEach(openSideIssues, id: \.self) { issue in
                        Text(issue)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.destructive)
                    }
                }
            }
        }
    }

    private var entertainmentTypePicker: some View {
        let type = Binding<EntertainmentType>(
            get: { EntertainmentType.resolve(catalogID: draft.catalogID, label: draft.label) },
            set: { draft.catalogID = $0.catalogID }
        )
        return VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Type")
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textPrimary)

            Picker("Type", selection: type) {
                ForEach(EntertainmentType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var shapePicker: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Shape")
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textPrimary)

            Picker("Shape", selection: $draft.shape) {
                ForEach(FootprintShape.allCases, id: \.self) { shape in
                    Text(shape.displayName).tag(shape)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .help("A round shape fills the width and length as an oval; equal sides make a circle")
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
            fields: .forObject(LayoutObject(kind: .block, label: draft.label, placement: Placement(
                center: .init(10, 10),
                sizeM: .init(4, 2)
            ))),
            sizeRange: 0.1...50.0
        )
    } footer: {
        EmptyView()
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
