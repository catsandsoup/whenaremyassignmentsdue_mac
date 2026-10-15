# Native reader actions implementation plan

> **For agentic workers:** Use superpowers:executing-plans inline; user explicitly requested scope and implementation together. Run a fresh review of the completed change.

**Goal:** Make feedback and rubrics reusable and PDF interactions familiar, preserving the deadline agenda and silent credential behaviour.
**Architecture:** Pure value-to-text export, small native interaction adapter (AppKit clipboard and SwiftUI Transferable), one shared reading-size preference based on native semantic font metrics. Views project selected identity as before. No schema changes or new API calls.
**Tech stack:** macOS 27, SwiftUI, AppKit, CoreTransferable, UniformTypeIdentifiers.
**Spec:** The user's native-first/copyable-content requirements recorded in AGENTS.md and the previous turn's proposed refinements.

## Acceptance contract

- Copy Feedback includes course/title, released mark or explicit source/unavailability, previous-attempt distinction, all lecturer comments with author/time and attachment filenames. Never copy signed URLs, credentials, local file paths, raw API payloads or unposted numeric grades.
- Copy Rubric includes all criteria/long descriptions and every rating, independent of disclosure state. Include assessed comments/awarded zero and fractions, assessment type/attempt; obey hidden-points flags. No structured rubric means the action is unavailable; PDF-only rubrics use the file actions.
- Native List Copy (⌘C) copies selected assignment feedback. Reader text selection retains standard range-copy behaviour. Explicit named actions live in a compact toolbar menu and rubric heading; copy actions report a quiet accessible confirmation.
- Sidebar right-click targets the clicked assignment, even if another row is selected. File right-click offers Open, Quick Look, Save, and Reveal in Finder for cached files.
- Cached PDFs are draggable using Transferable FileRepresentation; share uses ShareLink. Export the actual PDF bytes with a useful filename, never the Canvas URL or cache path text. No drag gesture/download subsystem.
- Important reader text is selectable, including rubric headings/ratings/points and metadata.
- Text-size menu offers Larger/Smaller/Actual Size using standard ⌘+/⌘−/⌘0 shortcuts. Persist a bounded size setting only for marks/feedback. Derive font sizes from native text-style metrics, preserve heading hierarchy; wrap/scroll at large size. Default system semantic fonts and accent remain unchanged.
- Keep deadline view, Keychain handling and SwiftData schema unchanged.

## Tasks

1. [x] Add failing synthetic export/reading-bound tests; implement pure FeedbackExport and reading-size model. Prove complete source order, hidden points, unavailable/unposted/zero distinctions and no token-bearing URLs.
2. [x] Add native PDF Transferable and a file-representation byte round-trip test. Wire copy/context menus, selectable text, drag/ShareLink and reading controls using small focused view helpers.
3. [ ] Run full regressions/build; native light/dark checks for copy scope, selection replacement, context menus, file export, keyboard and largest reading size. Fresh review, document limits, install/sign-verify and push source.

## Sources and rulings

Context7 official SwiftUI docs: textSelection, copyable, contextMenu(forSelectionType:), Transferable/FileRepresentation, draggable and ShareLink. macOS dynamicTypeSize does not change user text size; reading controls must be explicit and tested. Use native NSFont preferred text-style metrics for the larger reading setting; no custom typeface, colour or gesture system.

Progress: Task 1 complete; export checks were observed failing before implementation and pass. Task 2 implemented; native PDF byte export passed, filename round-trip failed, then passed after providing a named export copy in a system-managed replacement directory. Native clipboard checks verified real complete rubric/feedback content. User clarified no-spaghetti disclosure design: researched HIG/first-party/third-party source and replaced manual sidebar indicators with Section(isExpanded:), rubric repeated sub-controls with criterion-labelled DisclosureGroup. Fresh review found no important correctness issues; enlarged heading weight refinement applied using the native font descriptor. Native final verification/release remains.
