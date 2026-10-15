import SwiftUI
import AppKit
import QuickLook

struct FeedbackReader: View {
    let item: FeedbackItem
    @ObservedObject var store: FeedbackStore
    @State private var previewURL: URL?
    @State private var showingWarning = false
    @State private var saveError: String?
    @State private var actionTask: Task<Void, Never>?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(item.course).font(.subheadline).foregroundStyle(.secondary).padding(.bottom, 10)
                Text(item.title).font(.largeTitle.weight(.bold)).textSelection(.enabled).padding(.bottom, 7)
                Text(item.markLabel.map { $0 + " · Released Canvas mark" } ?? item.subtitle)
                    .font(.title2).foregroundStyle(.secondary)
                if !item.gradeMatchesCurrent && item.markLabel != nil {
                    Text("This mark is for a previous submission attempt.").font(.subheadline).padding(.top, 6)
                }
                rule
                heading("Feedback")
                if item.attachments.isEmpty && item.comments.isEmpty {
                    Text("No feedback is available from Canvas yet.").foregroundStyle(.secondary)
                } else if !item.attachments.isEmpty {
                    Text("Open the PDF for your result and written feedback.").padding(.bottom, 16)
                    ForEach(item.attachments) { file in
                        fileRow(file)
                    }
                }
                if !item.comments.isEmpty {
                    heading("Lecturer comment", top: 24)
                    ForEach(item.comments) { comment in
                        Text(comment.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        if !store.designMode {
                            Text(comment.author + " · " + FeedbackFormat.time(comment.createdAt))
                                .font(.caption).foregroundStyle(.secondary).padding(.top, 5).padding(.bottom, 12)
                        }
                    }
                }
                rule
                FeedbackRubricView(item: item)
                rule
                DisclosureGroup("Submission details") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Status", value: item.workflowState.capitalized)
                        LabeledContent("Submitted", value: FeedbackFormat.time(item.submittedAt))
                        if let attempt = item.attempt { LabeledContent("Attempt", value: String(attempt)) }
                        if item.late { Text("Canvas marks this submission as late.") }
                        if item.missing { Text("Canvas marks this submission as missing.") }
                        ForEach(item.submissionFiles) { file in Text(file.name).textSelection(.enabled) }
                        ForEach(item.history) { history in
                            Text("Attempt \(history.attempt) · " + FeedbackFormat.time(history.submittedAt)).font(.subheadline)
                        }
                    }.padding(.top, 12)
                }.font(.body)
                rule
                HStack(spacing: 8) {
                    Text("Updated " + FeedbackFormat.time(item.checkedAt)).font(.caption).foregroundStyle(.secondary)
                    if let error = store.errorMessage {
                        Button { showingWarning.toggle() } label: { Image(systemName: "exclamationmark.triangle.fill").symbolRenderingMode(.multicolor) }
                            .buttonStyle(.plain).help(error).accessibilityLabel("Updates unavailable; saved feedback remains available")
                            .popover(isPresented: $showingWarning) { Text(error).padding().frame(width: 300) }
                    }
                }
                if let saveError { Text(saveError).font(.caption).foregroundStyle(.secondary).padding(.top, 8) }
                Spacer(minLength: 28)
            }
            .padding(.horizontal, 30).padding(.top, 28).padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .quickLookPreview($previewURL)
        .onDisappear { previewURL = nil; actionTask?.cancel() }
    }
    private var rule: some View { Divider().padding(.vertical, 26) }
    private func heading(_ text: String, top: CGFloat = 0) -> some View {
        Text(text).font(.headline).padding(.top, top).padding(.bottom, 10)
    }
    private func fileRow(_ file: FeedbackAttachment) -> some View {
        let key = item.id + ":" + String(file.id)
        let isBusy = store.busyFiles.contains(key)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "doc.richtext").font(.largeTitle).foregroundStyle(.secondary).frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(friendlyName(file)).font(.body.weight(.semibold)).lineLimit(3).textSelection(.enabled).help(file.name)
                    Text((file.isPDF ? "PDF" : file.contentType) + " · " + ByteCountFormatter.string(fromByteCount: Int64(file.cachedSize ?? file.size), countStyle: .file)).font(.subheadline).foregroundStyle(.secondary)
                    if store.designMode || store.localURL(file) != nil {
                        Label("Saved on this Mac", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 8) {
                    HStack {
                        Button(isBusy ? "Downloading…" : (file.isPDF ? "Open PDF" : "Open file")) {
                            actionTask?.cancel()
                            actionTask = Task {
                                if let url = await store.obtain(file, itemID: item.id), !Task.isCancelled { NSWorkspace.shared.open(url) }
                            }
                        }.buttonStyle(.borderedProminent).disabled(isBusy)
                        Button("Save…") { actionTask?.cancel(); actionTask = Task { await save(file) } }.disabled(isBusy)
                    }
                    if !store.designMode {
                        Button("Preview") { actionTask?.cancel(); actionTask = Task {
                            let url = await store.obtain(file, itemID: item.id)
                            if !Task.isCancelled { previewURL = url }
                        } }
                            .buttonStyle(.link).disabled(isBusy)
                            .onKeyPress(.space) { actionTask?.cancel(); actionTask = Task {
                            let url = await store.obtain(file, itemID: item.id)
                            if !Task.isCancelled { previewURL = url }
                        }; return .handled }
                    }
                }
            }
            if let error = store.fileErrors[key] { Text(error).font(.caption).foregroundStyle(.secondary) }
            if let source = store.duplicateSource(file, itemID: item.id) {
                Text("This file is identical to the attachment on " + source + ".").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 20).background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator.opacity(0.5)))
    }
    private func friendlyName(_ file: FeedbackAttachment) -> String {
        if file.isPDF, item.title.hasPrefix("Progress Presentation") {
            if let range = file.name.range(of: "[0-9]+(?=of[0-9]+)", options: .regularExpression) {
                return "Presentation " + file.name[range] + " — Feedback.pdf"
            }
            return item.title.replacingOccurrences(of: "Progress ", with: "") + " — Feedback.pdf"
        }
        return file.name
    }
    private func save(_ file: FeedbackAttachment) async {
        guard let url = await store.obtain(file, itemID: item.id), !Task.isCancelled else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = file.name
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let destination = panel.url else { return }
            do { try Data(contentsOf: url).write(to: destination, options: .atomic); saveError = nil }
            catch { saveError = "Could not save this copy: " + error.localizedDescription }
        }
    }
}

struct FeedbackRubricView: View {
    let item: FeedbackItem
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rubric").font(.headline)
            switch item.rubricState {
            case .document:
                Text("Included in the feedback PDF")
                Text("Criteria and assessor ratings are in the PDF above.").font(.subheadline).foregroundStyle(.secondary)
            case .unavailable:
                Text(item.attachments.contains(where: \.isPDF) ? "A rubric may be included in the feedback PDF above." : "A rubric is not available from Canvas for this assignment.").foregroundStyle(.secondary)
            case .criteria, .assessed:
                Text(item.rubricState == .assessed ? "Assessed rubric" : "Marking criteria").font(.subheadline).foregroundStyle(.secondary)
                if let type = item.assessmentType, type != "grading" { Text("Assessment type: " + type).font(.subheadline) }
                if let attempt = item.assessmentAttempt {
                    Text("Rubric for submission attempt \(attempt)").font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(item.rubric) { criterion in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(criterion.description).font(.body.weight(.semibold))
                            Spacer(minLength: 12)
                            if !item.hideRubricPoints, let maximum = criterion.points {
                                Text((item.assessments[criterion.id]?.points.map { FeedbackFormat.number($0) + "/" } ?? "Up to ") + FeedbackFormat.number(maximum)).font(.subheadline)
                            }
                        }
                        if !criterion.longDescription.isEmpty { Text(criterion.longDescription).textSelection(.enabled) }
                        if let comment = item.assessments[criterion.id]?.comments, !comment.isEmpty { Text(comment).textSelection(.enabled) }
                        DisclosureGroup("Rating descriptions") {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(criterion.ratings) { rating in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(rating.description).font(.subheadline.weight(.semibold))
                                            Spacer()
                                            if !item.hideRubricPoints, let points = rating.points { Text(FeedbackFormat.number(points)).font(.subheadline) }
                                        }
                                        Text(rating.longDescription).font(.subheadline).textSelection(.enabled)
                                    }
                                }
                            }.padding(.top, 10)
                        }.font(.subheadline)
                    }.padding(.vertical, 10)
                    Divider()
                }
                ForEach(item.assessments.keys.filter { id in !item.rubric.contains { $0.id == id } }.sorted(), id: \.self) { id in
                    VStack(alignment: .leading) {
                        Text("Additional criterion feedback").font(.subheadline.weight(.semibold))
                        if let comment = item.assessments[id]?.comments { Text(comment).textSelection(.enabled) }
                    }
                }
            }
        }
    }
}
