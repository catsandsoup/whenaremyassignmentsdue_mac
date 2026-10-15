import SwiftUI
import AppKit
import QuickLook

struct FeedbackReader: View {
    let item: FeedbackItem
    @ObservedObject var store: FeedbackStore
    let preview: ([FeedbackAttachment]) -> Void
    @State private var showingWarning = false
    @State private var copyNotice = ""
    @State private var saveError: String?
    @State private var actionTask: Task<Void, Never>?
    @FocusState private var focusedAttachment: Int?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(item.course).feedbackFont(.subheadline).foregroundStyle(.secondary).padding(.bottom, 10)
                Text(item.title).feedbackFont(.largeTitle, weight: .bold).textSelection(.enabled).accessibilityAddTraits(.isHeader).padding(.bottom, 7)
                Text(item.markLabel.map { $0 + " · Released Canvas mark" } ?? item.subtitle)
                    .feedbackFont(.title2).foregroundStyle(.secondary)
                if !item.gradeMatchesCurrent && item.markLabel != nil {
                    Text("This mark is for a previous submission attempt.").feedbackFont(.subheadline).padding(.top, 6)
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
                                .feedbackFont(.caption).foregroundStyle(.secondary).padding(.top, 5).padding(.bottom, 12)
                        }
                    }
                }
                rule
                FeedbackRubricView(item: item) { copyNotice = $0 }
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
                            Text("Attempt \(history.attempt) · " + FeedbackFormat.time(history.submittedAt)).feedbackFont(.subheadline)
                        }
                    }.padding(.top, 12)
                }.feedbackFont(.body).accessibilityLabel("Submission details")
                rule
                HStack(spacing: 8) {
                    Text("Updated " + FeedbackFormat.time(item.checkedAt)).feedbackFont(.caption).foregroundStyle(.secondary)
                    if let error = store.errorMessage {
                        Button { showingWarning.toggle() } label: { Image(systemName: "exclamationmark.triangle.fill").symbolRenderingMode(.multicolor) }
                            .buttonStyle(.plain).help(error).accessibilityLabel("Updates unavailable; saved feedback remains available")
                            .popover(isPresented: $showingWarning) { Text(error).padding().frame(width: 300) }
                    }
                }
                if let saveError { Text(saveError).feedbackFont(.caption).foregroundStyle(.secondary).padding(.top, 8) }
                Spacer(minLength: 28)
            }
            .textSelection(.enabled)
            .feedbackFont(.body)
            .padding(.horizontal, 30).padding(.top, 28).padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .bottomTrailing) {
            if !copyNotice.isEmpty { Text(copyNotice).font(.callout).padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).padding() }
        }
        .task(id: copyNotice) {
            guard !copyNotice.isEmpty else { return }
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { copyNotice = "" }
        }
        .onDisappear { actionTask?.cancel() }
    }
    private var rule: some View { Divider().padding(.vertical, 26) }
    private func heading(_ text: String, top: CGFloat = 0) -> some View {
        Text(text).feedbackFont(.headline).accessibilityAddTraits(.isHeader).padding(.top, top).padding(.bottom, 10)
    }
    private func fileRow(_ file: FeedbackAttachment) -> some View {
        let key = item.id + ":" + String(file.id)
        let isBusy = store.busyFiles.contains(key)
        return VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    attachmentIcon(file)
                    fileMetadata(file).frame(minWidth: 180)
                    Spacer(minLength: 0)
                    fileButtons(file, isBusy: isBusy)
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) { attachmentIcon(file); fileMetadata(file) }
                    fileButtons(file, isBusy: isBusy)
                }
            }
            if let error = store.fileErrors[key] { Text(error).feedbackFont(.caption).foregroundStyle(.secondary) }
            if let source = store.duplicateSource(file, itemID: item.id) {
                Text("This file is identical to the attachment on " + source + ".").feedbackFont(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 20).background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator.opacity(0.5)))
        .focusable()
        .focused($focusedAttachment, equals: file.id)
        .onKeyPress(.space, phases: .down) { _ in
            guard focusedAttachment == file.id else { return .ignored }
            guard !isBusy else { return .handled }
            perform(.preview, file: file); return .handled
        }
        .contextMenu {
            Button(file.isPDF ? "Open PDF" : "Open File") { perform(.open, file: file) }.disabled(isBusy)
            Button("Quick Look", systemImage: "eye") { perform(.preview, file: file) }.disabled(isBusy)
            Button("Save…", systemImage: "square.and.arrow.down") { perform(.save, file: file) }.disabled(isBusy)
            if let url = store.localURL(file) {
                Divider()
                Button("Show in Finder", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                if file.isPDF { ShareLink(item: FeedbackPDF(url: url, name: file.name), preview: SharePreview(file.name)) }
            }
        }
    }
    private func fileMetadata(_ file: FeedbackAttachment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(friendlyName(file)).feedbackFont(.body, weight: .semibold).lineLimit(3).textSelection(.enabled).help(file.name)
            Text((file.isPDF ? "PDF" : "File") + " · " + ByteCountFormatter.string(fromByteCount: Int64(file.cachedSize ?? file.size), countStyle: .file)).feedbackFont(.subheadline).foregroundStyle(.secondary)
            if store.designMode || store.localURL(file) != nil {
                Label("Saved on this Mac", systemImage: "checkmark.circle.fill").feedbackFont(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private func fileButtons(_ file: FeedbackAttachment, isBusy: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Button { perform(.open, file: file) } label: {
                    Text(file.isPDF ? "Open PDF" : "Open file").opacity(isBusy ? 0 : 1)
                        .overlay { if isBusy { ProgressView().controlSize(.small) } }
                }
                    .accessibilityLabel(isBusy ? "Downloading attachment" : (file.isPDF ? "Open PDF" : "Open file"))
                    .buttonStyle(.borderedProminent).disabled(isBusy)
                Button("Save…") { perform(.save, file: file) }.disabled(isBusy)
            }
            if !store.designMode {
                Button("Preview") { perform(.preview, file: file) }.buttonStyle(.link).disabled(isBusy)
            }
        }
    }
    @ViewBuilder private func attachmentIcon(_ file: FeedbackAttachment) -> some View {
        let icon = Image(systemName: "doc.richtext").feedbackFont(.largeTitle).foregroundStyle(.secondary).frame(width: 30)
        if file.isPDF, let url = store.localURL(file) {
            icon.draggable(FeedbackPDF(url: url, name: file.name))
                .help("Drag this PDF into Finder or another app")
                .accessibilityLabel("Drag " + file.name)
        } else { icon }
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
