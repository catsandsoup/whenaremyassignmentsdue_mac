import SwiftUI

// The full labelled row is the button, including whitespace, rather than just the chevron.
struct ComfortableDisclosureStyle: DisclosureGroupStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) { configuration.isExpanded.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0)).accessibilityHidden(true)
                    configuration.label.feedbackFont(.body)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                .padding(.horizontal, 8).contentShape(Rectangle())
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")
            if configuration.isExpanded { configuration.content.padding(.leading, 8) }
        }
    }
}
