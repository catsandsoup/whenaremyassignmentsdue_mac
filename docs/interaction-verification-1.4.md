# Interaction verification and motion review — 1.4

15 October 2026. This release adds assessment-level Quick Look, keyboard search handoff, submission-file cache retention, browser navigation and an application icon. The deadline view, SwiftData schema and Keychain implementation are unchanged. VoiceOver testing was explicitly excluded by the user after runtime activation could not be verified.

## Test evidence

The full test script reports 14 PASS checks. New preview checks cover feedback-first/current-submission ordering, file-identity deduplication, multiple URLs, partial failure recovery, cancellation preventing an old assessment from reopening, and immediate cached preview while another download is pending. Persistence checks exercise submission-download retention across refresh and disk reopening. Tests use synthetic records and temporary files.

Native runtime checks observed Command-F search with ordinary spaces, Return and Down Arrow selecting the filtered assessment, Space opening the cached PDF in native Quick Look, and the toolbar preview action. Quick Look exposed the document's actual pages and native Open/Share/navigation controls. Escape dismissal returned to the reader; subsequent accessibility observations confirmed the assessment remained selected. Some observations arrived while the native panel was transitioning, so no exact timing or universal focus-return certification is claimed.

Light-mode reader controls were inspected. The final dark-mode reader was enlarged to 200% in a minimum-width window: title and row text wrapped, the PDF card adapted vertically, Open/Save remained within the reader, and vertical scrolling remained available. Command-zero restored ordinary reading size. Accessibility-tree inspection confirmed distinct assessment, Feedback, Lecturer comment and Rubric headings, labelled actions and native disclosure state. These are accessibility structure checks, not a VoiceOver pass.

The automated native PDF Transferable test verifies byte equality, human filename, writable exported copy and unchanged read-only original. An attempted drag to Finder desktop did not produce a verified received file. End-to-end Finder/AI-editor receiving behaviour remains unresolved and is not presented as passed. Previous Open/Quick Look/Save cancellation observations remain applicable; a complete keyboard-only journey through every system panel and external-display testing is not claimed.

## Button and motion contract

| Control | Result and state | Native mechanism / motion |
| --- | --- | --- |
| Assessment row / arrow keys | Replace the complete reader by assignment identity; cancel old preview work. | SwiftUI List/NavigationSplitView. No crossfade mixing unrelated academic content. |
| Search / Return / Down / Escape | Local filter; transfer to selected/first visible result; Escape clears search and returns list focus. | TextField, FocusState, onSubmit and focused onKeyPress. |
| Course triangle / criterion triangle | Hide/reveal related content in place. | Sidebar Section(isExpanded:) and DisclosureGroup; system transition behaviour, no custom chevrons or spring choreography. |
| Space / Quick Look / Command-Y | Preview feedback and current-submission files; cached files appear without waiting for network requests. | SwiftUI collection quickLookPreview. Dismissal cancels pending files, preventing a late reopen. |
| File Open / Preview / Save | Open the system handler, preview one attachment, or choose an export destination. | NSWorkspace, Quick Look and NSSavePanel. Busy indicator overlays the existing Open label footprint, avoiding a width-driven layout switch. |
| Copy actions | Complete contextual text independent of disclosure state. | Native pasteboard, accessibility announcement and quiet confirmation; no forced navigation. |
| Open in Canvas | Selected assessment's stable Canvas route in the default browser. | Native Link; remains visible but disabled with no selection so adjacent controls do not jump. Browser authentication remains Canvas's own behaviour. |
| Text Size / Command-plus/minus/zero | Change reader text scale, preserve semantic font hierarchy and wrap/scroll. | Native font descriptors, AppStorage, ViewThatFits; affects the feedback reader only. |
| Refresh / warning | Update available data; retain saved content on failure; show explanation on request. | Existing progress indicator and native popover. No blocking replacement connection screen. |
| Close reader / Quit | Closing reader retains menu-bar utility; Quit ends app. | Native window lifecycle. No custom minimise/zoom animation or attention bounce. |

Two concrete layout shifts were corrected: removing Open in Canvas when selection cleared, and replacing a short Open label with a wider Downloading label. Source contains no custom withAnimation/animation/transition choreography. Native controls own their transitions; this does not prove zero frame drops. Frame-level profiling and Reduce Motion/Contrast/Transparency sweeps remain future checks.

Apple's [Motion HIG](https://developer.apple.com/design/human-interface-guidelines/motion), [Quick Look user interaction](https://support.apple.com/guide/mac-help/preview-a-file-mh14119/mac) and [collection preview API](https://developer.apple.com/documentation/swiftui/view/quicklookpreview(_:in:)) inform the interaction contract. No motion is added merely to make a button feel active.

## Dock, browser and related assessments

The app remains a menu-bar utility (`LSUIElement`), with no persistent Dock or application-switcher entry. This follows the common menu-bar-only behaviour described by [MenuBarExtra documentation](https://developer.apple.com/documentation/swiftui/menubarextra). The icon identifies the app in Finder and system presentation; it does not require adding a permanent Dock presence. A future regular-app mode would need explicit window/reopen/Dock-menu design rather than changing activation policy on every click.

Browser-only student actions are reached through Open in Canvas; the app does not pretend that an API key authenticates the browser or implement submission writes.

Related assessments remain separate academic records. Identical bytes are already deduplicated in storage with assignment provenance retained. A shared hash is evidence of identical files, not proof of a common brief, rubric, deadline or result. Future related-assessment navigation should use explicit Canvas references or student-confirmed relationships, preserve individual deadlines/submission attempts, and clearly label shared versus assessment-specific materials. No speculative automatic grouping is implemented.

The generated icon source is `Assets/AppIcon.png`; build.sh packages native .icns sizes using sips/iconutil. Private records, downloaded feedback, screenshots and credentials remain outside this repository.
