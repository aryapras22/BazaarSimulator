# SwiftUI updates for the 27 SDKs

> Condensed from Apple's [SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui) page, fetched 3 November 2026. Entries are grouped as Apple groups them. Check each API's own page for exact availability before use; some are iOS only.

## June 2026 (Xcode 27, iOS 27, macOS 27)

### General

*   `@State` uses the `State()` macro when you build with Xcode 27 or later. For class values, the property is initialized and stored only once, which removes the old pitfall of a class being re-created on every view init.
*   `ContentBuilder` is the single result builder for type-agnostic content built from closures, replacing type-specific builders such as `ToolbarContentBuilder` and `CommandsBuilder`. New APIs (for example `safeAreaBar`) are declared with `@ContentBuilder`.
*   Drag-and-drop reordering in any container (lists, stacks, grids, custom layouts): `reorderable()` and `reorderContainer(for:isEnabled:move:)`.
*   Custom swipe actions in any container: `swipeActions(edge:allowsFullSwipe:content:onPresentationChanged:)` with `swipeActionsContainer()`.

### Transitions

*   `crossFade` transition for sheets that fade in over content.

### Images

*   `AsyncImage` can cache downloads: `asyncImageURLSession(_:)` and request-based initializers such as `init(request:scale:)`.

### Toolbars

*   `visibilityPriority(_:)` keeps important items visible as space shrinks; lower-priority items move to the overflow menu first.
*   `ToolbarOverflowMenu` sends secondary actions straight to the overflow menu (iOS, iPadOS, Mac Catalyst, visionOS).
*   `topBarPinnedTrailing` placement pins an item to the trailing edge of the top bar.
*   `toolbarMinimizationBehavior(_:for:)` minimizes bars in response to scrolling.

### Documents

*   URL-based documents: conform to `ReadableDocument`, and to `WritableDocument` for writing, to read large files directly from a file URL.
*   Custom reading and writing with `DocumentReader` and `DocumentWriter`, or `FileWrapperDocumentReader` and `FileWrapperDocumentWriter`.
*   `URLDocumentConfiguration` gives the file URL, modification date, and coordinated access.
*   Export with `fileExporter(isPresented:document:contentType:defaultFilename:onCompletion:onCancellation:)`.

### Tab bars

*   `prominent` tab role places a tab in a separate trailing position.

### Alerts and confirmation dialogs

*   Present from an optional item or an error, using the value to build the title and content: `alert(_:item:actions:)`, `alert(error:actions:)`, the `message:` variants, and `confirmationDialog(_:item:titleVisibility:actions:)` with its `message:` variant.

### Gestures

*   Gestures can restrict their input sources (direct or indirect touch, pencil, pointer) through new initializers on `DragGesture`, `LongPressGesture`, `MagnifyGesture`, `RotateGesture`, `RotateGesture3D`, `SpatialEventGesture`, `SpatialTapGesture`, `TapGesture`, and `WindowDragGesture`. See `GestureInputKinds`.

## September 2026

### Arrangement views

*   `ArrangementView` lays out primary and secondary content adaptively. Style it with `arrangementViewStyle(_:)`, or write a custom `ArrangementViewStyle`.
*   `split` style places the two side by side; constrain axes with `axes(_:)`, size with `splitArrangementLayoutRatio(...)`, `splitArrangementLayoutSize(...)`, or `splitArrangementFixedLayoutSize(horizontal:vertical:)`. Read the current axis from the `splitArrangementAxis` environment value.
*   `overlay` style layers primary over secondary; anchor it with `overlayArrangementEdge(_:)` and read `overlayArrangementZIndex`.

### Hardware regions and iPhone Duo

*   `ReservedRegion` and `reservedRegions(kind:options:layoutDirectionBehavior:)` describe areas reserved by hardware (camera, hinge), with kinds such as `.occlusion` and `.division`.
*   `onHingeChange(isEnabled:_:)` and `DeviceHinge` report the hinge angle and state on iPhone Duo; `CameraCaptureAccessory` presents content on the outer display during camera capture.

### Controls on the vertical axis

*   `toolbarVerticalEdge` environment value, `toolbarVerticalBehavior(_:)`, `axisBehavior(_:)` with `ToolbarItemAxisBehavior`, and `toolbarVerticalCompressionBehavior(_:)` manage bars the system places on a vertical edge.

## June 2025 (26 SDKs): the Liquid Glass baseline

These arrived one year earlier and are the base of the Liquid Glass design. Details are in `LiquidGlassSwiftUIAPI.md`.

*   `glassEffect(_:in:)` and `.buttonStyle(.glass)`.
*   `ToolbarSpacer` for visual breaks between glass toolbar groups.
*   `scrollEdgeEffectStyle(_:for:)`.
*   `backgroundExtensionEffect()`.
*   `tabBarMinimizeBehavior(_:)`, the `search` tab role, `TabViewBottomAccessoryPlacement`.
*   Also in that release: `WebView` with `WebPage`; multi-item drag with `draggable(containerItemID:containerNamespace:)` and `dragContainer(for:itemID:in:_:)`; the `Animatable()` macro; `Slider` tick marks when initialized with `step`; `windowResizeAnchor(_:)`; `TextEditor` with `AttributedString`, `AttributedTextSelection`, `AttributedTextFormattingDefinition`, and `FindContext`; `NSHostingSceneRepresentation` and `NSGestureRecognizerRepresentable` for AppKit integration.

## Relevant to this project

| Change | Where it matters here |
| --- | --- |
| `@State` macro (Xcode 27) | Views such as `RootView` that hold classes in `@State` (`AppRouter`, `ProjectScreenFactory`, view models) no longer risk re-creating them on each init |
| `ContentBuilder` | Custom containers like `InspectorPanel` that take `@ViewBuilder` closures keep working; new code can use `@ContentBuilder` where Apple's APIs do |
| `visibilityPriority(_:)` (macOS 26.1) | Keep the editor's most important toolbar items (back, tool buttons) visible in narrow windows |
| Gesture input kinds | The canvas `DragGesture` and `MagnifyGesture` can be limited to pointer or trackpad input if needed |
| Alerts from items and errors | The group delete confirmation (`pendingGroupDelete`) could use `confirmationDialog(_:item:...)` |
| Reorderable containers | A future layout list or group list could reorder by drag without custom code |
