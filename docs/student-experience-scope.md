# Student experience: journeys, files and the quality bar

15 October 2026. This scope joins the [Mac interaction audit](interaction-audit-mac-journeys.md), [file audit](interaction-audit-files.md), [Siri/MCP/awards research](interaction-audit-integrations.md), and [first-/third-party control comparison](native-interaction-comparison.md). Those documents distinguish observed source/evidence, completed runtime checks and proposed acceptance tests.

## The product promise

A student should be able to find the next real deadline, understand what an assignment requires, check their submission, read the right feedback and reuse the right rubric/document without reconstructing context from Canvas. The menu-bar agenda stays focused. Reading, files and automation have their own clear contracts.

A delight is a completed job with unnecessary steps removed: copying an entire rubric despite its collapsed presentation; opening a cached feedback PDF after the API key expires; retaining each assignment's provenance when two attachments have identical bytes. Adding controls is not itself improvement.

## Interaction contract

| User activity | Entry point / physical or keyboard target | Required journey and state | Native implementation / test gate |
| --- | --- | --- | --- |
| Open | Menu-bar item → agenda; gear/right-click → Marks & Feedback; ⌘⇧M | Reuse one window, restore valid selection, show cache immediately. | SwiftUI Window/openWindow; test launch, reopen and offline. |
| Type/search | Search field or ⌘F | Filter locally by course/title; clear hidden selection; do not show old content. Clear query restores list. | TextField/focus; test typing, paste, deletion, no matches and keyboard return to list. |
| Select/read | Assignment row, Up/Down | One selected identity; entire reader changes together; accent while active, inactive system selection otherwise. | Native List; test contrasting PDF/no-PDF/rubric records and delayed requests. |
| Expand/collapse | Native triangle beside a course or criterion title | Reveal related content in place. No fake menu or navigation. Hiding the selected course clears reader. | Section(isExpanded:), DisclosureGroup; test mouse, keyboard and AX state. |
| Right-click | Assignment row or file icon/card background; selectable filename for text services | Act on the clicked object, including an unselected row. The PDF icon exposes file actions; selectable text preserves system text services. | Selection-aware contextMenu; clipboard output must identify the target. Installed runtime verified both icon/file and filename/text menus. |
| Copy | Selected text + ⌘C; sidebar selection + ⌘C; named Copy Rubric/Feedback | Range-copy stays native; complete-copy includes context and hidden disclosure contents. No unposted mark or transport secrets. | textSelection, copyable, native pasteboard; quiet visual and accessibility confirmation; explicit failure. |
| Scroll | Trackpad/wheel over sidebar versus reader | Independent scroll regions, long content flows vertically; a refresh must not arbitrarily reset reading position. | Native ScrollView/List; test long rubric, large text and selection reset. |
| Hover | Filename, drag icon, controls | Useful tooltip/original name; no essential action or information exists only on hover. | help; test mouse, large pointer and keyboard/VoiceOver equivalents. |
| Read with glasses/larger text | Text Size picker; View → Larger/Smaller/Actual Size | Preserve hierarchy, wrap and scroll; keep actions reachable in light/dark and at supported reading sizes. | Native text-style descriptors, commands, ViewThatFits; test up to 200%, not a blanket Larger Text certification. |
| Download | Explicit file action or successful automatic feedback refresh | Per-file progress, duplicate suppression, validation then atomic local commit. Failure keeps cached records/files. | URLSession/file actor; test missing, denied, expired, corrupt and changed resources. |
| Preview | Preview / Quick Look context action; Space on focused file card | Read the exact local document without browser login; dismiss back to the same assignment. A busy file must not restart/cancel its action on repeated Space. | quickLookPreview, native focus; test preview, dismissal and descendants' keyboard actions. |
| Open document | Open PDF or context menu | Launch the chosen system handler; keep authoritative cached bytes protected; native editors may require a writable duplicate. Handler failure offers Save recovery. | NSWorkspace, read-only managed source; verify editor-specific behaviour separately. |
| Save | Save… → native sheet | Original filename, user-chosen destination; cancel changes nothing; exported copy can be edited independently. | NSSavePanel/atomic copy; test successful save, cancellation and write failure. |
| Drag/share | PDF document icon; context Share | Send a named editable document copy, not a signed URL or opaque cache path; no automatic AI destination. | Transferable FileRepresentation, ShareLink; byte/name/permission round-trip tests plus real receiving-app tests. |
| Reveal file | File context menu → Show in Finder | Current action reveals the cached original, whose hash name is an acknowledged limitation. Future exported-document reveal should target a tracked user copy. | NSWorkspace; do not imply Finder is an assignment archive or expose arbitrary paths. |
| Close | Escape for preview/menu; ⌘W/window close for reader; Quit for app | Dismiss the appropriate surface; closing the reader leaves the menu-bar app/cache alive. Reopen restores context. | Native window/sheet lifecycles; test close during download and focus restoration. |
| External monitor/clamshell/Mac mini | Mouse/keyboard, menu bar on another display, reconnect display | Reachable windows, readable scaling and working keyboard/typed paths; no dependence on laptop touch input or a microphone. | Native windowing; physical display/Space/scale matrix remains required. |
| Ask Siri | System selected-text action versus future app intent | System text assistance is distinct from querying the app. Future assignment questions must resolve course/identity and answer using cached, dated data. | App Intents/Shortcuts feasibility next; typed/voice and device authentication tested separately. |
| Use an AI agent | Copy/paste or drag today; deliberate scoped connection in future | Student chooses what leaves the app. MCP needs a selected-record allowlist, provenance, offline semantics and revoke. | Native handoff now; read-only MCP separately scoped, not implemented. |

## What a file means

To a student, a PDF is “the lecturer's comments on my second presentation” or “the marking criteria I must satisfy.” To software it is bytes, content type, identity, a location and sometimes extractable text. An AI needs the human context as well as usable bytes/text; opening a PDF does not prove that scanned text, tables, annotations, handwriting or every page was interpreted correctly.

Keep five things distinct: the academic object, Canvas's remote metadata, the managed local original, the user's exported/annotated copy, and any derived text/OCR. A content hash can identify duplicate bytes; it cannot tell us that the same feedback is a new result for another assignment.

Known evidence covers 27 own submission records; 11 current file references (5 PDF, 5 DOCX, 1 MP4); 17 file references across 33 history records (including current attempts); and three feedback PDFs representing two distinct byte contents. There are eight structured rubrics with 39 criteria and 147 rating levels. These are observed references, not a complete accessible Canvas file inventory. Linked HTML resources, annotated documents, media and external-tool files need independent retrieval/permission checks.

| Academic purpose | Importance / expected use | Product priority |
| --- | --- | --- |
| Brief, instructions, structured rubric | High; repeatedly while preparing work | Find and reuse complete authoritative context first. Definitions are not assessed results. |
| Own/group submission and receipt/attempt | High near submission; occasional verification later | Exact attempt, filename and time; group membership alone is not proof of submission. |
| Lecturer comments and feedback document | High when released; revisited for the next assignment | Open the exact document, preserve teacher/assignment/source and full text. |
| Readings, slides, worksheets, datasets/templates | Varies; frequent during the teaching week | Future purpose-led course materials view; do not bulk-dump files into deadlines. |
| Annotated PDFs, recordings and external tools | Potentially high; representation/access varies | Prove student access and actual annotation/media payload before promising support. |
| Historical revisions and archived semesters | Occasional but important for recovery/reference | Retain provenance and distinguish historical data from current enrolment. |

Frequency is a working hypothesis, not measured analytics; validate with students.

## Release priorities and award-quality gates

**Current refinement:** complete copy, native disclosure/menu/picker semantics, selectable text, local PDF handoff, explicit failure/confirmation, protected originals and editable exports, bounded larger reading size, light/dark verification. Keep API, credential behaviour and deadline agenda stable.

**Next validation:** full keyboard/VoiceOver, contrast/transparency/non-default accent, scaled external monitors and display disconnect/reconnect, real receiving-app drag/drop, read-only Preview duplicate behaviour and user-owned export lifecycle. Do not advertise these as fully verified merely because the APIs compile.

**Then evaluate:** instructions/course materials, typed native App Intents and Shortcuts; PDF text/annotation/OCR with source/page labels; a separately permissioned read-only MCP interface. Every addition must remove a demonstrated student step and preserve a calm agenda.

Apple's App Store Awards and Design Awards are separate editorial programs, not a utility feature checklist. Translate the published themes into user studies and engineering gates: students find the correct deadline/rubric without explanation; correctly predict controls; navigate by keyboard and VoiceOver; complete copy/file handoff in one deliberate action; and trust offline/recovery behaviour. The detailed integration audit supplies proposed measurable thresholds and official award references. SwiftUI usage alone cannot earn an award or prove HIG/accessibility compliance.
