import SwiftUI
import AppKit
import QuickLook

struct FeedbackReader: View {
    let item: FeedbackItem
    @ObservedObject var store: FeedbackStore
    let preview: ([FeedbackAttachment]) -> Void
    @State private var section = ReaderSection.materials
    @State private var initializedSection = false
    private enum ReaderSection: String, CaseIterable { case materials = "Materials", feedback = "Feedback", submission = "Submission" }
    @State private var showingWarning = false
    @State private var copyNotice = ""
    @State private var rubricFile: URL?
    @State private var saveError: String?
    @State private var actionTask: Task<Void, Never>?
    var body: some View {
        VStack(spacing:0) {
            header.padding(24)
            Divider()
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch section {
                case .materials: AssignmentMaterialsView(item:item,store:store)
                case .feedback:
                    feedbackSection
                    rule
                    rubricSection
                    if !item.prioritizesFeedback {
                        Text("Lecturer feedback will appear here when Canvas releases it.").feedbackFont(.callout).foregroundStyle(.secondary).padding(.top,16)
                    }
                case .submission:
                DisclosureGroup("Submission details") {
                    VStack(alignment: .leading, spacing: 10) {
                        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                            GridRow { Text("Status").foregroundStyle(.secondary); Text(item.workflowState.capitalized) }
                            GridRow { Text("Submitted").foregroundStyle(.secondary); Text(FeedbackFormat.time(item.submittedAt)) }
                            if let attempt = item.attempt { GridRow { Text("Attempt").foregroundStyle(.secondary); Text(String(attempt)) } }
                        }
                        if item.late { Text("Canvas marks this submission as late.") }
                        if item.missing { Text("Canvas marks this submission as missing.") }
                        ForEach(item.submissionFiles) { file in fileRow(file) }
                        ForEach(item.history) { history in
                            Text("Attempt \(history.attempt) · " + FeedbackFormat.time(history.submittedAt)).feedbackFont(.callout)
                        }
                    }.textSelection(.enabled).padding(.top, 12).frame(maxWidth: .infinity, alignment: .leading)
                }.feedbackFont(.body).disclosureGroupStyle(ComfortableDisclosureStyle())
                }
                HStack(spacing: 8) {
                    Text("Updated " + FeedbackFormat.time(item.checkedAt)).feedbackFont(.callout).foregroundStyle(.secondary)
                    if let error = store.errorMessage {
                        Button { showingWarning.toggle() } label: { Image(systemName: "exclamationmark.triangle.fill").frame(minWidth: 28, minHeight: 28).symbolRenderingMode(.multicolor) }
                            .help(error).accessibilityLabel("Updates unavailable; saved feedback remains available")
                            .popover(isPresented: $showingWarning) { Text(error).padding().frame(width: 300) }
                    }
                }.padding(.top, 20)
                if let saveError { Text(saveError).feedbackFont(.callout).padding(.top, 8) }
            }
            .feedbackFont(.body)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        }
        .overlay(alignment: .bottomTrailing) {
            if !copyNotice.isEmpty { Text(copyNotice).font(.callout).padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).padding() }
        }
        .task(id: copyNotice) {
            guard !copyNotice.isEmpty else { return }
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { copyNotice = "" }
        }
        .task(id: item.checkedAt) {
            guard FeedbackExport.hasRubric(item) else { rubricFile = nil; return }
            let name = item.rubricState == .assessed ? "Assessed rubric.txt" : "Marking rubric.txt"
            var rubricPlan = AssignmentAssistPlan(course: item.course, title: item.title, courseID: item.courseID, assignmentID: item.assignmentID)
            rubricPlan.texts = [AssistText(name: name, text: FeedbackExport.rubric(item))]
            rubricFile = try? await store.materialTexts(rubricPlan).first(where: { $0.id == name })?.url
        }
        .onAppear {
            if !initializedSection { section = item.prioritizesFeedback ? .feedback : .materials; initializedSection = true }
        }
        .onDisappear { actionTask?.cancel() }
    }
    private var header: some View {
        VStack(alignment:.leading,spacing:0) {
                Text(item.course).feedbackFont(.callout, weight: .semibold).foregroundStyle(.secondary).padding(.bottom, 6)
                Text(item.title).feedbackFont(.title, weight: .bold).lineLimit(3).help(item.originalTitle).textSelection(.enabled)
                    .accessibilityAddTraits(.isHeader).padding(.bottom, 8)
                Text(item.markLabel.map { $0 + " · Released Canvas mark" } ?? item.navigationSubtitle)
                    .feedbackFont(.title3)
                if !item.gradeMatchesCurrent && item.markLabel != nil {
                    Text("This mark is for a previous submission attempt.").feedbackFont(.callout).padding(.top, 6)
                }
                if let due = item.dueAt {
                    Text("Due " + FeedbackFormat.time(due)).feedbackFont(.body).padding(.top,8)
                }
                Picker("Assignment section",selection:$section) {
                    ForEach(ReaderSection.allCases,id:\.self) { value in
                        Text(value.rawValue).tag(value)
                    }
                }.pickerStyle(.tabs).controlSize(.large).labelsHidden().padding(.top,16)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    private var rule: some View { Divider().padding(.vertical, 18) }
    private func heading(_ text: String) -> some View {
        Text(text).feedbackFont(.headline).accessibilityAddTraits(.isHeader).padding(.bottom, 10)
    }
    private var rubricSection: some View {
        FeedbackRubricView(item: item, dragFile: rubricFile) { copyNotice = $0 }
    }
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Feedback")
            ForEach(item.attachments) { file in fileRow(file) }
            if !item.comments.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack { Text("Lecturer comments").feedbackFont(.headline); Spacer(); copyComments }
                    VStack(alignment: .leading, spacing: 8) { Text("Lecturer comments").feedbackFont(.headline); copyComments }
                }
                ForEach(item.comments) { comment in
                    Text(comment.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    if !store.designMode {
                        Text(comment.author + " · " + FeedbackFormat.time(comment.createdAt))
                            .feedbackFont(.callout).foregroundStyle(.secondary)
                    }
                }
            }
            if !item.attachments.isEmpty {
                Text("Drag a feedback document into your AI or Finder, or save a copy.")
                    .feedbackFont(.callout).foregroundStyle(.secondary)
            }
        }
    }
    private var copyComments: some View {
        Button {
            copyNotice = FeedbackClipboard.copy(FeedbackExport.feedback(item), confirmation: "Lecturer comments copied")
        } label: { Label("Copy Lecturer Comments",systemImage:"doc.on.doc").feedbackFont(.body).frame(minHeight:28).contentShape(Rectangle()) }.controlSize(.large).help("Copy the complete Canvas comments with assessment context. PDF contents are separate.")
    }
    private func fileRow(_ file: FeedbackAttachment) -> some View {
        let key = item.id + ":" + String(file.id)
        return VStack(alignment: .leading, spacing: 8) {
            NativeFileRow(name: friendlyName(file), detail: (file.isPDF ? "PDF" : "File") + " · " + ByteCountFormatter.string(fromByteCount: Int64(file.cachedSize ?? file.size), countStyle: .file) + (store.localURL(file) == nil ? " · From Canvas" : " · Ready to drag"), url: store.localURL(file), exportName: friendlyName(file), busy: store.busyFiles.contains(key),
                preview: { perform(.preview, file: file) }, save: { perform(.save, file: file) }, open: { perform(.open, file: file) })
            if let error = store.fileErrors[key] { Text(error).feedbackFont(.callout) }
            if let source = store.duplicateSource(file, itemID: item.id) {
                Text("This file is identical to the attachment on " + source + ".").feedbackFont(.callout).foregroundStyle(.secondary)
            }
        }
    }
    private enum FileAction { case open, preview, save }
    private func perform(_ action: FileAction, file: FeedbackAttachment) {
        if action == .preview { preview([file]); return }
        actionTask?.cancel()
        actionTask = Task {
            if action == .save { await save(file); return }
            guard let url = await store.obtain(file, itemID: item.id), !Task.isCancelled else { return }
            if !NSWorkspace.shared.open(url) {
                store.fileErrors[item.id + ":" + String(file.id)] = "No app could open this file. Use Save… to keep a copy and choose an app."
            }
        }
    }
    private func friendlyName(_ file: FeedbackAttachment) -> String { FeedbackExport.fileName(file,item:item) }
    private func save(_ file: FeedbackAttachment) async {
        guard let url = await store.obtain(file, itemID: item.id), !Task.isCancelled else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = friendlyName(file)
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let destination = panel.url else { return }
            do { try Data(contentsOf: url).write(to: destination, options: .atomic); saveError = nil }
            catch { saveError = "Could not save this copy: " + error.localizedDescription }
        }
    }
}
