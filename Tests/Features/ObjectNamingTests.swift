import Testing
@testable import BazaarSimulator

@Suite
struct ObjectNamingTests {
    @Test("The block kind is called Object in every place the user reads it")
    func blockIsCalledObject() {
        #expect(LayoutObjectKind.block.displayName == "Object")
        #expect(ObjectCatalog.item("block")?.name == "Object")
        #expect(EditorAddTool.block.title == "Add object")
    }
}
