import SwiftUI
import AppKit
import QuickLook

struct FeedbackRubricView: View {
    let item: FeedbackItem
    var dragFile: URL? = nil
    var copied: (String) -> Void = { _ in }
    @State private var preview: URL?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack { rubricTitle; Spacer(); rubricActions }
                VStack(alignment: .leading, spacing: 10) { rubricTitle; rubricActions }
            }
            if let dragFile {
                NativeFileRow(name: item.rubricState == .assessed ? "Assessed rubric.txt" : "Marking rubric.txt", detail: "Complete criteria and ratings · Ready to drag", url: dragFile,
                    preview: { preview = dragFile }, save: { save(dragFile) }, open: { NSWorkspace.shared.open(dragFile) })
            }
            switch item.rubricState {
            case .document:
                Text("Included in the feedback PDF")
                Text("Criteria and assessor ratings are in the PDF above.").feedbackFont(.subheadline).foregroundStyle(.secondary)
            case .unavailable:
                Text(item.attachments.contains(where: \.isPDF) ? "A rubric may be included in the feedback PDF above." : "A rubric is not available from Canvas for this assignment.").foregroundStyle(.secondary)
            case .criteria, .assessed:
                Text(item.rubricState == .assessed ? "Assessed rubric" : "Marking criteria").feedbackFont(.subheadline).foregroundStyle(.secondary)
                if let type = item.assessmentType, type != "grading" { Text("Assessment type: " + type).feedbackFont(.subheadline) }
                if let attempt = item.assessmentAttempt {
                    Text("Rubric for submission attempt \(attempt)").feedbackFont(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(item.rubric) { criterion in
                    VStack(alignment: .leading, spacing: 10) {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 14) {
                                if !criterion.longDescription.isEmpty { Text(criterion.longDescription) }
                                ForEach(criterion.ratings) { rating in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(alignment: .firstTextBaseline) {
                                            Text(rating.description).feedbackFont(.subheadline, weight: .semibold)
                                            Spacer(minLength: 12)
                                            if !item.hideRubricPoints, let points = rating.points { Text(FeedbackFormat.number(points)).feedbackFont(.subheadline) }
                                        }
                                        Text(rating.longDescription).feedbackFont(.subheadline)
                                    }
                                }
                            }.padding(.top, 12)
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                Text(criterion.description).feedbackFont(.body, weight: .semibold)
                                Spacer(minLength: 12)
                                if let score = score(criterion) { Text(score).feedbackFont(.subheadline).fixedSize() }
                            }
                        }
                        if let comment = item.assessments[criterion.id]?.comments, !comment.isEmpty {
                            Text(comment).textSelection(.enabled)
                        }
                    }.padding(.vertical, 6)
                    Divider()
                }
                ForEach(item.assessments.keys.filter { id in !item.rubric.contains { $0.id == id } }.sorted(), id: \.self) { id in
                    VStack(alignment: .leading) {
                        Text("Additional criterion feedback").feedbackFont(.subheadline, weight: .semibold)
                        if let comment = item.assessments[id]?.comments { Text(comment).textSelection(.enabled) }
                    }
                }
            }
        }.disclosureGroupStyle(ComfortableDisclosureStyle())
        .quickLookPreview($preview)
    }
    private var rubricTitle: some View { Text("Rubric").feedbackFont(.headline).accessibilityAddTraits(.isHeader) }
    private var rubricActions: some View {
        HStack(spacing: 12) {
                if FeedbackExport.hasRubric(item) {
                    Button("Copy Rubric", systemImage: "doc.on.doc") {
                        copied(FeedbackClipboard.copy(FeedbackExport.rubric(item), confirmation: "Rubric copied"))
                    }.controlSize(.large).help("Copy every criterion and rating description, including collapsed sections")
                }
        }
    }
    private func save(_ url: URL) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = url.lastPathComponent
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let destination = panel.url else { return }
            do { try Data(contentsOf: url).write(to: destination, options: .atomic); copied("Rubric saved") }
            catch { copied("Could not save this rubric: " + error.localizedDescription) }
        }
    }
    private func score(_ criterion: FeedbackCriterion) -> String? {
        guard !item.hideRubricPoints else { return nil }
        if let awarded = item.assessments[criterion.id]?.points {
            return FeedbackFormat.number(awarded) + (criterion.points.map { "/" + FeedbackFormat.number($0) } ?? "")
        }
        return criterion.points.map { "Up to " + FeedbackFormat.number($0) }
    }

}
