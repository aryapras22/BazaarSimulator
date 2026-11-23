import SwiftUI

/// What a dialog asks, and what its button does.
struct AppDialogContent: Identifiable {
    enum Kind {
        /// A question with Cancel and a red confirm button.
        case confirm(confirmTitle: String, action: () -> Void)
        /// A notice with one button.
        case notice(symbol: String, buttonTitle: String)
    }

    let id = UUID()
    let title: String
    let message: Text
    let kind: Kind
}

/// A small dark card in the middle of the window, over a dimmed backdrop. It replaces the system alert so the
/// delete confirmations and notices look like the rest of the app.
struct AppDialog: View {
    let content: AppDialogContent
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: Spacing.m) {
            if case .notice(let symbol, _) = content.kind {
                Image(systemName: symbol)
                    .font(.system(size: 26))
                    .foregroundColor(Palette.destructive)
            }

            VStack(spacing: Spacing.xs) {
                Text(content.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                content.message
                    .font(.system(size: 13))
                    .foregroundColor(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            buttons
        }
        .padding(Spacing.l)
        .frame(width: 300)
        .glassModalSurface()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var buttons: some View {
        switch content.kind {
        case .confirm(let confirmTitle, let action):
            HStack(spacing: Spacing.s) {
                Button("Cancel", action: dismiss)
                    .buttonStyle(DialogButtonStyle(fill: Palette.control, textColor: Palette.textPrimary))
                    .keyboardShortcut(.cancelAction)
                Button(confirmTitle) {
                    action()
                    dismiss()
                }
                .buttonStyle(DialogButtonStyle(fill: Palette.destructive, textColor: .white))
                .keyboardShortcut(.defaultAction)
            }
        case .notice(_, let buttonTitle):
            Button(buttonTitle, action: dismiss)
                .buttonStyle(DialogButtonStyle(fill: Palette.highlight, textColor: Color(hex: 0x1A0F08)))
                .keyboardShortcut(.defaultAction)
        }
    }
}

private struct DialogButtonStyle: ButtonStyle {
    let fill: Color
    let textColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(fill.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
    }
}

extension View {
    /// Shows the dialog over this view, with the rest of the window dimmed and out of reach until it is answered.
    func appDialog(_ content: Binding<AppDialogContent?>) -> some View {
        // What is behind the dialog is blurred, as behind Insights.
        blur(radius: content.wrappedValue == nil ? 0 : 14)
        .overlay {
            if let shown = content.wrappedValue {
                ZStack {
                    Palette.scrim
                        .ignoresSafeArea()
                        .onTapGesture { content.wrappedValue = nil }
                    AppDialog(content: shown) { content.wrappedValue = nil }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: content.wrappedValue?.id)
    }
}

#Preview("Confirm") {
    AppDialog(
        content: AppDialogContent(
            title: "Delete Project?",
            message: Text("Deleting “Basha Vol. 1” will also remove its data."),
            kind: .confirm(confirmTitle: "Delete", action: {})
        ),
        dismiss: {}
    )
    .padding(40)
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

#Preview("Notice") {
    AppDialog(
        content: AppDialogContent(
            title: "Unsupported File",
            message: Text("“Plan_Legend.dwg” isn’t supported. Please upload a PDF."),
            kind: .notice(symbol: "doc.badge.exclamationmark", buttonTitle: "Ok")
        ),
        dismiss: {}
    )
    .padding(40)
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
