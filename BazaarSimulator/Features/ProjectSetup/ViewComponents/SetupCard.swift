import SwiftUI

/// One of the two panels on the upload page: a title with a help button, an optional count, and what goes in it.
struct SetupCard<Help: View, Trailing: View, Content: View>: View {
    let title: String
    var subtitle: String?
    /// Space under the content. The drop zone sits in the card with a margin all round, while a list ends at its
    /// last row, whose own height already leaves room.
    var bottomPadding: CGFloat = Spacing.m
    @ViewBuilder let help: () -> Help
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let content: () -> Content

    @State private var showsHelp = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isEnabled ? Palette.textPrimary : Palette.textSecondary)

                        Button {
                            showsHelp.toggle()
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 11))
                                .foregroundColor(Palette.textSecondary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("What is this?")
                        .popover(isPresented: $showsHelp, arrowEdge: .trailing) {
                            help()
                        }
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundColor(Palette.textSecondary)
                    }
                }

                Spacer(minLength: Spacing.s)

                trailing()
            }
            .padding(.bottom, Spacing.s)

            Divider()
                .background(Palette.surfaceBorder)
                .padding(.bottom, Spacing.s)

            content()
        }
        .padding(.horizontal, Spacing.m)
        .padding(.top, Spacing.m)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(isEnabled ? Palette.surface : Palette.surfaceDisabled)
        .clipShape(RoundedRectangle(cornerRadius: Radius.l))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l)
                .stroke(isEnabled ? Palette.surfaceBorder : Palette.surfaceDisabledBorder, lineWidth: 1)
        )
    }
}

extension SetupCard where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        bottomPadding: CGFloat = Spacing.m,
        @ViewBuilder help: @escaping () -> Help,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title, subtitle: subtitle, bottomPadding: bottomPadding, help: help,
            trailing: { EmptyView() }, content: content
        )
    }
}

/// The small card a help button opens: what the thing is, and what a good one looks like.
struct SetupHelpPopover<Items: View>: View {
    let title: String
    let summary: String
    let itemsTitle: String
    @ViewBuilder let items: () -> Items

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundColor(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(itemsTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                items()
            }
        }
        .padding(Spacing.m)
        .frame(width: 210, alignment: .leading)
        .background(Palette.menu)
        .preferredColorScheme(.dark)
    }
}

/// One line of a help popover: a colored dot or a check, then the text.
struct SetupHelpItem: View {
    enum Mark {
        case dot(Color)
        case check
    }

    let mark: Mark
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            switch mark {
            case .dot(let color):
                Circle().fill(color).frame(width: 9, height: 9)
            case .check:
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Palette.textSecondary)
            }
            Text(text)
                .font(.system(size: 10.5))
                .foregroundColor(Palette.textSecondary)
        }
    }
}

#Preview("Legends") {
    SetupCard(
        title: "Legends",
        subtitle: "3 Elements",
        help: { Text("Help") },
        trailing: { Button("Clear All") {}.buttonStyle(.secondary) },
        content: { Text("Content").foregroundColor(Palette.textPrimary) }
    )
    .frame(width: 330)
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
