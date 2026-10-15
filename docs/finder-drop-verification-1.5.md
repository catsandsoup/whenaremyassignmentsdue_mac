# Attachment controls and Finder verification — 1.5

15 October 2026. Deadline agenda, credential handling, API requests and SwiftData schema are unchanged.

## Controls corrected

The browser link and Quick Look previously shared one glass background and looked like one compound action. A native `ToolbarSpacer(.fixed, placement: .primaryAction)` now separates them into distinct logical groups, following Apple's [toolbar guidance](https://developer.apple.com/documentation/swiftui/landmarks-refining-the-system-provided-glass-effect-in-toolbars).

The attachment's Open, Quick Look and Save actions now form one row rather than a prominent Open/Save row and a detached link underneath. Open uses the standard bordered style; Quick Look uses a labelled native eye button with a tooltip. The filename aligns beside the document icon, and ViewThatFits retains the vertical alternative when horizontal space is insufficient. Native dark-mode inspection confirmed the separated toolbar groups and compact file-action row.

Drag, Share and Save now use the same readable name shown in the card. A reattached earlier presentation retains that document's earlier presentation name and duplicate-source explanation; it is not silently relabelled as a new result. The original remote filename remains in the title tooltip.

## Automated receiving-path evidence

The full test suite reports 14 PASS checks. The PDF test now registers the real FeedbackPDF Transferable with NSItemProvider and loads its PDF file representation through the native receiving API. Assertions verify ASCII and Unicode names, one `.pdf` extension and exact bytes. Existing tests verify source filename rather than the content hash, writable exported copies, unchanged managed originals and missing-file failure.

Apple documents [suggestedFileName](https://developer.apple.com/documentation/coretransferable/transferrepresentation/suggestedfilename(_:)-47rg0) as including the extension. The exporter retains that documented contract. No unverified extension-stripping workaround, custom drag gesture or handwritten file-promise implementation was added.

## Actual Finder acceptance status

The computer-use drag action did not produce a file in the clean Finder destination. Calibration then failed to move an already selected synthetic text file into a folder within Finder itself; this prevents interpreting the failed app drag as proof of an exporter defect.

The user authorised a native XCUITest fallback. Its test target built successfully, but runner attempts failed before the test established a connection. The last result reported: “Early unexpected exit, operation never finished bootstrapping” and “Test crashed with signal kill before establishing connection.” No drag assertion executed. The host also reported an outdated CoreSimulator service; a causal connection to this macOS runner failure has not been established. Security protections and developer-mode settings were not changed.

A manual drop into the prepared Finder destination was offered; the user chose to skip it. Actual Finder drag/drop therefore remains unverified. Item-provider success is not represented as Finder success. Test runners/results, calibration files and any real received PDFs remain outside this public repository.
