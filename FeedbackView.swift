import SwiftUI
import QuickLook
import Accessibility

struct FeedbackWindowView: View {
    @ObservedObject var store: FeedbackStore
    @AppStorage("feedbackReadingSize") private var readingStep = 0
    @State private var copyNotice = ""
    @StateObject private var preview = FeedbackPreview()
    @AppStorage("feedbackSelection") private var savedSelection = ""
    @State private var state = FeedbackSelection()
    @FocusState private var searchFocused: Bool
    @FocusState private var listFocused: Bool
    private var selected: FeedbackItem? { state.item(in: store.items) }
    private var filtered: [FeedbackItem] {
        var search = state; search.collapsedCourses = []
        return search.visible(store.items)
    }
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search assignments…", text: $state.search)
                        .textFieldStyle(.plain).focused($searchFocused)
                        .accessibilityLabel("Search assignments")
                        .onSubmit { selectSearchResult() }
                        .onKeyPress(.downArrow) { selectSearchResult(); return .handled }
                        .onExitCommand { state.search = ""; searchFocused = false; listFocused = true }
                    if !state.search.isEmpty {
                        Button { state.search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).accessibilityLabel("Clear search")
                    }
                }
                .padding(9).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 10)
                assignmentList
            }
            .feedbackFont(.body)
            .navigationSplitViewColumnWidth(min: 270, ideal: 340, max: 440)
        } detail: {
            Group {
                if let item = selected {
                    FeedbackReader(item: item, store: store) { files in showPreview(item, files: files) }.id(item.id)
                } else {
                    VStack(spacing: 12) {
                    ContentUnavailableView(state.search.isEmpty ? "Select an assignment" : "No assignment selected", systemImage: "doc.text", description: Text(state.search.isEmpty ? "Choose an assignment to read its results, feedback and rubric." : "Choose a matching assignment from the sidebar."))
                    if let error = store.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle").feedbackFont(.subheadline).foregroundStyle(.secondary).padding().frame(maxWidth: 460)
                    }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
            .navigationTitle("Marks & Feedback")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Link("Open in Canvas", destination: selectedCanvasURL ?? URL(string: "https://canvas.sydney.edu.au")!)
                        .disabled(selectedCanvasURL == nil)
                        .help("Open this assessment in your browser for submission and other Canvas actions")
                }
                ToolbarSpacer(.fixed, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) {
                    Button("Quick Look", systemImage: "eye") { if let selected { showPreview(selected) } }
                        .keyboardShortcut("y", modifiers: .command)
                        .disabled(selected?.previewFiles.isEmpty != false || preview.loading)
                        .help("Preview attached documents (Space when an assessment is selected, or ⌘Y)")
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if let selected { FeedbackCopyActions(item: selected) { copyNotice = $0 } }
                        Divider()
                        Picker("Text Size", selection: $readingStep) {
                            ForEach(0...FeedbackReadingSize.maximum, id: \.self) { step in
                                Text("\(100 + step * 10)%").tag(step)
                            }
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .help("Copy and reading options").accessibilityLabel("Copy and reading options")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { store.refresh() } label: {
                        if store.syncing { ProgressView().controlSize(.small) }
                        else { Image(systemName: "arrow.clockwise") }
                    }.disabled(store.syncing).help("Refresh marks and feedback")
                        .accessibilityLabel("Refresh marks and feedback")
                }
            }
        }
        .environment(\.feedbackReadingStep, FeedbackReadingSize.clamped(readingStep))
        .frame(minWidth: 850, minHeight: 570)
        .quickLookPreview(previewSelection, in: preview.urls)
        .onChange(of: preview.selection) { old, value in
            if old != nil && value == nil && !searchFocused { listFocused = true }
        }
        .onDisappear { preview.cancel() }
        .overlay(alignment: .bottomLeading) {
            if preview.loading { ProgressView("Preparing previews…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).padding() }
            else if !preview.message.isEmpty { Text(preview.message).font(.callout).padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).padding().allowsHitTesting(false) }
        }
        .onChange(of: preview.message) { _, value in
            if !value.isEmpty { AccessibilityNotification.Announcement(value).post() }
        }
        .overlay(alignment: .bottomTrailing) {
            if !copyNotice.isEmpty { Text(copyNotice).font(.callout).padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).padding().accessibilityLabel(copyNotice) }
        }
        .task(id: copyNotice) {
            guard !copyNotice.isEmpty else { return }
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { copyNotice = "" }
        }
        .onAppear {
            if state.selectionID == nil {
                let id = store.designMode ? store.items.first?.id : store.items.first { $0.id == savedSelection }?.id
                state.select(id ?? defaultItem?.id, in: store.items)
            }
            listFocused = true
            store.refreshIfNeeded()
        }
        .onChange(of: state.search) { _, _ in state.reconcile(in: store.items) }
        .onChange(of: state.selectionID) { _, value in savedSelection = value ?? ""; preview.cancel() }
        .onChange(of: store.items.map(\.id)) { old, _ in
            state.reconcile(in: store.items)
            if old.isEmpty && state.selectionID == nil && state.search.isEmpty {
                state.select(store.items.first { $0.id == savedSelection }?.id ?? defaultItem?.id, in: store.items)
            }
        }
        .background {
            Button("Find") { searchFocused = true }.keyboardShortcut("f").hidden()
        }
    }
    private var assignmentList: some View {
                List(selection: Binding(get: { state.selectionID }, set: { state.select($0, in: store.items) })) {
                    ForEach(FeedbackFormat.groups(filtered), id: \.0) { course, items in
                        Section(isExpanded: Binding(
                            get: { !state.collapsedCourses.contains(course) },
                            set: { expanded in
                                if expanded { state.collapsedCourses.remove(course) }
                                else { state.collapsedCourses.insert(course) }
                                state.reconcile(in: store.items)
                            }
                        )) {
                            ForEach(items) { item in
                                FeedbackSidebarRow(item: item).tag(item.id)
                            }
                        } header: {
                            Text(course).feedbackFont(.subheadline, weight: .semibold)
                        }
                    }
                }
                .listStyle(.sidebar)
                .focused($listFocused)
                .onKeyPress(.space, phases: .down) { _ in
                    guard listFocused, let selected else { return .ignored }
                    showPreview(selected); return .handled
                }
                .copyable(selected.map { [FeedbackExport.feedback($0)] } ?? [])
                .contextMenu(forSelectionType: String.self) { ids in
                    if let item = store.items.first(where: { ids.contains($0.id) }) {
                        Button("Quick Look", systemImage: "eye") { showPreview(item) }.disabled(item.previewFiles.isEmpty)
                        Divider()
                        FeedbackCopyActions(item: item) { copyNotice = $0 }
                    }
                }
                .overlay { if filtered.isEmpty { Text("No matching assignments").foregroundStyle(.secondary) } }
    }
    private func selectSearchResult() {
        let rows = FeedbackFormat.groups(state.visible(store.items)).flatMap(\.1)
        state.select(selected?.id ?? rows.first?.id, in: store.items)
        searchFocused = false; listFocused = true
    }
    private var selectedCanvasURL: URL? {
        selected.flatMap { URL(string: "https://canvas.sydney.edu.au/courses/\($0.courseID)/assignments/\($0.assignmentID)") }
    }
    private var previewSelection: Binding<URL?> {
        Binding(get: { preview.selection }, set: { value in
            if let value { preview.selection = value }
            else { preview.cancel() }
        })
    }
    private func showPreview(_ item: FeedbackItem, files: [FeedbackAttachment]? = nil) {
        preview.show(files ?? item.previewFiles, cached: { store.localURL($0) }) { file in
            await store.obtain(file, itemID: item.id)
        }
    }
    private var defaultItem: FeedbackItem? {
        store.items.filter { !$0.comments.isEmpty }.sorted { $0.recentDate > $1.recentDate }.first
        ?? store.items.first { !$0.rubric.isEmpty } ?? store.items.first
    }
}

private struct FeedbackSidebarRow: View {
    let item: FeedbackItem
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc").feedbackFont(.title2).foregroundStyle(.secondary).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).feedbackFont(.body).lineLimit(2)
                Text(item.subtitle).feedbackFont(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            if let mark = item.markLabel { Text(mark).feedbackFont(.body, weight: .semibold) }
        }
        .help(item.originalTitle)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.course + ", " + item.title + ", " + (item.markLabel ?? item.subtitle))
    }
}
