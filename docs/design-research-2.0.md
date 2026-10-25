# Native assignment and module workflows

This pass addresses finding upcoming work, collecting its requirements, reviewing results, and saving teaching materials for one module or an entire subject.

## Research translated into interactions

| Principle | App decision | Primary reference |
| --- | --- | --- |
| Organise around tasks and recognisable labels | Upcoming / Feedback / All scopes; stable Materials / Feedback / Submission tabs; visible Module Files entry | [NN/g: IA versus navigation](https://www.nngroup.com/articles/ia-vs-navigation/), [information scent](https://www.nngroup.com/articles/information-scent/) |
| Reduce interaction cost and repeated searching | Agenda items route into the selected assignment; requirements fetch inline; save one module or all modules | [NN/g: interaction cost](https://www.nngroup.com/articles/interaction-cost-definition/) |
| Use hierarchy and progressive disclosure | Original documents first; expandable page images, page text/source links and collection notes | [NN/g: visual design principles](https://www.nngroup.com/articles/principles-visual-design/), [progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/) |
| Use comfortable real targets | Full-width labelled disclosure buttons; framed native toolbar labels; file icon/name drag area and visible Save alternative | [Apple: buttons](https://developer.apple.com/design/human-interface-guidelines/buttons), [disclosure controls](https://developer.apple.com/design/human-interface-guidelines/disclosure-controls), [NN/g: drag and drop](https://www.nngroup.com/articles/drag-drop/) |
| Preserve readable hierarchy and platform conventions | System fonts/semantic colours, explicit Mac reading-size preference, wrapping/stacking file controls, native menus/windows/Quick Look | [Apple: typography](https://developer.apple.com/design/human-interface-guidelines/typography), [accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) |
| Show meaningful state and preserve usable content | Collection progress, cancellation, missing-file notes, retained offline copies, explicit save destination and Finder reveal | [NN/g: system status](https://www.nngroup.com/articles/visibility-system-status/) |
| Keep motion purposeful | Brief disclosure transitions that respect Reduce Motion | [Apple: motion](https://developer.apple.com/design/human-interface-guidelines/motion), [NN/g: animation usability](https://www.nngroup.com/articles/animation-usability/) |

Comparable patterns informed the interaction choices: [Itsycal](https://www.mowglii.com/itsycal/help) and [Fantastical](https://flexibits.com/fantastical/help/calendar-views) distinguish a quick menu-bar view from a larger window; [Zotero](https://www.zotero.org/support/attaching_files) supports reusable stored attachments and Finder reveal; [Apple Notes](https://support.apple.com/en-au/guide/notes/apd9953dabf9/mac) uses familiar document preview and file actions.

Current official SwiftUI documentation was consulted through Context7 for [DisclosureGroupStyle](https://developer.apple.com/documentation/swiftui/disclosuregroupstyle), [native tab pickers](https://developer.apple.com/documentation/swiftui/pickerstyle/tabs), file representations, Quick Look, text selection and Reduce Motion. Native appearance alone was not treated as evidence of usable targets or accessible behaviour.

## Canvas and concurrency

The implementation follows the documented [Modules](https://developerdocs.instructure.com/services/canvas/resources/modules), [Files](https://developerdocs.instructure.com/services/canvas/resources/files), [Pages](https://developerdocs.instructure.com/services/canvas/resources/pages) and [throttling](https://csn.instructure.com/doc/api/file.throttling.html) behaviours. Module items are paginated independently; explicit linked files are distinguished from a broad file-library crawl. Hidden-from-index files can be valid when linked and unlocked; the authenticated download remains subject to Canvas permission checks.

Bounded structured concurrency preserves source order while allowing overlapping work. A shared request gate handles cancellation and rate-limit cooldown before admitting queued work. Retries do not erase the credential or cached academic content.

## Verification and limits

Synthetic tests cover discovery, permission/lock states, cached-data retention, file naming/bytes, request caps, concurrent ordering, retry classification and throttle timing. Native checks cover window/menu lifecycle; observed UI checks include whole-row disclosure activation and reader/module reflow at 200% reading size.

A completed pointer drag into Finder, full VoiceOver traversal, measured contrast across appearance/Increase Contrast and trackpad usability testing remain open. File-provider receiver tests establish the receiving path, rather than a completed physical drag. No HIG or accessibility certification is claimed.

## Follow-up scope

Selected-course onboarding downloads and opt-in hourly/daily/weekly material checks are planned. They need persistent background progress, revision-aware updates, sleep/wake handling and clear last-success status. The current release provides manual one-module/all-module collection; it does not enable those schedules.
