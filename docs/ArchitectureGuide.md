# Architecture Guide

> Purpose: development guide for developers working on Bazaar Simulation. It defines the structure, layer responsibilities, code quality limits, testing rules, and how to build reusable components. All code in this guide is short and illustrative, for learning the pattern. It is not the implementation. References are listed once, at the end.
>
> Updated 30 Oct 2026 to match the Hi-Fi screens. Terms follow the UI: project, layout, legend, visitor type.
## Table of contents
*   App overview
*   Architecture: feature-sliced MVVM + simulation core
*   Layer rules
*   Separation of concerns
*   Directory structure
*   Core building blocks
*   Feature flows
*   macOS specifics
*   Code size limits and how to break up files
*   Long parameter lists
*   Code smells quick reference
*   Writing tests
*   Reusable components
*   Tooling and review
*   Suggested build order
*   Architecture checklist
*   Sources
* * *
## App overview
Bazaar Simulation is a planning tool for event layouts. The user brings the floor plans and legend of a bazaar, reviews and edits each layout, sets who visits and when, compares the layouts on four measures, and watches one layout run in 3D. It is not a game: no money, no days.

A project is one bazaar. It holds a legend, one set of event parameters, and several layouts (alternative floor plans of the same bazaar).

| Feature | Description (Hi-Fi screen) |
| ---| --- |
| Project library | Sidebar list of projects with a search field at the bottom. Create, open, rename, delete. The empty state reads "Add project to get started" |
| Project setup | Name the project. Drop legend PDFs (one legend serves every layout) and floor plan PDFs (one per layout). Files are read one at a time, with a progress bar per file, a Cancel button, and Continue to Review once every file is read |
| Layout editor | Two-layer editing (Structure and Booths) with inactive layer dimming (35%). Vertical tool rail per layer, collapsible side panel, canvas with hint strip and visitor flow toggle, wall graph editing with node and midpoint gestures, hall outline edge handles that grow or shrink the hall, and fixed inspector column. View presets: Plan and 3D. The same editor is used to review detected objects |
| Parameters | A dialog opened from the project header, with Cancel and Apply. Total visitors per day, event duration, bazaar type, visitor type mix. Applies to every layout in the project |
| Project overview | Header with Parameters and Legend buttons. One card per layout with a thumbnail, zone badges (A to F) colored by risk, counts of low, medium, and high zones, and Simulate and Edit buttons |
| Analysis | Below the cards. Tabs for Crowd Density, Flow Rate, Congestion, and Duration. Each tab shows a recommendation ("Our choice"), a comparison table, and a chart over the day |
| Simulation | A Preparing Layout screen (2D to 3D), then a 3D view of one layout with Density, Congestion, and Footfall overlays and playback controls |

Two things are missing from the Hi-Fi. It has no separate review screen, so this guide reuses the Layout editor for it, with detected objects marked for confirmation. It also shows no way to start a layout without a PDF, but the editor still has to work without a reader (see Floor plan import and reading).

Out of scope: vehicles, parking, road transport. Export is optional for now.
* * *
## Architecture: feature-sliced MVVM + simulation core

```sql
graph TD
    subgraph "Presentation (per feature)"
        View["View (SwiftUI)"]
        VM["ViewModel (@Observable, @MainActor)"]
        View --> VM
    end

    subgraph "Core"
        Session["ProjectSession (current project)"]
        Repo["Repositories"]
        Services["Services (PDF import, floor plan readers)"]
        Analysis["AnalysisService"]
        Engine["SimulationEngine (actor, one per run)"]
        DB["SwiftData"]
        Repo --> DB
        Analysis --> Engine
    end

    subgraph "Domain (pure Swift)"
        Models["Project, Layout, Legend, VisitorType, VisitorMix, EventParameters"]
        Snap["SimulationSnapshot, HeatmapFrame, LayoutAnalysis"]
    end

    VM --> Session
    VM --> Repo
    VM --> Services
    VM --> Analysis
    VM --> Engine
    Repo --> Models
    Services --> Models
    Analysis --> Snap
    Engine --> Models
    Engine --> Snap
    View --> DS["DesignSystem"]
```

| Layer | Responsibility | Example |
| ---| ---| --- |
| View | Declarative UI. Reacts to ViewModel state | `LayoutEditorView`, `SimulationView` |
| ViewModel | Feature state and user actions. Coordinates core pieces | `SimulationViewModel`, `ParametersViewModel` |
| ProjectSession | The one shared, observable current project | edited by setup, editor, and parameters, read by overview, analysis, and simulation |
| Service | OS and model access | `PDFImportService`, floor plan readers |
| Repository | Decides how projects are stored | `ProjectRepository` |
| Analysis service | Runs the engine headless for each layout, caches the results, builds the recommendation | `AnalysisService`, `RecommendationBuilder` |
| Simulation engine | Agents, arrivals, movement, zones, metrics. No UI, no SwiftData | `SimulationEngine` |
| Domain | Plain value types, `Sendable` | `Layout`, `VisitorType`, `AgentState` |
| DesignSystem | Tokens, styles, and components shared by features. Carries the dark palette of the Hi-Fi | `MetricTile`, `Card`, `SegmentedTabs` |

* * *
## Layer rules
1. Views only talk to their own ViewModel. Never call a service, repository, or the engine directly.
2. ViewModels may use services, repositories, the engine, and `ProjectSession`, always through protocols. They never reference another feature's ViewModel.
3. The engine imports Foundation and `simd` only. Never SwiftUI, AppKit, or SwiftData.
4. Domain types are plain `Sendable` structs. SwiftData `@Model` classes are not passed into the engine or across actors. A repository maps between them.
5. Repositories decide the data source. ViewModels ask for projects, not for a `ModelContext`.
6. Services and the engine factory are injected through `init`, not created inside ViewModels. Each simulation run gets its own engine from the factory.
7. Feature A never imports Feature B. Logic two features need goes in `Core/`. A screen that shows two features (the project screen shows the layout cards and the analysis) is composed in `App/Navigation/`.
8. Only one floor plan reader model is loaded at a time. `ImportQueue` reads one file at a time, loads the model lazily, and unloads it after the last file. Most end users are assumed to have 16 GB Macs.
9. Keep every file, type, function, and parameter list inside the limits in this guide. A linter warning is a prompt to look for a second concern in the code, not to shave lines.
10. `Core/DesignSystem` imports SwiftUI only. It never imports Domain or a feature.
11. `Core/Scene3D` may import RealityKit and `Core/DesignSystem`. `Core/Domain/Catalog` imports Foundation and `simd` only. The simulation engine still imports neither.

* * *
## Separation of concerns
Separation of concerns means splitting a problem into parts that can be understood and changed one at a time. In this app, a concern is a reason for code to change: how a screen looks, how a project is stored, how a crowd moves, how a PDF is read. The layers above are the first level of separation. This section covers the second level: spotting, inside one file, that two concerns got mixed.
### Who owns which concern

| Concern | Owner | The owner must not |
| ---| ---| --- |
| Drawing and layout | View | call services, repositories, or the engine. Compute geometry or metrics |
| Screen state and user actions | ViewModel | draw, parse files, do geometry or crowd math, touch SwiftData |
| The current project, shared by features | ProjectSession | do work (no I/O, no engine calls) |
| Storage format and queries | Repository | know about screens or selection |
| OS and model access (PDF, readers) | Service | decide what the UI shows, or edit the project |
| Crowd behavior and metrics | Engine | import SwiftUI, AppKit, or SwiftData |
| Comparing layouts and the recommendation | AnalysisService, RecommendationBuilder | import SwiftUI, or hold screen state |
| Drawing the 3D scene and the crowd | Scene types inside the Simulation feature | decide movement or compute metrics |
| Meaning and rules of the data | Domain | import anything beyond Foundation and simd |
| Raw model output to domain units | Mapper | live inside a reader or a view |
| Look and feel shared by features | DesignSystem | know about domain types |

A view model never contains crowd math or unit conversion. If a GUI class holds domain logic, move that logic and its data into a domain type.
### One reason to change
A type has one responsibility and therefore one reason to change. Two smells show the opposite:
*   Divergent change: one class is edited for unrelated reasons (a UI tweak and a storage change land in the same file).
*   Shotgun surgery: one change forces small edits in many places, which means one concern is scattered.
### Five checks to run on any file
1. Describe the type in one sentence. If the sentence needs "and" between two different jobs, split it.
2. Read the imports. A file that imports SwiftUI and PDFKit, or SwiftUI and SwiftData, is mixing layers.
3. Imagine three changes: a new screen layout, a new storage format, a new crowd model. If more than one of them would make you edit this file, split it.
4. Imagine adding a new `LayoutObjectKind`. If that means edits in the editor, the engine, the 3D scene, and the import mapper, the facts about each kind are scattered. Gather them in one place (computed properties on the enum in `Core/Domain`) so other layers ask the enum instead of repeating a `switch`.
5. Ask whether the logic can be unit tested without launching the UI. If not, logic is stuck inside a view or view model.
### Example: one function with five concerns, then split

```swift
// Before: file access, model call, unit conversion, storage, and screen state in one place
func importPlan(_ url: URL) async {
    let image = render(PDFDocument(url: url))
    let result = try await model.generate(from: image)
    context.insert(ProjectRecord(layout: convert(result)))
    draft = convert(result)
}

// After: the import code orchestrates. Each step belongs to the layer that owns it
func importPlan(_ url: URL, legend: Legend) async throws {
    let page = try await pdf.loadPage(from: url, pageIndex: 0)                  // Service
    let request = ReadingRequest(page: page, legend: legend, mode: .agentic)
    let extracted = try await reader.readPlan(request, onProgress: updateRow)   // Service
    drafts.append(extracted.toDraftLayout(page: page))                          // Mapper
}
```

Nothing is saved yet. Continue to Review puts the drafts into `ProjectSession`, and the repository stores the project once the user confirms the review.
* * *
## Directory structure

```bash
BazaarSimulation/
├── .swiftlint.yml
├── App/
│   ├── BazaarSimulationApp.swift        # Scenes, ModelContainer, builds AppServices
│   ├── AppServices.swift                # Container of injected services and the engine factory
│   ├── AppCommands.swift                # Menu bar commands and shortcuts
│   └── Navigation/                      # AppRouter, ScreenFactory, ProjectScreen (layout cards + analysis)
│
├── Core/
│   ├── Domain/                          # Project, Layout, Legend, VisitorType, VisitorMix, EventParameters, snapshots, enums
│   │   └── Catalog/                     # CatalogItem, ShapePrimitive, ObjectCatalog, BoothShape, BoothTemplates
│   ├── Scene3D/                         # SceneGeometryBuilder, SceneMeshFactory (RealityKit), CameraRig, CameraRay, BoundingBox3D
│   ├── Persistence/                     # ProjectRecord (SwiftData) and mapper
│   ├── Repositories/                    # ProjectRepository
│   ├── Resources/                       # Bundled JSON: visitor type presets, bazaar type presets, risk thresholds, metric texts
│   ├── Services/
│   │   ├── PDFImportService.swift
│   │   └── FloorPlanReading/            # Protocol, registry, four reader backends
│   ├── Simulation/                      # Engine, CrowdSimulation, CrowdWorld, ZoneMap, MetricsCollector
│   ├── Analysis/                        # AnalysisService, RecommendationBuilder
│   ├── Session/
│   │   └── ProjectSession.swift
│   └── DesignSystem/
│       ├── Tokens/                      # Palette (dark), Typography, Spacing, Radius
│       ├── Modifiers/                   # Card, CaptionTextFormat
│       ├── Styles/                      # PrimaryButtonStyle
│       └── Components/                  # SegmentedTabs, ProgressBar, Chip, MetricTile, Panel
│
├── Features/
│   ├── ProjectLibrary/
│   ├── ProjectSetup/
│   ├── LayoutEditor/
│   ├── Parameters/
│   ├── ProjectOverview/
│   ├── Analysis/
│   └── Simulation/                      # Each has View/, ViewModel/, ViewComponents/. Simulation also has Scene/ (3D)
│
└── Tests/
    ├── Core/                            # Mirrors the source folders
    ├── Features/
    ├── Support/                         # Fakes, stubs, fixture builders
    ├── Fixtures/                        # Sample PDFs, labelled floor plans and legends
    └── UITests/
```

Optional: make `Core/Domain` and `Core/Simulation` a local Swift Package. It enforces rule 3 (no UI imports) at compile time and lets the engine run from a command line target.
* * *
## Core building blocks
### Domain models
All positions are in metres from the layout origin, never in PDF pixels. Import converts pixels to metres. Legend colors are stored as RGB values and the DesignSystem converts them, so Domain imports no UI framework.

```swift
struct LayoutObject: Codable, Identifiable, Sendable {
    var id = UUID()
    var kind: LayoutObjectKind       // booth, door, wall, block, closedArea, table, seating, entertainment
    var label: String                // "B-7", "NW"
    var placement: Placement
    var categoryID: LegendEntry.ID?  // booths: a legend category
    var openSides: OpenSides = []    // booths: the sides visitors can use
    var doorFlow: DoorFlow?          // doors: direction and connection (Door inspector on Structure layer)
}

struct Placement: Codable, Sendable {
    var center: SIMD2<Double>        // metres
    var sizeM: SIMD2<Double>
    var rotationRadians: Double = 0
    var shape: FootprintShape = .rect // .round fills the box with an oval; only blocks and restricted areas
    func snapped(toGrid cellM: Double) -> Placement { /* ... */ }
}
```

| Type | Purpose |
| ---| --- |
| `Project` | Name, `Legend`, `EventParameters`, a list of `Layout`, and `SimulationConfig` |
| `Layout` | Name, width, depth, and a list of `LayoutObject`. Tables and seating blocks are objects too: each names a standard model in `FurnitureModels` by `catalogID`, and its chairs are computed from the model, never stored. One per floor plan PDF |
| `Legend` | Entries of name and RGB color (in the Hi-Fi: F&B, Fashion, Lifestyle & Hobbies), read from the legend PDFs. Booth categories come from here |
| `EventParameters` | Total visitors per day, event hours, bazaar type, `VisitorMix`. Shared by every layout |
| `VisitorType` | Name, one-line summary, and the behavior parameters the engine reads (see below) |
| `VisitorMix` | A percentage per visitor type. Rescales so the total stays 100. A locked share is left out of rescaling |
| `SimulationConfig` | Tick rate and random seed |
| `SimulationInput` | What one run needs: a `Layout`, the `EventParameters`, the `Legend`, and the `SimulationConfig` |
| `SimulationSnapshot` | Time and every agent's position and velocity at one tick |
| `HeatmapFrame` | Density, congestion, and footfall values per grid cell. Published less often than snapshots |
| `LayoutAnalysis` | Results of one full run: density and risk level per zone, flow rate over the day, congestion, duration |
| `Recommendation` | The better layout for one metric and the plain-language text shown in "Our choice" |

The Hi-Fi presets are Socializer, Family Member, Stroller, and Purpose Buyer, each with a one-line description of how it moves. Presets and any edited type are the same `VisitorType`, stored as bundled JSON. The parameters follow the ODD persona table in the project docs: walking speed, planned stops, impulse weight, queue tolerance, stay budget, dwell time, and interests (legend category and weight pairs, empty means no preference). The simulator reads only these parameters, so any parameter beyond them needs an engine change first. The Hi-Fi has an edit control per type but no way to add a new type.

`EventParameters.bazaarType` selects a bundled preset that seeds the starting mix and visitor total. The user can change both afterwards.

```swift
struct EventParameters: Codable, Sendable {
    var totalVisitors: Int                 // per day
    var eventHours: TimeRange              // start and end, minutes from midnight
    var bazaarType: BazaarType
    var mix: VisitorMix
}
```

### Persistence and repositories
One SwiftData record stores the whole `Project` as encoded data. The domain structs stay the single schema, and the engine never sees SwiftData.

```swift
protocol ProjectRepositoryProtocol {
    func list() throws -> [ProjectSummary]
    func load(id: UUID) throws -> Project
    func save(_ project: Project) throws
    func delete(id: UUID) throws
}
```

A view model asks for projects. It does not know whether they live in SwiftData or a folder of files. Layout thumbnails and analysis results are derived from the project, so they are not stored in it.
### Floor plan import and reading
Project setup takes two kinds of PDF: legends (one set serves every layout) and floor plans (one PDF per layout). Four steps, each in its own piece:
1. `PDFImportService` renders the page to an image and pulls the page text with PDFKit.
2. A reader backend turns image and text into raw output shaped by the model. `readLegend` gives an `ExtractedLegend`, `readPlan` gives an `ExtractedLayout`. Legends are read first, because reading a plan needs the legend to label booth categories.
3. `ImportQueue` runs the files one at a time, which also keeps one model loaded (rule 8). It publishes a state per file: waiting, reading with progress, done with detected counts (booths and doors), or failed. Cancel stops the queue. Continue to Review is enabled when every file is done.
4. The Layout editor opens in review mode. The user edits, deletes, and confirms detected objects. A mapper converts each draft to a `Layout` in metres.

```swift
protocol FloorPlanReading: Sendable {
    func readLegend(_ page: FloorPlanPage) async throws -> ExtractedLegend
    func readPlan(_ request: ReadingRequest,
                  onProgress: @Sendable (Double) -> Void) async throws -> ExtractedLayout
}
struct ReadingRequest: Sendable {
    let page: FloorPlanPage
    let legend: Legend
    var mode: ReadingMode = .agentic
}
enum ReadingMode { case modelOnly, agentic }   // raw model first, then with tools
```

Four backends (Apple on-device, Apple Private Cloud Compute, Qwen3-VL 4B, Gemma 4 E4B) sit behind this one protocol, so comparing them is a loop. A backend that cannot measure progress reports none, and its row shows an indeterminate bar. If the model cannot find a scale, the user calibrates by clicking two points and typing the real distance.
The first backend in the code is `ExtractorFloorPlanReader`. It wraps the local `Extractor` package, which uses classical image processing and Vision instead of a model, so nothing is downloaded. The package reads pixels and no scale. The reader takes the scale from sizes printed on the plan, and when none is printed it assumes the median booth is 2.5 m. `ExtractedLayoutMapper` then converts the pixels to metres. It keeps booths, walls, blocked areas, and doors from both wall openings and swing symbols. Tables are kept as the standard table that fits their chairs, and chairs without a table become seating blocks. The stage becomes an entertainment object, and other legend classes become blocks. Pillars and entrance and exit areas are dropped. `ExtractedLayoutMapperTruthTests` scores the mapped sample plans against their truth files, on detections recorded from the reader. Python and model options of the package stay off, because the sandbox cannot run them. `ImportQueue` is the real queue behind `ImportQueueing`; `ScriptedImportQueue` remains for previews and tests.
`ImportQueue` also keeps an in-memory log of each file's steps and error text, capped at 2000 lines. The reader adds its own lines through `PlanReadingEvent.note`. The Developer menu's Dev Mode toggle is stored in `UserDefaults` and shows that log at the bottom of project setup.
Extraction quality has been poor so far, so the editor must work without the reader. A user can place everything by hand in an empty layout.
### Simulation engine
An `actor` owns all agent state. One engine instance serves one run. It advances in fixed steps, independent of how often the UI redraws, and publishes snapshots.

```swift
protocol SimulationEngineProtocol: Sendable {
    func prepare(_ input: SimulationInput, progress: @Sendable (Double) -> Void) async throws
    func run() async
    func pause() async
    func setSpeed(_ multiplier: Double) async
    func runToEnd() async -> LayoutAnalysis      // headless, publishes nothing
    var snapshots: AsyncStream<SimulationSnapshot> { get }
    var heatmaps: AsyncStream<HeatmapFrame> { get }
}
```

*   Fixed time step and a seeded random generator: the same input and seed give the same run. That makes bugs reproducible and tests possible. It also means the 3D view and the Analysis show the same event, because Analysis calls `runToEnd()` and Simulation plays the run live.
*   Every walking person is simulated. `CrowdSimulation` steps at 10 Hz: a leader follows the flow field of its target, followers keep a slot beside the leader, time-to-collision steering avoids neighbours and walls, and local density slows people down along the Weidmann curve. Parties decide every half second: planned booths are picked by food share and pull, a booth in view can draw a party off its plan, and strollers stop on the way. Entertainment (stage, photobooth, competition area, display) pulls at attractiveness 5 but is never planned and uses up no detour or stopover. A party that wants to sit takes a free table, or a group of up to four chairs in a seating block, and half the parties at a stage or competition sit in seating within 15 m to watch. The values come from the crowd behaviour research and live in `CrowdParameters`.
*   The event clock covers the event duration from `EventParameters`. `SpawnScheduler` turns total visitors and event hours into arrival times (a Poisson process at a steady rate). Each arrival draws a visitor type from the mix, comes as a party (a family of two adults with one or two kids, anyone else alone or with one or two friends), waits outside while the door is at its flow limit, enters through a door whose flow allows entry, visits booths according to its type, and leaves through a door that allows exit. The Hi-Fi has no stage, so the earlier show phase with front-of-stage crowding is removed.
*   The layout becomes a `CrowdWorld` and a `ZoneMap` once, in `prepare`. `CrowdWorld` holds the 0.25 m floor grid, distance to walls, one-way doors, and one routing field per target. `prepare` reports progress for the Preparing Layout screen. Editing while running is not supported. Stop, edit, prepare again.
*   `ZoneMap` splits the walkable area into named zones (A to F in the Hi-Fi). The Hi-Fi does not say how zones are cut, so that is decided with the metrics research. A zone's risk level (low, medium, high) comes from its density against `RiskThresholds`, loaded from bundled JSON.

Metrics follow the four Analysis tabs. Crowd Density is people per square metre per zone, shown as a risk level. Flow Rate is visitors per minute through the doors over the day, summarized as low, average, and peak. Congestion is where and for how long visitors are slowed or queue. Duration is how long a visitor needs to see everything. Footfall appears only as a 3D overlay and counts visits per cell. Exact definitions come from the metrics research, not from the Hi-Fi.
### Analysis
`AnalysisService` returns one `LayoutAnalysis` per layout. For each layout it creates a fresh engine from the factory in `AppServices` and calls `runToEnd()`. Results are cached in memory under a key made from the layout, the parameters, and the seed, so changing any of them makes the next request recompute.

```swift
protocol AnalysisServiceProtocol: Sendable {
    func analyses(for project: Project) async throws -> [LayoutAnalysis]
}
```

`RecommendationBuilder` is a pure type. Given the analyses and a metric, it picks the better layout and builds the "Our choice" card: a headline value per layout and the plain-language "What this means" lines. The wording lives in a bundled JSON file, not in Swift.
### Cross-feature state
The editor, parameters, overview, analysis, and simulation all work on the same project. That state lives in one injected object in `Core/Session/`.

```swift
@MainActor @Observable
final class ProjectSession {
    var project: Project
    var activeLayoutID: Layout.ID?
    var selectedObjectID: UUID?
}
```

Until `ProjectRepository` is added, `ProjectSessionProtocol` also holds the in-memory project list and setup drafts:

```swift
@MainActor
protocol ProjectSessionProtocol: AnyObject {
    var projects: [ProjectSummary] { get }
    var activeProjectID: UUID? { get }
    var activeProject: ProjectSummary? { get }

    @discardableResult
    func createProject(named name: String) -> ProjectSummary
    func selectProject(id: UUID)
    func renameProject(id: UUID, to name: String)

    func draft(for projectID: UUID) -> ProjectDraft?
    func setDraft(_ draft: ProjectDraft, for projectID: UUID)

    func layout(id: Layout.ID, in projectID: UUID) -> Layout?
    func updateLayout(_ layout: Layout, in projectID: UUID)
    func activeLayoutID(for projectID: UUID) -> Layout.ID?
    func setActiveLayoutID(_ id: Layout.ID, for projectID: UUID)
}
```

| Feature | Relationship to the session |
| ---| --- |
| ProjectLibrary | Loads a project through the repository into the session when it is opened |
| ProjectSetup | Creates the project and writes its name, legend, and draft layouts into the session |
| LayoutEditor | Edits the layout named by `activeLayoutID`, sets `selectedObjectID` |
| Parameters | Edits a draft copy of `project.parameters`. Apply writes it to the session, Cancel drops it |
| ProjectOverview | Reads the layouts and sets `activeLayoutID` for Edit and Simulate |
| Analysis | Reads the project and asks `AnalysisService`. Never edits the session |
| Simulation | Reads the project and the active layout, builds a `SimulationInput`, passes it to its own engine. Never edits the session |

View models save through the repository after a confirmed change (Save Changes, Apply, Continue to Review). The session itself does no I/O.

Analysis and Simulation do not share an engine. Each run has its own instance from the factory, and because a run is deterministic, the 3D playback of a layout matches the numbers in the Analysis.
* * *
## Feature flows
### Project setup

```haskell
sequenceDiagram
    autonumber
    actor User
    participant VM as ProjectSetupViewModel
    participant Queue as ImportQueue
    participant PDF as PDFImportService
    participant Reader as FloorPlanReading
    participant Session as ProjectSession

    User->>VM: Drops legend PDFs and floor plan PDFs
    VM->>Queue: enqueue(files)
    loop One file at a time, legends first
        Queue->>PDF: loadPage(url, 0)
        PDF-->>Queue: Page image + text
        Queue->>Reader: readLegend(page) or readPlan(request)
        Reader-->>Queue: Progress, then result
        Queue-->>VM: Row state (waiting, reading, done)
    end
    VM->>VM: Map each result to a draft Layout (pixels to metres)
    User->>VM: Continue to Review
    VM->>Session: project = name, legend, draft layouts
```

The user can press Cancel at any point, which stops the queue. After Continue to Review, the Layout editor opens in review mode on the drafts.

### Compare layouts

```haskell
sequenceDiagram
    autonumber
    actor User
    participant VM as AnalysisViewModel
    participant Service as AnalysisService
    participant Engine as SimulationEngine (headless)
    participant Rec as RecommendationBuilder

    User->>VM: Opens the project screen
    VM->>Service: analyses(for: project)
    loop Each layout
        Service->>Engine: prepare(input), runToEnd()
        Engine-->>Service: LayoutAnalysis
    end
    Service-->>VM: One LayoutAnalysis per layout
    User->>VM: Picks a tab (Crowd Density, Flow Rate, Congestion, Duration)
    VM->>Rec: recommendation(for: tab, analyses)
    Rec-->>VM: Recommendation
    VM-->>User: Our choice, table, and chart
```

Cached results come back at once when the layout, parameters, and seed are unchanged. Applying new parameters or saving a layout edit changes the key, so the next visit to the project screen recomputes.

### Run the simulation

```rust
sequenceDiagram
    autonumber
    actor User
    participant VM as SimulationViewModel
    participant Engine as SimulationEngine (actor)
    participant Scene as Scene (3D)

    User->>VM: Presses Simulate on a layout card
    VM->>VM: State is preparing (Preparing Layout screen)
    VM->>Engine: prepare(input, progress)
    VM->>Scene: Build the 3D scene from the layout
    User->>VM: Presses Play
    VM->>Engine: run()
    loop Fixed steps
        Engine-->>VM: SimulationSnapshot (HeatmapFrame at a lower rate)
        VM-->>Scene: Update agents and the selected overlay
    end
    User->>VM: Pauses, changes speed, or picks Density, Congestion, or Footfall
    VM->>Engine: pause() or setSpeed()
```

The Simulation view builds the 3D scene from the layout while the Preparing Layout screen is up. The static layout scene now comes from `Core/Scene3D`; the simulation adds agents and overlays on top. Agents are drawn from snapshots. The Density, Congestion, and Footfall tabs switch which layer of the `HeatmapFrame` is painted over the floor. These simulation-specific overlays live in `Features/Simulation/Scene/`. RealityKit is used for the 3D scene (confirmed via spike off `feature/layout-editor`). The engine and view model do not change either way, because they only produce snapshots.

* * *
## macOS specifics
Window and navigation:
*   One `WindowGroup` with a `NavigationSplitView`. The sidebar lists projects, has a search field at the bottom, and can be collapsed. The detail column is a `NavigationStack`: project setup, then review (the editor), then the project screen, which leads to the editor or the simulation. `AppRouter` in `App/Navigation/` owns the active destination (`empty`, `setup(projectID:)`, `review(projectID:)`). `ProjectScreenFactory` in `App/Navigation/` builds and caches screen ViewModels (such as keeping one `ProjectSetupViewModel` per project for the life of the window).
*   The project screen header has a back chevron, the project name, and the Parameters and Legend buttons. Both open as dialogs over the screen. Parameters edits a draft copy and has Cancel and Apply.
*   The editor uses a structured desktop layout with two layers (Structure and Booths) switched via toolbar tabs or Cmd-1 and Cmd-2. Inactive layers draw dimmed at 35% opacity and supply snap candidates without being selectable. The vertical tool rail reflects the active layer: Select, Wall, Room, Library in Structure; Select, Row, Fill, Library in Booths. The central canvas has view presets (Plan and 3D, switched by keys 1 and 2), an active-tool hint strip, and a visitor flow overlay toggle. The right 320 pt inspector column displays single-object, group, or wall graph editing properties.
*   The 3D view has a segmented control at the top (Density, Congestion, Footfall) and a compact playback overlay at the bottom (play and pause, clock, speed).
*   The window uses the dark navy background of the Hi-Fi with blue and orange glows and a translucent sidebar. Tokens carry these colors. Only a dark appearance is designed.
*   A `Settings` scene for reader selection and model management. It is not in the Hi-Fi.
Input:
*   Menu bar commands in `AppCommands.swift` with shortcuts: Space for play and pause, Delete for removing the selected object, Cmd+Z and Cmd+Shift+Z for undo and redo.
*   Editor interactions: click to select, drag to move, hover highlight, right-click menu, scroll or pinch to zoom. The Hi-Fi shows no palette, so how new items are added (right-click menu or a palette) is still open.
*   Route every editor change through one place so undo is implemented once, for example by registering inverse operations with the window's `UndoManager`. Inspector edits commit through the same path as they are made, and consecutive edits to one object merge into one undoable change.
Sandbox and entitlements:
*   App Sandbox on. PDF import needs user-selected file read access. Add read-write only when export is built.
*   Downloading model weights on first launch needs the outgoing network entitlement. Store weights in Application Support.
*   Check the Apple Foundation Models and Private Cloud Compute requirements for the target OS in the current SDK documentation before relying on them.
Frameworks and storage:
*   Use AppKit where iOS code would use UIKit (`NSViewRepresentable` for a custom editing surface if SwiftUI gestures are not enough). SwiftUI `Canvas` for the 2D editor. RealityKit for the 3D view (selected after spike). Swift Charts for the Analysis chart. PDFKit for import. `@Observable` over `ObservableObject`.
*   This guide uses one `WindowGroup` with a SwiftData project library. If the team prefers one file per event plan, `DocumentGroup` is the alternative. The repository protocol keeps that decision out of the features.

* * *
## Code size limits and how to break up files
### The limits
The team adopts the SwiftLint defaults as its limits. Writing them explicitly in `.swiftlint.yml` (see Tooling and review) documents them and keeps them stable if the tool's defaults change.

| Measure | Warning | Error | What is counted |
| ---| ---| ---| --- |
| Line length | 120 characters | 200 | One line |
| Function body | 50 lines | 100 | Functions, initializers, accessors. Comments and blank lines are not counted |
| Type body | 250 lines | 350 | Class, struct, enum, actor. Extensions and protocols are excluded by default |
| File length | 400 lines | 1000 | The whole file. Comment-only lines are counted by default |
| Cyclomatic complexity | 10 | 20 | Branching paths in one function |
| Parameters | 5 | 8 | Per function or initializer. Parameters with default values are not counted |

How to use them:
*   Warning: stop and look for a second concern before the pull request is merged. If the code is fine as it is, say why in the PR description.
*   Error: blocks the merge.
*   The number is a symptom. The cause is almost always mixed concerns or a function doing more than one step.
*   A good reading test: if you want to write a comment explaining a block, give the block a name instead.
### Three cautions
*   Do not shave lines. Joining statements or deleting blank lines changes the count and nothing else. Splitting by concern changes the design.
*   Extensions do not shrink a type. The type body rule skips extensions by default, so moving half a type into `Something+Part.swift` silences the warning while the type keeps the same responsibilities. Use extensions to group one concern's code or a protocol conformance. Use new types to separate concerns.
*   Data is not code. Preset visitor types, bazaar type presets, risk thresholds, and similar tables belong in a bundled JSON file, not in a 300-line Swift array.
### Which fix for which problem

```css
flowchart TD
    A["File over 400 lines, or type over 250"] --> B{"More than one concern?"}
    B -- yes --> C["Extract a type per concern, one file each"]
    B -- no --> D{"One huge function or view body?"}
    D -- yes --> E["Extract methods or subviews"]
    D -- no --> F{"Mostly data?"}
    F -- yes --> G["Move the data to a bundled JSON file"]
    F -- no --> H["Group related members into extensions in their own files, same concern only"]
```

### Breaking up a long function
1. Find comments inside the function that label a block. Move each block into a method named after its comment.
2. Name the new method for what it does, not how. The caller should read like a table of contents.
3. If a local variable blocks the extraction, replace it with a computed property or a small function.
4. Extract complex conditions into named functions, for example `isInsideQueueZone(agent)`.
5. If many locals and parameters still get in the way, move the function into a small struct or class whose properties are those locals (a method object).

```scss
// After: the engine step reads like an outline
private func step(dt: Double) {
    spawnArrivals(upTo: time)
    advanceBoothVisits()
    moveAgents(dt: dt)
    metricsCollector.record(agents, at: time)
}
```

### Breaking up a large type
A type is too large when different methods use different subsets of its properties. Group the methods that share the same properties and move each group into its own type (Extract Class). The original type keeps the orchestration.

| Growing type | Split into |
| ---| --- |
| `LayoutEditorViewModel` | `SelectionState`, `PlacementTool` (drag and snap), `EditHistory` (undo and redo), `InspectorDraft` (field values being typed; a valid draft is applied at once). The view model orchestrates them |
| `SimulationEngine` | `CrowdSimulation`, `CrowdWorld`, `ZoneMap`, `MetricsCollector` (already separate) |
| `ParametersViewModel` | `MixEditor` (rescaling percentages to 100), `ParametersDraft` (form state held until Apply) |
| `ProjectSetupViewModel` | `ImportQueue` (one file at a time, cancel) and a row state type per file |
| Floor plan readers | `FloorPlanPrompt` and `ExtractedLayoutParser` shared by all four backends. Each backend only calls its model |

The helpers are plain types with no UI imports, so they can be unit tested directly.
### Breaking up a large file
*   One main type per file, and the file is named after it. A small private helper type used only by that file may share it.
*   Extensions go in `TypeName+Topic.swift`, only for one concern or one protocol conformance.
*   When a feature folder grows, group by topic: `Features/LayoutEditor/Tools/`, `Features/LayoutEditor/Inspector/`.
### Breaking up a large SwiftUI view
*   Extract subviews into `ViewComponents/`. Each subview is its own struct and takes only the values it needs, not the whole view model.
*   Pass a `Binding` for state a subview edits, not the owner object.
*   Move construction of destinations that need dependencies into a factory, so the top-level view does not know them.
*   Keep low-level components free of domain models (see Reusable components).
*   A flat, readable layout does not need to be split just to hit a number. Do not add abstractions without a reason.
* * *
## Long parameter lists
### The limits

| Count | What to do |
| ---| --- |
| 0 to 3 | Normal. Fewer is better |
| 4 | Look for data clumps and flags |
| 5 (linter warning) | Refactor, or justify in the PR |
| 8 (linter error) | Must be fixed |

Initializers count too. Defaults are not counted by the linter, but they do not remove the complexity.
### Which technique for which symptom

| Symptom | Technique | Example in this app |
| ---| ---| --- |
| Values that always travel together. Test: delete one, and if the others lose their meaning, they are a clump | Introduce Parameter Object | `x, y, width, depth, rotation` become `Placement` |
| Several values are read from one object you already have | Pass the whole object | `CrowdWorld(layout:legend:)` instead of width, depth, and objects |
| The callee can find the value itself | Replace the parameter with a method call | The reader reads the scale from the page, so no `scale:` argument |
| A Boolean flag or mode switches the behavior | Split into two functions, or use an enum | `ReadingRequest(... mode: .agentic)`, not a `useTools: true` flag |
| Many optional tuning values | Options struct with defaults | `ReadingOptions`, `SimulationConfig` |
| An initializer with many injected services | The type has too many jobs. Split the type first | See below |

Exception: do not remove a parameter if doing so creates an unwanted dependency between types. `MetricsCollector` needs agent positions and zone rectangles. Pass those, not the whole `Project`, or the collector becomes coupled to everything in a project.
### Injected services
If a view model's initializer takes more than about four services, it is a large class. Split the view model by responsibility before grouping anything.
`AppServices` is read only where things are composed (the app entry, `App/Navigation/`, and each feature's root view). View models receive the specific protocols they use, never the whole container.
### Worked example

```swift
// Before: a data clump (x...rotation) and two flags that make one function do three jobs
func addObject(kind: LayoutObjectKind, label: String, x: Double, y: Double,
               width: Double, depth: Double, rotation: Double,
               snapToGrid: Bool, registerUndo: Bool)

// After: one value type; snapping and undo are handled elsewhere
func addObject(_ kind: LayoutObjectKind, label: String, at placement: Placement)
```

### Rules for a parameter object
*   Make it a value type (struct). Prefer `let` properties unless an editor needs to change them. Add `Sendable` if it crosses to the engine.
*   Name it for the concept: `Placement`, `ReadingOptions`. Avoid `Params`, `Info`, `Data`, and `Manager`.
*   Move behavior into it. A struct that only holds fields is a data class smell. `Placement` has `snapped(toGrid:)` for that reason.
*   Give optional members default values so most call sites stay short.
*   Put it in `Core/Domain` if the engine or more than one feature uses it. Otherwise keep it next to the type that owns the function.
*   Do not bundle unrelated parameters just to get under the count. If the values do not belong together, the function is doing two jobs. Split the function.
* * *
## Code smells quick reference

| Smell | What it looks like here | First fix |
| ---| ---| --- |
| Long Method | The engine's `step()` has comments labeling steps and runs past a screen | Extract Method per commented block |
| Large Class | `LayoutEditorViewModel` holds selection, snapping, undo, and palette state | Extract Class per responsibility |
| Long Parameter List | `addObject(kind:label:x:y:width:depth:rotation:...)` | Parameter object, whole object, or split the function |
| Data Clumps | The same position, size, and rotation values in several signatures | A value type such as `Placement` |
| Primitive Obsession | A `Double` that is metres in one place and pixels in another | Name the unit in the type (`metresPerPixel`) or use small wrapper types |
| Divergent Change | A view model edited both for UI changes and for storage changes | Extract Class so each reason to change has its own type |
| Shotgun Surgery | A new `LayoutObjectKind` needs edits in the editor, engine, 3D scene, and mapper | Gather per-kind facts in one place |
| Feature Envy | A view model method that mostly reads fields of `VisitorType` or `Layout` | Move the method onto that type |
| Duplicated code | The same density calculation in the engine and the analysis | One function in `Core` |
| Dead code, comments explaining what | Unused branches, comments that restate the next line | Delete. Rename or extract so the code says it |
| Speculative generality | An abstraction built for a feature nobody asked for | Delete it. Add it when a second use appears |

* * *
## Writing tests
### What to use
*   Swift Testing for unit and integration tests: `import Testing`, `@Test`, `#expect`, `#require`. It runs tests in parallel, supports async tests, and supports tags and parameterized tests.
*   XCUITest for the few UI tests.
*   Test code lives only in test targets. Never import the testing library into the app target.
### The test pyramid for this app
Many small fast tests at the bottom, fewer coarser tests above, very few at the top.

| Level | Count | What | Example |
| ---| ---| ---| --- |
| Unit | Most | Domain types, mappers, engine pieces, view models with fakes | `Placement.snapped`, `VisitorMix` rescaling, `SpawnScheduler`, `RecommendationBuilder`, `ProjectSetupViewModel` with a failing reader |
| Integration | Some | One real boundary at a time | `ProjectRepository` with an in-memory store, `PDFImportService` with a sample PDF, a headless engine run |
| Reader evaluation | Separate, slow | Model output against hand-labelled floor plans | Report a score. Do not assert pass or fail in the unit suite |
| UI | Very few | The most valuable journeys | Import PDFs, review, set parameters, compare layouts, simulate |

What to test per layer:

| Layer | How |
| ---| --- |
| Domain | Pure unit tests |
| Mapper | Unit tests with fixtures: pixels convert to metres, a missing scale asks for calibration |
| Engine pieces | Unit tests with a fixed seed: the mix spawns the right counts, movement avoids obstacles |
| Engine, full run | Headless integration test: every agent has left when the run ends, no agent stands inside an obstacle, the same seed gives the same result |
| Analysis | Unit tests with fixed `LayoutAnalysis` values: the layout with the lower peak density is recommended on Crowd Density, and a tie gives a defined result |
| ViewModel | Unit tests with fake services: a snapshot from a fake engine updates state, an error from a fake reader sets the message |
| Repository | Integration test: save then load returns an equal project |
| View | No direct unit tests. Logic lives in the view model. Previews show visual states |

### Rules
1. Test behavior, not implementation. Check the public interface and observable results. Do not verify the order of calls between collaborators, because that breaks tests during every refactor.
2. If you feel the need to test a private method, the type probably has too many responsibilities. Split it (see the size limits).
3. Test at the lowest level possible. When a high-level test fails and no lower-level test does, add the lower-level test. Remove high-level tests that only repeat lower-level coverage.
4. One behavior per test, laid out as Arrange, Act, Assert (Given, When, Then), separated by blank lines.
5. Tests follow FIRST: fast, isolated, repeatable, self-validating, timely (written with or before the code).
6. Do not test trivial code (plain getters, simple forwarding). Test non-trivial logic, including edge cases. A coverage number is not a goal. Use coverage to find code with no tests.
7. Fix or delete a flaky test quickly. An unreliable suite stops being trusted.
8. A bug fix starts with a failing test that reproduces the bug.
### Structure and naming
*   One suite per production type, named `TypeNameTests`, in a file `TypeNameTests.swift`. The Tests folder mirrors the source folders.
*   Give each test a display name written as a sentence about the behavior: `@Test("Every agent has left when the run ends")`.
*   A suite is a struct. The runner creates a new instance for each test, so `init` is the setup and nothing is shared between tests.
*   Tests run in parallel by default. No shared mutable state, no shared files. If a test needs files, use its own temporary folder.
*   Tag slow tests (`.slow`, `.model`) so they stay out of the default run.
### Determinism
*   Unit tests do not touch the network, a real model, the real file system, the clock, or the system random generator.
*   The engine takes a seed and a fixed step, so a test can run a whole event in milliseconds with a known result.
*   Never sleep in a test to wait for something. Await the result, or use a double you control.
### Test doubles
Prefer fakes and stubs over strict mocks.

| Kind | What it is | Example here |
| ---| ---| --- |
| Dummy | Fills a parameter, never used | An unused service in a view model init |
| Fake | Working shortcut implementation | `InMemoryProjectRepository` |
| Stub | Returns prepared answers | `StubFloorPlanReader` returning a fixed `ExtractedLayout` |
| Spy | A stub that records how it was called | A reader that counts calls |
| Mock | Preloaded with expected calls, fails on others | Avoid. It couples tests to implementation |

Write doubles by hand against the protocols in `Core`. Keep them in `Tests/Support/`. Use fixture builders with defaults so a test states only what matters, for example `Layout.fixture(booths: 3)`.
### Examples

```swift
@Suite struct VisitorMixTests {
    @Test("Changing one share rescales the others to 100")
    func rescales() {
        var mix = VisitorMix.fixture(shares: [50, 30, 20])

        mix.setShare(70, for: mix.shares[0].visitorTypeID)

        let total = mix.shares.map(\.percent).reduce(0, +)
        #expect(abs(total - 100) < 0.001)
    }
}

// Parameterized: a new enum case is tested automatically
@Test(arguments: LayoutObjectKind.allCases)
func everyKindHasADisplayName(_ kind: LayoutObjectKind) {
    #expect(!kind.displayName.isEmpty)
}
// Same seed, same run
@Test("A run is repeatable")
func repeatable() async throws {
    let first = try await runHeadless(Project.fixture(seed: 7))
    let second = try await runHeadless(Project.fixture(seed: 7))
    #expect(first == second)
}
```

Expectation tools: `#expect` keeps going after a failure. `#require` stops the test (use it to unwrap an optional precondition). `#expect(throws:)` checks errors. To test with several inputs, use `arguments:`. With two collections, use `zip` to avoid running every combination.
### Async code and view models
*   Mark the test `async` and `await` the call. Mark view model tests `@MainActor`.
*   For event callbacks, use `confirmation` with an expected count.
*   Long-lived streams (engine snapshots) are hard to test with real timing. Inject a test double that delivers scripted snapshots on demand, then assert on the view model state.
### SwiftData
Create an in-memory container per test (`ModelConfiguration(isStoredInMemoryOnly: true)`) so each test starts clean. Test the repository directly, not through a view.
### Floor plan readers
Model output is not deterministic, so readers are measured, not asserted. Keep a few labelled floor plans and legends in `Tests/Fixtures/`, run each reader (model only, then agentic) in a separate slow plan, and report an accuracy score per reader. The unit suite tests only the code around the reader (the prompt, the parser, the mapper) with stubs.
* * *
## Reusable components
### Where components live
*   Used by one feature: `Features/X/ViewComponents/`.
*   Used by two or more features: `Core/DesignSystem/`.
*   Extract on the second use, not before. A component built for a use that does not exist yet is speculative.
### Pick the right form

| Need | Use |
| ---| --- |
| The same group of modifiers repeated (padding, background, font) | A `ViewModifier` plus a `View` extension |
| Restyle a built-in control and keep its full API | A style type (`ButtonStyle`, `LabelStyle`, `ToggleStyle`) |
| A composite with its own layout and logic | A custom `View` struct |
| A container that holds caller-supplied content (card, panel, inspector section) | A generic view with a `@ViewBuilder` closure |
| Shared values: colors, spacing, radii, fonts | Design tokens in `Core/DesignSystem/Tokens/` |

Notes on each form:
*   Modifiers: name the modifier for its purpose, keep it to one job, pass settings in as parameters, and keep conditional logic out. Modifier order changes the result. A modifier refines a view. It should not build a whole hierarchy.
*   Styles: apply with the matching modifier, which also styles a whole subtree and lets a child override it. A custom style replaces the system behavior, so handle states such as pressed yourself.
*   Do not wrap a built-in control in a new view just to restyle it. The wrapper must re-expose every parameter, existing modifiers stop applying directly, and the result cannot be passed where the control is expected.

```swift
// Modifier + extension: one place to change the look
struct Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.m)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.m))
    }
}
extension View { func card() -> some View { modifier(Card()) } }

// Container: the caller decides the content
struct Panel<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title).font(Typography.headline)
            content()
        }
        .card()
    }
}
```

### Components the Hi-Fi already needs

| Component | Where it appears | Home |
| ---| ---| --- |
| `SegmentedTabs` | Floor Plan and Flow in the editor, Density, Congestion, and Footfall in the simulation, the four Analysis tabs | `Core/DesignSystem/Components/` |
| `Card`, `Panel` | Layout cards, analysis panels, inspector sections | `Core/DesignSystem/` |
| `Chip` | Zone badges, time range chips in Parameters | `Core/DesignSystem/Components/` |
| `ProgressBar` | Import rows, Preparing Layout screen | `Core/DesignSystem/Components/` |
| `MetricTile` | Headline values in the recommendation card | `Core/DesignSystem/Components/` |
| `DropZone` | Legend and floor plan drop areas (both uses are in one feature) | `Features/ProjectSetup/ViewComponents/` |
| `InspectorPanel` | Booth and door inspectors | `Features/LayoutEditor/ViewComponents/` |
| `CanvasRulers` | Top and left ruler bands over the editor canvas | `Features/LayoutEditor/ViewComponents/` |
| `CanvasScaleBar` | Measured scale bar at the bottom right of the canvas | `Features/LayoutEditor/ViewComponents/` |
| `GroupInspector` | Batch inspector for booth groups and multi-selections | `Features/LayoutEditor/ViewComponents/` |
| `VisitorTypeRow` | Slider rows in Parameters | `Features/Parameters/ViewComponents/` |
| `LayoutCard` | Layout cards on the project screen | `Features/ProjectOverview/ViewComponents/` |

### Rules for a reusable component
1. Take values, not models. `MetricTile(title:value:unit:)` takes strings, not `LayoutAnalysis`. A component that imports Domain or a feature is not reusable.
2. Actions are closures, editable state is a `Binding`. The component does not own state its parent needs.
3. No services, repositories, the engine, or view models inside a component.
4. Use tokens, not literals. No hard-coded colors, spacing, or radii inside a component. Changing a token updates every use.
5. One job. A component that needs a Boolean to switch between two layouts is two components.
6. Few required parameters (3 or fewer), with defaults for the rest. If it needs more, group them in a value type (see Long parameter lists).
7. Name by purpose, not appearance: `MetricTile`, not `BlueBox`.
8. Put formatting and other logic in a small plain type so it can be unit tested. The view only displays the result.
9. Set accessibility labels inside the component so every use gets them.
10. Every component has `#Preview`s for the normal case, long text, empty value, dark mode, and disabled state. Previews are the living documentation.

```rust
// Not reusable: knows the domain
struct MetricTile: View { let analysis: LayoutAnalysis }

// Reusable: knows only what it displays
struct MetricTile: View {
    let title: String
    let value: String
    var unit: String = ""
}
```

A feature-specific wrapper adapts a model to the generic component. `ZoneBadge(zone:)` lives in `Features/ProjectOverview/ViewComponents/` and builds a `Chip(title:color:)` from `DesignSystem`.
* * *
## Tooling and review
Add SwiftLint to the project and commit this file at the repository root. The values are the defaults, written out so they are visible and stable.

```yaml
line_length: { warning: 120, error: 200 }
function_body_length: { warning: 50, error: 100 }
type_body_length: { warning: 250, error: 350 }
file_length: { warning: 400, error: 1000 }
cyclomatic_complexity: { warning: 10, error: 20 }
function_parameter_count: { warning: 5, error: 8 }
```

Test plans: a fast plan (all unit and integration tests, excluding `.slow` and `.model`) runs on every build and before every merge. A slow plan (reader evaluation, UI tests) runs before milestones.
Review rules:
*   A linter error blocks the merge. A linter warning needs a fix or one sentence in the PR explaining why the code is fine.
*   New logic comes with tests. A bug fix comes with a regression test.
*   A new shared component comes with previews and uses tokens.
*   Review comments name the smell and the fix ("Data Clump, suggest a parameter object").
* * *
## Suggested build order
The floor plan reader is the riskiest part, so the app should not depend on it early. Write tests alongside each step.
1. Domain models and a headless `SimulationEngine` with a hard-coded layout and parameters, tested with a fixed seed. Include arrivals, `ZoneMap`, and `runToEnd()`.
2. Simulation view: the Preparing Layout step, the 3D scene with moving agents, and the three overlays. If 3D slows the team down, start with a top-down `Canvas` behind the same snapshot interface and swap later.
3. Layout editor with Structure and Booths layers, manual placement, wall graph editing, and the inspector, so a layout can exist without any model.
4. Project library, project screen with layout cards, and `ProjectSession` wiring.
5. Parameters dialog: mix sliders with rescaling, bazaar type presets, Cancel and Apply on a draft.
6. Analysis: `AnalysisService`, the four tabs, `RecommendationBuilder`, the table and the chart.
7. Project setup: PDF import, `ImportQueue`, one reader backend, then the other three behind the same protocol.
* * *
## Architecture checklist
Use this when adding a file, feature, or service.
*   \[ \] Core or feature: is it used by more than one feature? Put it in `Core/`
*   \[ \] Engine purity: does anything under `Core/Simulation` import SwiftUI, AppKit, or SwiftData? Remove it
*   \[ \] Domain only: does the engine or a service receive a `@Model` class? Pass a `Project` struct instead
*   \[ \] Units: does any position reach the engine in pixels? Convert to metres at import
*   \[ \] Repository abstraction: does a ViewModel use `ModelContext` directly? Go through `ProjectRepository`
*   \[ \] Protocol injection: is a service created inside a ViewModel? Inject it through `init`
*   \[ \] Feature isolation: does one feature import another? Extract the shared logic to `Core/`
*   \[ \] Shared state: do two features keep their own copy of the layout or parameters? Use `ProjectSession`
*   \[ \] Reader independence: can a layout be built and simulated with no reader loaded?
*   \[ \] Composition: does a screen need views from two features? Compose it in `App/Navigation/`
*   \[ \] Engine per run: do Analysis and Simulation share one engine instance? Create one per run from the factory
*   \[ \] Analysis in Core: is a metric, risk level, or recommendation computed in a view or view model? Move it to `Core/Analysis` or the engine
*   \[ \] Colors: does Domain hold a SwiftUI `Color`? Store RGB values and convert in DesignSystem
*   \[ \] Memory: is more than one reader model loaded at a time? Unload the previous one
*   \[ \] Determinism: does the engine use `Date()` or the system random generator? Use the fixed step and seeded generator
*   \[ \] One reason to change: can you describe the type in one sentence without "and" between two jobs?
*   \[ \] Imports: does the file import frameworks from two layers? Split it
*   \[ \] Sizes: file over 400 lines, type over 250, function over 50 or complexity over 10? Run the flowchart. Do not hide size in extensions
*   \[ \] Parameters: 5 or more, or a Boolean flag? Parameter object, whole object, or split the function
*   \[ \] Data: is a large table of presets written as Swift code? Move it to a bundled JSON file
*   \[ \] Tests: does new logic have unit tests, and a bug fix a regression test?
*   \[ \] Test quality: one behavior per test, no sleeping, no real network, model, or clock, no shared state?
*   \[ \] Doubles: fakes and stubs instead of strict mocks?
*   \[ \] Component: does it take values instead of models, use tokens, and have previews?
*   \[ \] Component placement: used by one feature, or two or more (DesignSystem)?
*   \[ \] Views: does a subview receive the whole view model when it needs two values? Pass the values or a binding
* * *
## Sources
Researched on 22 Oct 2026. References are listed here only. Pages marked secondary are blog posts, course notes, or reader summaries.
Separation of concerns and code smells:
*   [Separation of concerns (Wikipedia)](https://en.wikipedia.org/wiki/Separation_of_concerns)
*   [Long Method (Refactoring Guru)](https://refactoring.guru/smells/long-method)
*   [Large Class (Refactoring Guru)](https://refactoring.guru/smells/large-class)
*   [Long Parameter List (Refactoring Guru)](https://refactoring.guru/smells/long-parameter-list)
*   [Introduce Parameter Object (Refactoring Guru)](https://refactoring.guru/introduce-parameter-object)
*   [Data Clumps (Refactoring Guru)](https://refactoring.guru/smells/data-clumps)
*   [Smells to Refactorings (Carleton University course notes, secondary)](https://people.scs.carleton.ca/~jeanpier/Fall2021/Topic%204-%20About%20Smells%20and%20Refactoring/1a-%20Smells%20to%20Refactorings.pdf)
*   [Code Smells (Coding Horror, secondary)](https://blog.codinghorror.com/code-smells/)
*   [Clean Code reading summary (GitHub, secondary summary of Robert C. Martin's book)](https://github.com/bibenji/reading-sheets/blob/master/Clean_Code.md)
Size and parameter limits (SwiftLint defaults):
*   [file\_length](https://realm.github.io/SwiftLint/file_length.html)
*   [function\_body\_length](https://realm.github.io/SwiftLint/function_body_length.html)
*   [type\_body\_length](https://realm.github.io/SwiftLint/type_body_length.html)
*   [function\_parameter\_count](https://realm.github.io/SwiftLint/function_parameter_count.html)
*   [cyclomatic\_complexity](https://realm.github.io/SwiftLint/cyclomatic_complexity.html)
*   [line\_length](https://realm.github.io/SwiftLint/line_length.html)
Testing:
*   [Swift Testing (Apple)](https://developer.apple.com/documentation/testing)
*   [Defining test functions (Apple)](https://developer.apple.com/documentation/Testing/DefiningTests)
*   [Organizing test functions with suite types (Apple)](https://developer.apple.com/documentation/Testing/OrganizingTests)
*   [Implementing parameterized tests (Apple)](https://developer.apple.com/documentation/Testing/ParameterizedTesting)
*   [Expectations and confirmations (Apple)](https://developer.apple.com/documentation/Testing/Expectations)
*   [Testing asynchronous code (Apple)](https://developer.apple.com/documentation/Testing/testing-asynchronous-code)
*   [The Practical Test Pyramid (martinfowler.com)](https://martinfowler.com/articles/practical-test-pyramid.html)
*   [Software Testing Guide (martinfowler.com)](https://martinfowler.com/testing)
*   [Test Double (martinfowler.com)](https://martinfowler.com/bliki/TestDouble.html)
*   [iOS unit testing guidelines (iflix, GitHub, secondary; written for Quick and Nimble, only the general principles were used)](https://github.com/iflix/ios-unit-testing-guidelines)
*   [How to write unit tests for your SwiftData code (Hacking with Swift, secondary)](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-write-unit-tests-for-your-swiftdata-code)
*   [Writing testable UI related code with modern Swift (Swift Forums, secondary)](https://forums.swift.org/t/writing-testable-ui-related-code-with-modern-swift/77944)
SwiftUI components:
*   [Reducing view modifier maintenance (Apple)](https://developer.apple.com/documentation/swiftui/reducing-view-modifier-maintenance)
*   [Encapsulating SwiftUI view styles (Swift by Sundell)](https://swiftbysundell.com/articles/encapsulating-swiftui-view-styles)
*   [Avoiding massive SwiftUI views (Swift by Sundell)](https://swiftbysundell.com/articles/avoiding-massive-swiftui-views)
*   [SwiftUI Craftsmanship: ViewModifiers (Captain SwiftUI, secondary)](https://captainswiftui.substack.com/p/swiftui-craftsmanship-viewmodifiers)
*   [Strategies for building reusable views in SwiftUI (Medium, secondary)](https://medium.com/@etoedia/strategies-for-building-reusable-views-in-swiftui-fd5716a9bf6d)
*   [Build a reusable SwiftUI component library (DEV Community, secondary)](https://dev.to/sebastienlato/build-a-reusable-swiftui-component-library-15i3)
What comes from the sources and what is the team's own: smell definitions and treatments, SwiftLint defaults, Swift Testing features, the test pyramid and test double definitions, and the modifier, style, and container guidance come from the pages above. Adopting the SwiftLint defaults as team limits, the five checks, the type-split tables, the test folder layout, tags and test plans, the reader evaluation approach, the rule of extracting a component on its second use, the component rules, and the review rules are this guide's own conventions.