import SwiftUI

struct GroupInspector: View {
    @Binding var draft: GroupInspectorDraft
    let display: GroupInspectorDisplay
    let categories: [CategoryOption]
    let sizeRange: ClosedRange<Double>
    let onResetOpenSides: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            if let warning = display.warningSummary {
                Text(warning)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.destructive)
            }

            if display.boothCount > 0 {
                CategoryPicker(
                    categories: categories,
                    entertainmentTypes: [],
                    title: categoryTitle,
                    currentChoice: currentCategoryChoice,
                    onSelect: { choice in
                        if case .booth(let id) = choice {
                            draft.category = .set(id)
                        }
                    }
                )
            }

            if display.furnitureCount > 0 {
                FurnitureTypePicker(
                    selectedID: sharedFurnitureTypeID,
                    onSelect: { draft.furnitureType = .set($0) }
                )
            }

            GroupSizeFields(draft: $draft, width: display.width, length: display.length, range: sizeRange)

            RotationControl(degrees: rotationBinding, isMixed: display.rotation == .mixed)

            if display.boothCount > 0 {
                Button("Reset open sides for \(display.boothCount) booths", action: onResetOpenSides)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var currentCategoryChoice: CategoryChoice? {
        guard case .shared(let shared) = display.category else { return nil }
        return .booth(shared)
    }

    private var sharedFurnitureTypeID: String? {
        guard case .shared(let shared) = display.furnitureType else { return nil }
        return shared
    }

    private var categoryTitle: String {
        guard case .shared(let shared) = display.category else { return "Mixed" }
        return categories.first { $0.id == shared }?.name ?? "Unassigned"
    }

    private var rotationBinding: Binding<Int> {
        Binding(
            get: {
                if case .shared(let degrees) = display.rotation { return degrees }
                return 0
            },
            set: { draft.rotationDegrees = .set($0) }
        )
    }
}

#Preview("Group inspector: shared and mixed values") {
    @Previewable @State var sharedDraft = GroupInspectorDraft(memberIDs: [])
    @Previewable @State var mixedDraft = GroupInspectorDraft(memberIDs: [])
    let options = CategoryOption.boothOptions
    HStack(alignment: .top, spacing: Spacing.l) {
        InspectorPanel(title: "Group A · 112 booths") {
            GroupInspector(
                draft: $sharedDraft,
                display: GroupInspectorDisplay(
                    category: .shared(.fnb),
                    width: .shared(2.5),
                    length: .shared(2.5),
                    rotation: .shared(0),
                    warningSummary: "3 booths have warnings",
                    memberCount: 112
                ),
                categories: options,
                sizeRange: 0.5...100,
                onResetOpenSides: {}
            )
        } footer: {
            EmptyView()
        }
        InspectorPanel(title: "12 booths") {
            GroupInspector(
                draft: $mixedDraft,
                display: GroupInspectorDisplay(
                    category: .mixed,
                    width: .mixed,
                    length: .shared(2.5),
                    rotation: .mixed,
                    warningSummary: nil,
                    memberCount: 12
                ),
                categories: options,
                sizeRange: 0.5...100,
                onResetOpenSides: {}
            )
        } footer: {
            EmptyView()
        }
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
