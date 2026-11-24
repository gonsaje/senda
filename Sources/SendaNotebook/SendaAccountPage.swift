import SwiftUI

struct AccountPage<Content: View>: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    var back: (() -> Void)?
    let close: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.dynamicTypeSize) private var textSize
    #if os(iOS)
    @State private var fittedHeight: CGFloat = 450
    @State private var detent = PresentationDetent.height(450)
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if back == nil { navigation }
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(NotebookTypography.heading(34, relativeTo: .largeTitle))
                        .accessibilityAddTraits(.isHeader)
                    if let detail {
                        Text(detail).font(.body).foregroundStyle(NotebookStyle.quiet)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 16, content: content)
            }
            .padding(.horizontal, 24)
            .padding(.top, back == nil ? 20 : 8)
            .padding(.bottom, 16)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
            #if os(iOS)
            .onGeometryChange(for: CGFloat.self) { ceil($0.size.height) } action: { height in
                guard back == nil else { return }
                fittedHeight = height
                if detent != .large { detent = .height(height) }
            }
            #endif
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if back != nil {
                navigation.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
                    .frame(maxWidth: 500).frame(maxWidth: .infinity)
                    .background(NotebookStyle.ivory)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .buttonStyle(.plain)
        #if os(iOS)
        .presentationBackground(NotebookStyle.ivory)
        .presentationDragIndicator(.visible)
        .presentationDetents(fullHeight ? [.large] : [.height(fittedHeight), .large],
                             selection: fullHeight ? .constant(.large) : $detent)
        #endif
    }

    private var fullHeight: Bool { back != nil || textSize.isAccessibilitySize }

    private var navigation: some View {
        HStack {
            if let back {
                Button(action: back) {
                    Label("Account options", systemImage: "chevron.left")
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: 48).contentShape(Rectangle())
                }
                .foregroundStyle(NotebookStyle.clay)
                .accessibilityLabel("Back to account options")
            } else {
                TrainingWordmark(width: 92)
            }
            Spacer(minLength: 8)
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 34, height: 34)
                    .background(NotebookStyle.inputSurface, in: NotebookStyle.squircle(12))
                    .frame(width: 48, height: 48, alignment: .trailing)
                    .contentShape(Rectangle())
            }.accessibilityLabel("Close").accessibilityIdentifier("senda-account-close")
        }
    }
}

struct AccountButtonStyle: ButtonStyle {
    enum Treatment { case apple, google, email, primary }
    let treatment: Treatment
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(foreground)
            .background(background, in: NotebookStyle.squircle(14))
            .overlay {
                if treatment == .google {
                    NotebookStyle.squircle(14).strokeBorder(NotebookStyle.ink.opacity(0.4), lineWidth: 1)
                }
            }
            .contentShape(NotebookStyle.squircle(14))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }

    private var foreground: Color {
        switch treatment {
        case .apple: NotebookStyle.pair(.white, .black)
        case .google: NotebookStyle.pair(Color(white: 0.12), .white)
        case .email: NotebookStyle.ink
        case .primary: isEnabled ? NotebookStyle.onPrimary : NotebookStyle.quiet
        }
    }

    private var background: Color {
        switch treatment {
        case .apple: NotebookStyle.pair(.black, .white)
        case .google: NotebookStyle.pair(.white, Color(white: 0.075))
        case .email: NotebookStyle.inputSurface
        case .primary: isEnabled ? NotebookStyle.primaryFill : NotebookStyle.inputSurface
        }
    }
}
