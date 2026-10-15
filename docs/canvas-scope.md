# Canvas capability scope — not implemented

The app currently implements deadline reading only. These are possible future additions, subject to the student's permissions and the institution's configuration.

| Information | API/source | Important constraints |
|---|---|---|
| Posted assignment marks and grades | Assignment submission `score`, `grade`, `posted_at`; assignment `points_possible` | Hidden or unposted marks must remain hidden; a missing score is not zero. |
| Course totals | Student enrollment `grades` | Totals may be withheld, incomplete, or calculated differently from a final university result. |
| Instructor comments | Submission with `include[]=submission_comments` | Text, author/time, and attachments can be available. Avoid requesting `read_status` just to inspect feedback because that can mark it read. |
| Rubric feedback | Submission with `include[]=rubric_assessment` | Only present when a rubric assessment exists and is visible. |
| Submitted files and feedback attachments | Submission and comment attachments | Use permitted download URLs; preview pages may require browser authentication. |
| Course materials | Course files, module items, file metadata | A course can deny bulk file listing while exposing individual module-linked files. Locked files remain unavailable. |
| Assignment instructions and assessment structure | Assignments and assignment groups | Instructions are HTML; weights and point totals require interpretation in the course context. |
| Announcements, modules, and pages | Announcements, modules, pages APIs | Published/locked status and navigation settings affect availability. External course tools may not expose their content through Canvas. |

Sources: [Submissions](https://developerdocs.instructure.com/services/canvas/resources/submissions), [Enrollments](https://developerdocs.instructure.com/services/canvas/resources/enrollments), [Files](https://developerdocs.instructure.com/services/canvas/resources/files).

A future design should keep marks and feedback separate from the calm deadline overview. No grade reader, comment viewer, download manager, or submission writer has been added.
