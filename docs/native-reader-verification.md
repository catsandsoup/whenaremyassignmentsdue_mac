# Native reader refinement verification — 1.3

15 October 2026. Scope: complete copy, native disclosure/context/file controls and larger reading size. Deadline agenda, API requests, SwiftData schema and credential handling are unchanged.

## Automated evidence

`./test.sh` completed successfully after the final source changes, reporting 13 PASS checks across the existing and new test executables. These cover deadline/date/enrolment behaviour; cache retention; own-user GET-only API mapping; selection replacement; released/unposted/zero distinctions; SwiftData disk reopening; file validation and safe redirects; shared silent credential reads; complete context-preserving text exports; and native PDF Transferable export.

The new synthetic export assertions check every collapsed rating, source order, long descriptions, hidden points, awarded zero/fractions and assessment attempt/type. They exclude signed URLs, private paths and unreleased numeric marks. PDF round trips check exact bytes, original filename rather than content-hash filename, missing-file failure and writable exports that leave the read-only original unchanged. Reading-size bounds include 200%.

`build.sh` completed successfully for the release app. Existing legacy Keychain API deprecation warnings remain; credential code was not changed or interactively probed for this refinement.

## Native runtime observations

- Native light and dark reader layouts inspected, including PDF and structured-rubric records. Selecting Written Report replaced the previous presentation's PDF/comment content with its rubric and unavailable-feedback state.
- Copy Feedback and Copy Rubric were pasted into a native text field to verify actual clipboard content. A collapsed rubric exported its final criterion and full rating descriptions. No-match search cleared the old reader.
- Native course sections expose expanded/collapsed accessibility state; rubric controls expose criterion title, points and disclosure state instead of repeated generic “Rating descriptions” buttons.
- Command-plus enlarged the reader to 200% in a minimum-width window. Titles and rows wrapped; the file card adapted vertically, its Open/Save actions remained reachable, and scrolling remained available. Command-zero restored the persisted setting to 100% (confirmed by reading the preference).
- Native context menus and their available actions were inspected. A complete right-click-unselected-row clipboard target round trip was interrupted, so it is not claimed as a completed runtime check; the action uses SwiftUI's selection-aware clicked identifiers.
- Installed 1.3 was opened with the real local cache and completed an automatic refresh without a credential dialog. Right-clicking the PDF icon exposed Open PDF, Quick Look, Save, Show in Finder and Share. Right-clicking its selectable filename preserved native text services instead; these are intentionally different pointer targets.
- Prior release checks exercised real PDF Open, Quick Look and Save cancellation. This release adds automated byte/filename/permissions verification; that is not a substitute for every receiving application's drag/drop behaviour.

## Remaining manual acceptance matrix

Full keyboard-only and VoiceOver journeys, focus return from preview/sheets, Space on focused file cards versus child buttons, real Finder/AI-editor drag destinations, Preview's read-only duplicate/edit behaviour, Increase Contrast, Reduce Transparency, non-default accent, and physical external-display/clamshell connect/disconnect remain explicit manual checks. No blanket HIG/accessibility certification is claimed.

Show in Finder currently reveals the managed hash-named original. Tracking user-exported/annotated copies is future scope. Siri/App Intents, MCP, PDF OCR/annotation extraction and a complete course-file inventory are not implemented.
