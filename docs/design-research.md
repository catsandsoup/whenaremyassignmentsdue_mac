# Design research

## Intended task

Answer “what is due next, for which subject, and at what exact time?” from a small menu bar panel. Keep the user’s actual Canvas deadlines available without browser authentication.

## Mac app comparison

The published product screenshots were visually inspected, rather than inferring their design from feature lists.

| Reference | Observed pattern | Application here |
|---|---|---|
| [Dato](https://sindresorhus.com/dato) | Narrow agenda; event title above time metadata; small colour rules instead of colouring all event text. | One reading column; restrained typography; no blanket urgency colour. |
| [Itsycal](https://www.mowglii.com/itsycal/) | Date sections, clear group boundaries, ordinary event titles, supporting times beneath titles. The inspected product image includes a September 2026 calendar. | Group by due date; title then course and due time. |
| [MeetingBar](https://github.com/leits/MeetingBar) | Compact day grouping, current/next event focus, actions separate from event entries. Its repository screenshot is an older visual reference. | Earliest deadline first; separate settings and refresh controls from content. |

Dato’s inspected screenshot depicts February 2023. These images establish useful information patterns; they do not prove how every version renders on macOS 27.

## Problems in the earlier builds

The first table gave every assignment a saturated orange title and left course labels faint. The following build added heavy text, monospaced course badges, and repetitive countdowns. A later native Table experiment introduced a wide spreadsheet-like layout and contrasting row backgrounds inside the menu bar panel. These changes did not reduce the work needed to decide where to look.

The resulting agenda removes the wide table, custom palette, font-design overrides, appearance overrides, badge decoration, and repeated countdowns. Date headings are SwiftUI `headline`; assignment titles use `body`; course/time metadata uses `subheadline`. Native buttons and menus retain platform behaviour. The Mac supplies the appearance.

## Apple guidance consulted through Context7

- [Typography](https://developer.apple.com/design/human-interface-guidelines/typography): system fonts and text styles provide a familiar hierarchy. SF Pro is the macOS system font; the documented default macOS text size is 13 points. These are platform defaults, not proof that a layout is comfortable for a particular person.
- [Colour](https://developer.apple.com/design/human-interface-guidelines/color): use semantic system colours and support the system appearance. Colour should have a consistent purpose.
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials): Liquid Glass belongs primarily to controls and navigation; avoid stacking custom glass layers throughout the content.
- [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts): reserve interruptions for essential, actionable information; cached content with an inline status is appropriate for a connection failure.

## Time pressure and information organisation

[Moacdieh and Sarter’s clutter study](https://scholarworks.aub.edu.lb/items/55099c15-c986-4d34-b3ac-c2e5b46ee9da) found that dense, poorly organised displays increased search times and errors. Its time-limit manipulation shortened response time without degrading performance. This argues against treating all stress effects as identical.

[Rieger and Manzey’s visual-search experiments](https://pubmed.ncbi.nlm.nih.gov/35770911/) found lower detection sensitivity and less searching under high time pressure in a simulated manual medical search task. This is not a study of student deadline apps. The design inference is to make important facts immediately findable without adding artificial pressure or requiring users to check multiple competing signals.

[Progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/) supports keeping the core information visible while moving infrequent actions and supporting details behind clearly labelled controls.

For this app, that means predictable chronological ordering, exact dates and times, date-based grouping, one reading column, and submission links on demand. There are no flashing countdowns, alarm-like row colours, or unsolicited alerts. Future urgency behaviour should distinguish actual immediacy from an ordinary upcoming task and should be validated with the user.

## Verification limits

Native screenshots establish visible layout and rendering only. They do not establish a measured reduction in the user’s stress, universal usability, or full accessibility compliance. The user’s feedback remains the deciding evidence for whether this presentation is easier to read.
