import Foundation

/// Converts a `Layout` into a `SimulationVenue` for the editor's read-only 3D preview and caches by `Layout`
/// equality so `SimulationVenue.id` stays stable while unchanged and rotates after 2D edits.
struct Editor3DVenueBuilder {
    private var cachedLayout: Layout?
    private var cachedVenue: SimulationVenue?

    init() {}

    mutating func venue(for layout: Layout) -> SimulationVenue {
        if let cachedVenue, cachedLayout == layout {
            return cachedVenue
        }
        let built = Self.build(for: layout)
        cachedLayout = layout
        cachedVenue = built
        return built
    }

    private static func build(for layout: Layout) -> SimulationVenue {
        let grid = NavigationGrid(layout: layout)
        return SimulationVenue(
            id: UUID(),
            blocks: VenueGeometry.blocks(for: layout),
            plan: grid.plan,
            attractions: VenueGeometry.attractions(in: layout),
            seats: VenueGeometry.seats(in: layout)
        )
    }
}
