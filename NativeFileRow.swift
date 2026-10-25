import SwiftUI
import AppKit

// A shared native file interaction: the icon and name are one drag/selection target.
struct NativeFileRow: View {
    let name: String
    let detail: String
    let url: URL?
    var exportName: String? = nil
    var busy = false
    let preview: () -> Void
    let save: () -> Void
    let open: () -> Void
    @FocusState private var selected: Bool
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { document; actions }
            VStack(alignment: .leading, spacing: 10) { document; actions }
        }
        .padding(12)
        .background(selected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
        .focusable().focused($selected)
        .onKeyPress(.space) { guard !busy else { return .handled }; preview(); return .handled }
        .contextMenu {
            Button("Open", action: open).disabled(busy)
            Button("Quick Look", systemImage: "eye", action: preview).disabled(busy)
            Button("Save…", systemImage: "square.and.arrow.down", action: save).disabled(busy)
            if let url {
                Divider()
                Button("Show in Finder", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                ShareLink(item: AssignmentMaterialFile(url: url, exportName: exportName), preview: SharePreview(name))
            }
        }
    }
    @ViewBuilder private var document: some View {
        if let url {
            label.draggable(AssignmentMaterialFile(url: url, exportName: exportName))
                .help("Drag \(name) to Finder or another app. Double-click to open.")
                .accessibilityDragPoint(.center, description: "Copy \(name)")
        } else { label }
    }
    private var label: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: url?.pathExtension.lowercased() == "pdf" ? "doc.richtext" : "doc.text")
                .feedbackFont(.title2).foregroundStyle(.secondary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(name).feedbackFont(.body, weight: .medium).fixedSize(horizontal: false, vertical: true)
                if !detail.isEmpty { Text(detail).feedbackFont(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
        }
        .frame(minWidth: 140, maxWidth: .infinity, minHeight: 32, alignment: .leading)
        .contentShape(Rectangle()).textSelection(.disabled)
        .onTapGesture(count: 2, perform: open)
        .onTapGesture { selected = true }
        .accessibilityElement(children: .combine)
    }
    private var actions: some View {
        HStack(spacing: 8) {
            Button(action:preview) { Label("Preview",systemImage:"eye").feedbackFont(.body).frame(minHeight:28).contentShape(Rectangle()) }.help("Quick Look \(name) (Space)")
            Button(action:save) { Text("Save…").feedbackFont(.body).frame(minHeight:28).contentShape(Rectangle()) }.help("Save a copy of \(name)")
        }
        .buttonStyle(.bordered).controlSize(.large).disabled(busy)
        .fixedSize(horizontal: true, vertical: false)
    }
}
