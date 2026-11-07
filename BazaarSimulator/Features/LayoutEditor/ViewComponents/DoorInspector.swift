import SwiftUI

struct DoorInspector: View {
    @Binding var draft: InspectorDraft
    let widthRange: ClosedRange<Double>
    let advice: DoorAdviceDisplay?
    let onUseAdvice: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            directionPicker

            SizeFields(
                width: $draft.widthM,
                length: $draft.lengthM,
                range: widthRange,
                showsSingleDimension: true,
                primaryTitle: "Width",
                detailText: nil
            )

            if let advice {
                CalloutCard(
                    message: advice.message,
                    actionTitle: advice.actionTitle,
                    action: onUseAdvice
                )
            }
        }
    }

    private var directionPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Direction")
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textPrimary)

            Picker("Direction", selection: $draft.doorDirection) {
                ForEach(DoorDirection.allCases, id: \.self) { direction in
                    Text(direction.displayName).tag(direction)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("Door Inspector With Tip") {
    @Previewable @State var draft = InspectorDraft(
        object: LayoutObject(
            kind: .door,
            label: "Door NW",
            placement: Placement(center: .init(10, 20), sizeM: .init(2, 0.4)),
            doorFlow: DoorFlow(direction: .both)
        )
    )
    let advice = DoorAdviceDisplay(
        message: "Door NE is already an exit. Most bazaars use one main entry. Make Door NW an entrance?",
        actionTitle: "Use \"Entrance\"",
        suggestedDirection: .entrance
    )
    InspectorPanel(title: "Door NW") {
        DoorInspector(
            draft: $draft,
            widthRange: 0.8...20.0,
            advice: advice,
            onUseAdvice: {}
        )
    } footer: {
        EmptyView()
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

#Preview("Door Inspector Without Tip") {
    @Previewable @State var draft = InspectorDraft(
        object: LayoutObject(
            kind: .door,
            label: "Door NW",
            placement: Placement(center: .init(10, 20), sizeM: .init(2, 0.4)),
            doorFlow: DoorFlow(direction: .entrance)
        )
    )
    InspectorPanel(title: "Door NW") {
        DoorInspector(
            draft: $draft,
            widthRange: 0.8...20.0,
            advice: nil,
            onUseAdvice: {}
        )
    } footer: {
        EmptyView()
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
