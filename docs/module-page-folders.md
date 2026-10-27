# Module materials organised by source page

The Module Files window and Downloads use the same saved source-page groups. A subject export contains module folders in Canvas order; each module contains folders titled after the tutorial, lecture or other Canvas page. Direct module attachments use “Module files”. Each page folder includes the original attachment names, page text and a clean Page source.txt link. Links for the module live under “Module information”.

A shared attachment is downloaded once and copied under each page that links to it. Page groups preserve Canvas page order. Safe names and case-insensitive collision suffixes prevent duplicate titles or filenames from overwriting content. The existing atomic export creates a new folder for each save, preserving earlier downloads.

Page groups retain the existing Preview, Save, drag and native file actions. Pages with document attachments start expanded, with page images and page text behind full-width disclosure controls. The visible Save This Module and Save All Modules actions keep one week and all-week collection together. Reading size and Reduce Motion continue using the existing native reader/disclosure components.

Offline refresh preserves page provenance when pages become unavailable. Pre-grouping caches remain readable; their unclassified attachments appear under “Other saved files” until a successful refresh supplies source-page information. Saved credentials, download concurrency and retry policy are unchanged.

Research:

- [NN/g: recognition and recall](https://www.nngroup.com/articles/recognition-and-recall/): visible Canvas titles let students recognise the teaching activity instead of remembering filenames.
- [Apple HIG: disclosure controls](https://developer.apple.com/design/human-interface-guidelines/disclosure-controls): retain clear page labels while revealing attachment and supporting detail on demand.
- [SwiftUI DisclosureGroup](https://developer.apple.com/documentation/swiftui/disclosuregroup), reviewed through Context7: use existing SwiftUI/native file actions and accessible labelled disclosure rows.
- [Apple: organise files in Finder](https://support.apple.com/en-ph/guide/mac-help/mchle9f0a1b2/27/mac/27): matching nested folders make the downloaded organisation consistent with the app.

Synthetic verification covers source groups, files linked by multiple pages, one file metadata resolution per ID, exact-byte folder copies, duplicate/sanitised folder names, course boundaries, safe source links, unchanged repeat exports, old-cache decoding and offline provenance. Live checks use the student's own Canvas pages without publishing their teaching content or credentials.

Live verification (27 October 2026): the installed app displayed the exact tutorial, solution and lecture page titles with 2, 2 and 6 document attachments respectively. A pointer click in the trailing whitespace of a source-page header collapsed it; reopening retained its file actions. Native Quick Look opened the tutorial PDF from its grouped row. Save This Module produced matching page folders with all 11 linked attachments verified against cached original hashes (including the page image). Save All Modules produced 15 module folders and 111 source-page folders; every one of 215 expected attachment placements matched the original cached hash. Actual academic files and verification data remain outside Git. The full automated suite passed. Pointer drag into Finder and a full VoiceOver/contrast audit were not repeated for this change; the unchanged native file-provider receiver tests passed.
