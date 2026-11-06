# Symbol legends for the extractor

> Plan to use the four symbol legends in `Core/Resources/Legends` in every layer of the floor plan extractor, and to carry what they find into the app. Findings come from reading the PDFs, the extractor package at `../bazaar/floor-plan-extractor/legend-only` (Swift, `Sources/Extractor`) and the app code on `feature/project-setup-reading`, not from running either. It follows `ArchitectureGuide.md` and `DeveloperAgreement.md`.

## Decisions already made

| Question | Decision |
| ---| --- |
| What the PDFs are | Reference sheets of symbols and class names, the same for every plan. The per-plan legend image only holds booth and zone colours |
| Where the work lives | Reading and matching in the extractor package. Mapping to layout objects in `ExtractedLayoutMapper` |
| Old behaviour | Without symbols the extractor runs as it does today, so the six plans keep their scores until a slice improves them |

## What the legends hold

43 classes on 7 pages, each a symbol thumbnail and a name. Some thumbnails sit on a tinted ground (cyan, red, beige, lavender) that belongs to the sheet, not the symbol.

| File | Classes |
| ---| --- |
| `legend-walls.pdf` | 4 wall styles: double line, thin, thick, medium |
| `legend-doors.pdf` | 9: single door (quarter arc, quarter arc in double wall, half disc), double door (two arcs, arcs in thin wall), gate (butterfly, butterfly with frame), door row scalloped, door bow-tie |
| `legend-tables-seating.pdf` | 6: table outline, outline compact, blue filled, red outline, theater chairs as circles, theater chairs as blue squares |
| `legend-misc.pdf` | 24: columns (hollow square, solid square, solid square on wall, hollow circle), stairs (ladder, boxed), restrooms (black circle, framed figures), safety (fire point, emergency exit left and right, assembly point, ambulance), info desk, arrows (entry, exit, circulation), zones (stage grey, red and dark grey, neighboring unit, unlabeled block, standing zone, service room) |

## Where the extractor stands

- `Layers.swift` has four layers: booth, wall, door, seat. `Layer.of` sorts items by class: `wall` and `pillar` to wall, `door` and `opening` to door, `object` to seat, everything else to booth.
- Only the booth layer reads a legend, as colour swatches (`Legend.swift`). The wall, door and seat layers find shapes by geometry: parallel line pairs and stroke thickness (`WallLayer`), arcs standing on a wall (`DoorLayer`, `DoorArcs`), chair circles and ink blobs (`SeatLayer`).
- Stairs, restroom icons, safety signs and arrows have no layer. Stairs end up as `object` in the seat layer (the comment in `SeatLayer.swift` says so), and the rest is noise or false booths.
- `PlanExtractor.plan(_:legend:)` takes the plan legend image and nothing else. `PlanItem` carries `cls`, `kind`, `width` and `chairs`, but no symbol class.
- In the app, `ExtractedLayoutMapper` switches on the strings `wall`, `pillar`, `opening`, `blocked`, `entrance`, `exit`, `door`, `object`, and on legend names for hall classes (`isHallClass`). Since the kind cut it makes walls, doors, blocked areas and blocks, and drops tables and the audience area.

## Symbol library

1. A script in the extractor repo (`scripts/make_symbol_library.py`, pymupdf like the other builders) reads the four PDFs and writes `legends.json` and one PNG per class. The JSON holds `id`, `name`, `layer` and `file`. The PDF text layer gives exact names, so no OCR is needed. The script crops each symbol, drops the sheet's tinted ground, and keeps the colour as its own field because some classes differ only by colour (table blue filled against outline, the three stage greys).
2. Class ids are stable and dotted: `wall.double`, `wall.thin`, `wall.thick`, `wall.medium`, `door.single_quarter`, `door.single_quarter_double_wall`, `door.single_half_disc`, `door.double_two_arcs`, `door.double_thin_wall`, `gate.butterfly`, `gate.butterfly_frame`, `door.row_scalloped`, `door.bow_tie`, `table.outline`, `table.outline_compact`, `table.blue_filled`, `table.red_outline`, `seats.theater_circles`, `seats.theater_squares`, then `column.*`, `stairs.*`, `restroom.*`, `safety.*`, `info.desk`, `arrow.*` and `zone.*`.
3. The output is committed under `Core/Resources/Legends/symbols/` in the app and read by the extractor through a `SymbolLegend` type: `SymbolLegend.load(from: URL)` and `entries(for: Layer)`.
4. `PlanExtractor.plan(_:legend:symbols:)` gains an optional `symbols` argument, default empty. `PlanItem` gains `symbolClass: String?` and `symbolScore: Double?`.

Test: the library holds 43 entries with unique ids, 4 walls, 9 doors, 6 tables and seating, 24 misc.

## Matching

Each layer already produces candidates, so the legend only classifies them. One shared `SymbolMatcher` takes a candidate crop and the entries of one layer and returns the best class and a score, or nothing below a threshold.

- First cue is shape: the Vision feature print the package already uses for IDs (`FeaturePrintStats`), on the symbol ink only, at several scales set from the median booth size.
- Second cue is colour, used only where the legend says a class is told apart by it.
- A candidate with no match keeps today's class and `needsReview`. The legend never removes an item that the geometry found.

## Layers

1. Booth layer. The six misc zone colours (stage grey, red and dark grey, neighboring unit, unlabeled block, standing zone, service room) become known non-booth colours, so those fills stop being matched to booth classes or read as unlabeled booths. This replaces the name list in `isHallClass`.
2. Wall layer. The four wall styles give stroke profiles (line count, gap, thickness) that confirm or reject candidate lines in place of the global `dmin`, `dmax` and `thick` thresholds. Each wall item gets `kind` set to its style. The four column classes drive `columnLayer` (hollow, solid, on a wall, circle) and set `kind` on pillars.
3. Door layer. The nine door classes decide what an arc group is: one quarter arc, a half disc, two arcs, a butterfly gate, a scalloped row, a bow-tie. The class replaces the arc-count note in the review reason and sets the leaf count. A scalloped row yields one opening per scallop.
4. Seat layer. Table classes tell a table from stairs and from audience rows. The two theater classes mark audience seating, whose chairs belong to no table. `kind` stays `table` and `chair`, and `symbolClass` says which style.
5. Misc layer, new. `Layer` gets a fifth case with `misc.json`. Stairs, restrooms, safety signs, info desk, ambulance and arrows are matched on the ink the other layers left over, and emitted as items with class `misc`, `kind` set to the family and `symbolClass` to the id. This takes stairs out of the seat layer.

## App mapping

`DetectedItem` gains `symbolClass`. `ExtractedLayoutMapper` maps by class family through one table, not string compares on `cls`:

| Family | Layout object |
| ---| --- |
| `wall.*` | wall, thickness from the style (double 0.2 m, medium 0.15 m, thin 0.1 m, thick 0.3 m) |
| `door.*`, `gate.*` | door, one per opening. Directions still come from markers |
| `column.*`, `stairs.*`, `restroom.*`, `zone.stage_*`, `zone.service_room`, `zone.unlabeled_block` | block |
| `arrow.entry`, `arrow.exit` | layout markers, which `MockLayoutMapper` already uses to set door direction |
| `table.*`, `seats.*`, `zone.neighboring_unit`, `zone.standing`, `safety.*`, `info.desk`, `arrow.circulation` | dropped |

The loader goes in `Core/Services/FloorPlanReading` as `SymbolLegendStore`, which `ExtractorFloorPlanReader` hands to `PlanExtractor.plan`. The `legend-only` package reference stays as it is.

## Scoring

The package scores each plan against `truth.json` and `truth_px.json` (`scripts/score.py`). Every slice must keep the current table in `docs/handoff.md` (tiles, IDs, pillars, doors, wall precision and recall) at or above its numbers. `truth.json` has no door types, wall styles, stairs or restrooms, so `score.py` gets a class confusion report and plans 1, 2 and 6 get a hand-checked `symbols.json` of expected classes, built like `seats.json`.

## Order

1. Symbol library script and resources, with the count test.
2. `SymbolLegend`, `SymbolMatcher` and the optional API argument, with no change in output.
3. Misc layer and the booth-layer exclusions. It removes false booths, so it moves the booth scores first.
4. Walls and columns.
5. Doors.
6. Seats.
7. App mapping, bundling, `ArchitectureGuide.md` and the extractor README.

Each slice is one commit in the repo it touches, with scores before and after on the six plans in the message.

## Risks

- Each class has one thumbnail of about 50 px, some blurred (table red outline). Shape matching on one example is brittle, so the threshold starts strict and a miss falls back to today's geometry.
- Plans draw the same class in different sizes and line weights. The scale search uses the median booth size, which is itself assumed on plans 2 and 5.
- Plans 5 and 6 score 0% on walls against `truth_px.json` today and 0/4 on doors, so wall and door styles will not help there until their detection does.
- A symbol class can appear on a plan that the legend names differently (plan 6 draws TOILET as framed figures, which is `restroom.framed`). Matching is by shape, not by name.

## Out of scope

User-editable legends, a trained model, door swing direction, and tables, seating and safety signs as layout objects.

## Open questions

1. Whether the symbol library is built once by the script and committed (recommended, no PDF parsing at run time and the app stays deterministic), or read from the PDFs when the app starts.
2. Whether the misc mapping above is right, in particular stairs and restrooms as blocks, and entry and exit arrows as markers.
3. Whether the extractor changes are made in `../bazaar/floor-plan-extractor/legend-only` with its own commits (recommended), since it is a separate repository from this app.
