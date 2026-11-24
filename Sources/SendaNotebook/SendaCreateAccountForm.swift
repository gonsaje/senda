import SwiftUI

struct SendaCreateAccountForm: View {
    private typealias Field = SendaAccountRegistration.Field
    @Binding var form: SendaAccountRegistration
    let configured: Bool
    let submit: () -> Void

    @Environment(\.dynamicTypeSize) private var textSize
    @FocusState private var focus: Field?
    @State private var visited: Set<Field> = []
    @State private var attempted = false

    var body: some View {
        let names = textSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        names {
            entry("First name", .firstName) {
                TextField("First name", text: $form.firstName, prompt: Text("Alex").foregroundStyle(NotebookStyle.quiet))
                    .textContentType(.givenName).submitLabel(.next).onSubmit { focus = .lastName }
            }
            entry("Last name", .lastName) {
                TextField("Last name", text: $form.lastName, prompt: Text("Rivera").foregroundStyle(NotebookStyle.quiet))
                    .textContentType(.familyName).submitLabel(.next).onSubmit { focus = .email }
            }
        }
        entry("Email address", .email) {
            TextField("Email address", text: $form.email, prompt: Text(verbatim: "name@example.com").foregroundStyle(NotebookStyle.quiet))
                .textContentType(.emailAddress).autocorrectionDisabled()
                #if os(iOS)
                .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                #endif
                .submitLabel(.next).onSubmit { focus = .password }
        }
        VStack(alignment: .leading, spacing: 8) {
            entry("Password", .password) {
                SecureField("Password", text: $form.password, prompt: Text("Choose a password").foregroundStyle(NotebookStyle.quiet))
                    .textContentType(.newPassword).submitLabel(.next).onSubmit { focus = .confirmation }
            }
            strengthMeter
        }
        entry("Confirm password", .confirmation) {
            SecureField("Confirm password", text: $form.confirmation, prompt: Text("Re-enter your password").foregroundStyle(NotebookStyle.quiet))
                .textContentType(.newPassword).submitLabel(.go).onSubmit(create)
        }
        if !configured {
            Label("Account creation is unavailable in this build.", systemImage: "info.circle")
                .font(.footnote).foregroundStyle(NotebookStyle.quiet)
        }
        Button("Create account", action: create)
            .buttonStyle(AccountButtonStyle(treatment: .primary))
            .disabled(!configured)
            .onChange(of: focus) { previous, _ in
                if let previous { visited.insert(previous) }
            }
    }

    private func entry(_ title: LocalizedStringKey, _ field: Field, @ViewBuilder input: () -> some View) -> some View {
        let error = form.error(for: field)
        let completedConfirmation = field == .confirmation && !form.confirmation.isEmpty && form.confirmation.count >= form.password.count
        let showError = attempted || visited.contains(field) || completedConfirmation
        let success: String? = switch field {
        case .email where error == nil: "Email format looks valid."
        case .confirmation where error == nil: "Passwords match."
        default: nil
        }
        return AccountTextInput(title: title, focused: focus == field, error: showError ? error : nil,
                                success: success, select: { focus = field }) {
            input().focused($focus, equals: field).accessibilityLabel(title)
        }
    }

    private var strengthMeter: some View {
        let strength = form.strength
        let filled = form.password.isEmpty ? 0 : strength.rawValue
        let tint: Color = switch strength {
        case .weak: NotebookStyle.accountError
        case .fair: NotebookStyle.clay
        case .strong: NotebookStyle.olive
        }
        return HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(1...3, id: \.self) { index in
                    NotebookStyle.squircle(2).fill(index <= filled ? tint : NotebookStyle.dockOutline)
                        .frame(width: 17, height: 4)
                }
            }.accessibilityHidden(true)
            Text(form.password.isEmpty ? "Use at least 8 characters." : "Password strength: \(strength.label)")
                .font(.footnote.weight(.medium)).foregroundStyle(NotebookStyle.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Password strength")
        .accessibilityValue(form.password.isEmpty ? "Use at least 8 characters." : strength.label)
        .accessibilityIdentifier("account-password-strength")
    }

    private func create() {
        guard configured else { return }
        attempted = true
        if let invalid = form.firstInvalidField {
            focus = invalid
            if let error = form.error(for: invalid) { TrainingAccessibility.announce(error) }
            return
        }
        focus = nil
        submit()
    }
}

struct AccountTextInput<Content: View>: View {
    let title: LocalizedStringKey
    let focused: Bool
    var error: String?
    var success: String?
    let select: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold)).accessibilityHidden(true)
            HStack(spacing: 8) {
                content.textFieldStyle(.plain)
                    .accessibilityHint(error ?? success ?? "")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if success != nil {
                    Image(systemName: "checkmark").font(.footnote.weight(.bold))
                        .foregroundStyle(NotebookStyle.olive).accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(minHeight: 50)
            .background(focused ? NotebookStyle.accountFieldFocused : NotebookStyle.accountField, in: NotebookStyle.squircle(11))
            .overlay {
                NotebookStyle.squircle(11)
                    .strokeBorder(border, lineWidth: focused || error != nil ? 1.7 : 1)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle()).onTapGesture(perform: select)
            if let error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.footnote).foregroundStyle(NotebookStyle.accountError)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var border: Color {
        if error != nil { return NotebookStyle.accountError }
        if focused { return NotebookStyle.clay }
        return success != nil ? NotebookStyle.olive : NotebookStyle.accountFieldEdge
    }
}
