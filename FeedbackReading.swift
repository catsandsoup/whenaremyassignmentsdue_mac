import SwiftUI
import AppKit

private struct FeedbackReadingStepKey: EnvironmentKey { static let defaultValue = 0 }
extension EnvironmentValues {
    var feedbackReadingStep: Int {
        get { self[FeedbackReadingStepKey.self] }
        set { self[FeedbackReadingStepKey.self] = newValue }
    }
}
private struct FeedbackFont: ViewModifier {
    @Environment(\.feedbackReadingStep) private var step
    let style: Font.TextStyle
    let weight: Font.Weight?
    func body(content: Content) -> some View {
        let native = NSFont.preferredFont(forTextStyle: nativeStyle)
        let resized = NSFont(descriptor: native.fontDescriptor, size: native.pointSize * FeedbackReadingSize.scale(step)) ?? native
        let font = step == 0 ? Font.system(style) : Font(resized)
        content.font(weight.map { font.weight($0) } ?? font)
    }
    private var nativeStyle: NSFont.TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .caption: .caption1
        case .caption2: .caption2
        case .footnote: .footnote
        case .callout: .callout
        default: .body
        }
    }
}
extension View {
    func feedbackFont(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> some View {
        modifier(FeedbackFont(style: style, weight: weight))
    }
}
struct FeedbackReadingActions: View {
    @Binding var step: Int
    var body: some View {
        Button("Larger Text", systemImage: "plus.magnifyingglass") { step = FeedbackReadingSize.clamped(step + 1) }
            .keyboardShortcut("+", modifiers: .command).disabled(step >= FeedbackReadingSize.maximum)
        Button("Smaller Text", systemImage: "minus.magnifyingglass") { step = FeedbackReadingSize.clamped(step - 1) }
            .keyboardShortcut("-", modifiers: .command).disabled(step <= 0)
        Button("Actual Size") { step = 0 }.keyboardShortcut("0", modifiers: .command).disabled(step == 0)
    }
}
struct FeedbackReadingCommands: Commands {
    @AppStorage("feedbackReadingSize") private var step = 0
    var body: some Commands {
        CommandGroup(before: .sidebar) {
            FeedbackReadingActions(step: $step)
        }
    }
}
