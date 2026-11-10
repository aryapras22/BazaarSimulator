import SwiftUI
import simd

#Preview("Annyeong Floor Plan") {
    @Previewable @State var transform = CanvasTransform.fitting(
        layoutSize: PreviewLayouts.annyeong().sizeM,
        in: SIMD2<Double>(900, 650)
    )
    @Previewable @FocusState var isFocused: Bool
    let layout = PreviewLayouts.annyeong()
    LayoutCanvasView(
        snapshot: CanvasDisplaySnapshot(
            layout: layout,
            legend: PreviewLayouts.sampleLegend,
            activeLayer: .booths,
            selectionID: layout.objects.first { $0.kind == .booth }?.id
        ),
        transform: $transform,
        isFocused: $isFocused
    )
    .frame(width: 900, height: 650)
    .preferredColorScheme(.dark)
}

#Preview("Beyond Visitor Flow") {
    @Previewable @State var transform = CanvasTransform.fitting(
        layoutSize: PreviewLayouts.beyond().sizeM,
        in: SIMD2<Double>(900, 650)
    )
    @Previewable @FocusState var isFocused: Bool
    let layout = PreviewLayouts.beyond()
    LayoutCanvasView(
        snapshot: CanvasDisplaySnapshot(
            layout: layout,
            legend: PreviewLayouts.sampleLegend,
            activeLayer: .structure,
            showVisitorFlow: true,
            selectionID: layout.objects.first { $0.kind == .door }?.id
        ),
        transform: $transform,
        isFocused: $isFocused
    )
    .frame(width: 900, height: 650)
    .preferredColorScheme(.dark)
}

#Preview("Validation Issue & Zoomed Labels") {
    @Previewable @State var transform = CanvasTransform(scale: 20, offset: SIMD2<Double>(50, 50))
    @Previewable @FocusState var isFocused: Bool
    let layout = PreviewLayouts.smallMarket()
    let boothID = layout.objects.first { $0.kind == .booth }?.id ?? UUID()
    LayoutCanvasView(
        snapshot: CanvasDisplaySnapshot(
            layout: layout,
            legend: PreviewLayouts.sampleLegend,
            activeLayer: .booths,
            selectionID: boothID,
            issues: CanvasIssueSnapshot(
                warningObjectIDs: [boothID],
                blockedSidesByBoothID: [boothID: .right]
            )
        ),
        transform: $transform,
        isFocused: $isFocused
    )
    .frame(width: 900, height: 650)
    .preferredColorScheme(.dark)
}
