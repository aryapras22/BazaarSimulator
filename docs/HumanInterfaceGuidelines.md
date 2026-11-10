# Apple human interface guidelines

Reference guide for Apple Human Interface Guidelines (HIG) tailored for Bazaar Simulator, a macOS SwiftUI app targeting macOS 27. It covers macOS core design principles, foundations, interface patterns, components, and their application to the app.

## core design principles

- Deference: the interface recedes so the user's primary work and content remain central.
- Clarity: controls, labels, and icons convey exact intent across all resolutions and display sizes.
- Depth and hierarchy: windows, split panes, and floating accessories use spatial layering, materials, and soft shadows to communicate modal states and active contexts.
- Desktop ergonomics: interactions assume high-precision pointing devices, trackpad gestures, fluid window resizing, and keyboard-driven efficiency.

## foundations

### layout and window structure

- Mac windows adapt to arbitrary dimensions, aspect ratios, and user displays. Layouts accommodate flexible window resizing rather than fixed screen geometries.
- Minimum window dimensions enforce readability and ensure controls remain unclipped.
- Standard spacing follows 4 pt or 8 pt multiples, aligning controls with system margins and baseline grids.
- Window chrome integrates window controls (close, minimize, zoom) alongside toolbars to preserve vertical work area.

### typography and sf symbols

- The system font family is San Francisco (SF Pro), paired with SF Mono for tabular or metric data.
- Standard text styles (largeTitle, title, headline, body, callout, caption) scale with accessibility settings and maintain proportional line heights.
- SF Symbols align with typography weights and provide vector iconography that scales across control sizes.
- Tabular figures (`.monospacedDigit()`) format numerical counters, coordinates, scale ratios, and financial tallies to prevent jitter during updates.

### color and materials

- Semantic colors adapt across light and dark appearances, ensuring contrast against varied desktop backgrounds.
- Functional controls use accent and tint colors sparingly to draw attention to primary workflows.
- Content layers use opaque backgrounds or standard dark neutral surfaces to preserve legibility.
- Translucent materials and Liquid Glass reside exclusively in navigation and control chrome floating above content. Stacking glass over glass is avoided.

### accessibility

- VoiceOver: every interactive element provides an accessible label, a clear accessibility trait, and descriptive hints where purpose is non-obvious.
- Reduce Transparency: views with materials or Liquid Glass replace blur effects with solid contrast fills when this setting is active.
- Increase Contrast: borders and focus rings sharpen, while text contrast ratios meet WCAG AA standards (minimum 4.5:1 for body copy).
- Reduce Motion: spatial animations and transitions collapse into immediate state switches or soft crossfades.

## patterns

### navigation and split views

- Three-pane and two-pane structures rely on `NavigationSplitView` to handle sidebar collapsing, detail views, and window-wide state.
- Sidebars hold top-level navigation lists and document libraries, adopting translucent system backgrounds.
- Selected items in sidebars display persistent selection highlights and update the detail canvas immediately.

### toolbars and window headers

- Primary actions occupy the window toolbar, grouping related actions with spacers and segmented pickers.
- Infrequent or destructive actions stay out of primary toolbars and remain accessible through app menus.
- Window subtitles provide document-level metadata, such as file origin, scale assumptions, or dirty state.

### menus, shortcuts, and direct manipulation

- Menu bar items expose every core application capability under standard top-level menus (File, Edit, View, Window, Help).
- Standard shortcuts (`Cmd+N`, `Cmd+O`, `Cmd+S`, `Cmd+Z`, `Cmd+Shift+Z`) map to universal actions without redefinition.
- Number keys and modifiers (`Cmd+1`, `Cmd+2`) switch structural editing layers and view perspectives.
- Direct manipulation enables intuitive interactions: click to select, shift-click or marquee to multi-select, drag to move, and pinch to zoom.
- Contextual menus opened by secondary click offer immediate operations relevant to the targeted object.

### sheets, inspectors, and modal tasks

- Modal tasks that require user confirmation before continuing open as sheets attached to the parent window.
- Sheets contain distinct dismissive (Cancel) and affirmative (Continue, Apply, Save) action buttons.
- Inspectors display secondary properties and fine-tuning controls for selected items, either docked in a split pane or floating alongside the canvas.

## components

### buttons and segmented controls

- Push buttons indicate single discrete actions, using prominent tinting for the primary action in a view.
- Segmented controls switch between mutually exclusive perspectives or editing layers.
- Glass button styles (`.buttonStyle(.glass)`) apply only to floating controls suspended over the canvas.

### forms, pickers, and text inputs

- Form layouts align labels and inputs in consistent vertical columns with unambiguous units (m, px, %).
- Numerical input fields parse numeric text, clamp invalid boundary values, and format values on commit.
- Pickers provide explicit choices without hidden options, using pop-up buttons for short lists and search fields for long collections.

### feedback and progress indicators

- Determinate progress indicators report fractional completion during multi-stage imports and parsing tasks.
- Indeterminate spinners indicate ongoing background processing when progress cannot be calculated.
- Warning banners and issue badges display inline validation states without blocking normal interaction.

## application to bazaar simulator

| Screen / Area | HIG Pattern | Project Implementation |
| --- | --- | --- |
| Project library | Sidebar navigation list with integrated search field | [`ProjectLibraryView`](file:///Users/arya/projects/ada/BazaarSimulator/BazaarSimulator/Features/ProjectLibrary/Views/ProjectLibraryView.swift) in split view sidebar |
| Project setup | Modal file drop and progress review sheet | [`ProjectSetupView`](file:///Users/arya/projects/ada/BazaarSimulator/BazaarSimulator/Features/ProjectSetup/Views/ProjectSetupView.swift) with per-file status rows and Cancel/Continue |
| Layout editor toolbar | Unified window toolbar with segmented view presets | [`LayoutEditorView`](file:///Users/arya/projects/ada/BazaarSimulator/BazaarSimulator/Features/LayoutEditor/Views/LayoutEditorView.swift) with Structure/Booths tabs and shortcuts |
| Layout editor canvas | Direct manipulation canvas with zooming and panning | [`CanvasSceneRenderer`](file:///Users/arya/projects/ada/BazaarSimulator/BazaarSimulator/Features/LayoutEditor/ViewComponents/CanvasSceneRenderer.swift) with marquee selection and hover |
| Layout editor inspector | Inspector panel with grouped property controls | `InspectorPanel` presenting single-object, group, and wall properties |
| Parameters dialog | Modal configuration sheet | `ParametersDialog` with Cancel and Apply buttons |
| 3D simulation | Tabbed metric views with playback transport bar | Simulation screen with Density, Congestion, and Footfall tabs and timeline controls |
