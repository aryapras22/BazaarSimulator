import Foundation

extension LayoutEditorViewModel {
    func isLayerVisible(_ layer: EditorLayer) -> Bool {
        !hiddenLayers.contains(layer)
    }

    func toggleLayerVisibility(_ layer: EditorLayer) {
        if hiddenLayers.contains(layer) {
            hiddenLayers.remove(layer)
        } else {
            hiddenLayers.insert(layer)
        }
    }
}
