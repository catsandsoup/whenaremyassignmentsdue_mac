# Inline assignment materials — approved implementation

The user approved the proposed layout before this revision: material files appear directly on the selected assignment page, fetch automatically from Canvas, support dragging, and save together to Downloads. There is no preparation/upload sheet or manual brief collection.

## Components

- AssignmentAssist: read-only assignment/syllabus/linked-page discovery and versioned local preparation metadata. The course home is used to discover a labelled unit-outline link, without exporting unrelated navigation or staff pages. Resolve only file IDs referenced by the selected content; do not crawl unrelated course libraries.
- AssignmentMaterialFiles: immutable, named text/document copies, typed CoreTransferable file representations, and atomic named-folder exports. Repeated saves preserve prior folders.
- AssignmentMaterialsView: inline automatic loading, cached availability, individual native Quick Look/Save/Share, ready file drags, explicit unavailable statuses, and Save all to Downloads.
- FeedbackReader / FeedbackRubricView: visible Copy Feedback and a separately draggable complete rubric, including available assessed criterion comments for previous assessments. Default requirement files exclude marks/submissions/lecturer comments.

## Requirements

Preserve the saved Canvas API key. All app features continue using the existing cached, silent Keychain reader; tests do not read or replace the live key. Keep academic caches/documents outside the repository. Never upload materials automatically. Preserve the agenda and deadline cache.

Use native SwiftUI and CoreTransferable APIs. Research comparable interactions first using current official documentation via Context7 and Apple HIG. Sources: Zotero attachments, Apple Notes attachments, Apple drag-and-drop HIG and SwiftUI textSelection/draggable/FileRepresentation documentation, linked in README.

## Verification

Synthetic tests cover full criterion/rating descriptions, assessed rubric comments and feedback export, typed NSItemProvider file receivers, exact bytes/Unicode filenames, long-title collisions, save-folder preservation, missing-material notes, cached documents, API scope and offline recovery. Native window checks cover Dock promotion, minimise/reopen and last-window close.

Live UI checks exercised automatic material availability, Quick Look, Save all to Downloads, previous-assessment Copy Feedback and successful refresh with the unchanged saved key. Automated pointer-drag results are inconclusive: the same automation also failed a Finder-to-Finder calibration. Native receiver tests pass; do not describe the pointer gesture as manually verified. No document was sent to an AI service.
