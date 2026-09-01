import SwiftUI

// MARK: - Icons

/// Interface icons. SF Symbols at a single weight, in `currentColor`, so a tab or button
/// controls its own colour. These are UI icons, not brand assets.
enum CIcon {
    static let heart = "heart"
    static let program = "checklist"
    static let education = "book"
    static let profile = "person.crop.circle"
    static let clock = "clock"
    static let arrowRight = "arrow.right"
    static let sync = "arrow.triangle.2.circlepath"
    static let check = "checkmark"
    static let close = "xmark"
    static let chevronUp = "chevron.up"
    static let plus = "plus"
}

// MARK: - Button

enum CButtonVariant { case primary, secondary, ghost }

/// Full-width pill. Primary is the black action surface; secondary is hairline on the page;
/// ghost is an underlined text link, for "Not now" and "Back".
struct CButton: View {
    let title: String
    var variant: CButtonVariant = .primary
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .cText(TypeScale.labelButton, weight: .medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .foregroundStyle(foreground)
                .background(background, in: Capsule())
                .overlay(Capsule().stroke(border, lineWidth: variant == .secondary ? 1 : 0))
                .underline(variant == .ghost)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var foreground: Color {
        switch variant {
        case .primary: return disabled ? CColor.card : CColor.actionInk
        case .secondary: return CColor.heading
        case .ghost: return CColor.inkSecondary
        }
    }
    private var background: Color {
        switch variant {
        case .primary: return disabled ? CColor.inkDisabled : CColor.action
        case .secondary, .ghost: return .clear
        }
    }
    private var border: Color { CColor.hairline }
}

// MARK: - Card

struct Card<Content: View>: View {
    var label: String? = nil
    var padding: CGFloat = Spacing.sm
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let label {
                Text(label).eyebrow().padding(.bottom, Spacing.xxs)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(CColor.card, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(CColor.hairline, lineWidth: 1))
    }
}

// MARK: - Chip

/// Provenance chip (source, arm). Informational only. Userkind `Tag / sm`.
struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .cText(TypeScale.bodySm)
            .tracking(0.14)
            .foregroundStyle(CColor.inkSecondary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxxs)
            .background(CColor.card, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).stroke(CColor.hairline, lineWidth: 1))
    }
}

// MARK: - Field

/// Labelled input. Error copy is mechanical only (ValidationCopy), never evaluative.
struct CField: View {
    let label: String
    @Binding var text: String
    var error: String? = nil
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var secure = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxxs) {
            Text(label).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
            Group {
                if secure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .cText(TypeScale.bodyBase)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(CColor.card, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(error == nil ? CColor.hairline : CColor.heading, lineWidth: 1))
            if let error {
                Text(error).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }
}

// MARK: - Segmented

/// Segmented control (e.g. trend range 2W / 6W / All).
struct Segmented<T: Hashable>: View {
    let options: [(value: T, label: String)]
    @Binding var selection: T
    let ariaLabel: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { opt in
                let on = opt.value == selection
                Button {
                    withAnimation(Motion.brand) { selection = opt.value }
                } label: {
                    Text(opt.label)
                        .cText(TypeScale.bodySm)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxxs)
                        .foregroundStyle(on ? CColor.actionInk : CColor.inkSecondary)
                        .background(on ? CColor.action : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
        .padding(2)
        .background(CColor.card, in: Capsule())
        .overlay(Capsule().stroke(CColor.hairline, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(ariaLabel)
    }
}

// MARK: - Progress

/// Journey progress indicator: one dot per step, current dot elongated.
struct StepDots: View {
    let total: Int
    let current: Int
    var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(1...max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(i == current ? CColor.heading : CColor.hairline)
                    .frame(width: i == current ? 24 : 6, height: 6)
            }
        }
        .padding(.bottom, Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current) of \(total)")
    }
}

/// Chapter progress as one segment per chapter: filled means read. The count is carried
/// by the accessibility label rather than printed beside the bar.
struct SegmentedProgress: View {
    let read: Int
    let total: Int
    let label: String
    var body: some View {
        HStack(spacing: Spacing.xxxs) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule().fill(i < read ? CColor.action : CColor.hairline).frame(height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

// MARK: - Screen scaffold

/// Page wrapper: Corveo wordmark header with eyebrow and action slot, scrollable content
/// column with optional overline and title, pinned footer. Every screen renders inside one.
struct Screen<Content: View>: View {
    var eyebrow: String? = nil
    var overline: String? = nil
    var title: String? = nil
    var withTabBar = false
    var action: AnyView? = nil
    var footer: AnyView? = nil
    /// Changes when the content swaps underneath a screen that stays mounted.
    var scrollKey: String = ""
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 18)
                    .accessibilityLabel(ProductCopy.corveoWordmark)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    if let eyebrow { Text(eyebrow).eyebrow() }
                    if let action { action }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 0).id("top")
                        if let overline {
                            Text(overline).eyebrow().padding(.bottom, Spacing.xxxs)
                        }
                        if let title {
                            Text(title)
                                .cDisplay(TypeScale.heading3XL)
                                .foregroundStyle(CColor.heading)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, Spacing.sm)
                                .accessibilityAddTraits(.isHeader)
                        }
                        content()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, withTabBar ? 96 : Spacing.md)
                }
                .scrollIndicators(.hidden)
                .onChange(of: scrollKey) { _, _ in proxy.scrollTo("top", anchor: .top) }
            }

            if let footer {
                footer
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.md)
            }
        }
        .background(CColor.page.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Header affordance for the tab screens: profile and settings behind one icon.
struct ProfileLink: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: CIcon.profile)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(CColor.inkTertiary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .padding(.vertical, -11)
        .padding(.trailing, -11)
        .accessibilityLabel(AppCopy.common.profileAria)
    }
}

/// A small underlined text link in the header action slot.
struct HeaderLink: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).eyebrow().underline()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab bar

enum MainTab: Hashable, CaseIterable {
    case program, record, education

    var icon: String {
        switch self {
        case .program: return CIcon.program
        case .record: return CIcon.heart
        case .education: return CIcon.education
        }
    }
    var label: String {
        switch self {
        case .program: return AppCopy.tabs.program
        case .record: return AppCopy.tabs.record
        case .education: return AppCopy.tabs.education
        }
    }
}

/// Floating tab bar, fixed above the home indicator. Icon-only: the record sits in the
/// middle as the home of the app. Labels are on the accessible name rather than on screen.
struct FloatingTabBar: View {
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: Spacing.xxxs) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                let on = tab == selection
                Button {
                    withAnimation(Motion.brand) { selection = tab }
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(on ? CColor.heading : CColor.actionInk)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(on ? CColor.card : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
        .padding(Spacing.xxxs)
        .background(CColor.action, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        .padding(.bottom, Spacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AppCopy.tabs.navAria)
    }
}

// MARK: - Small helpers

/// A radio-style option card used by Connect and Cadence.
struct OptionCard: View {
    let title: String
    let body_: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(title).cText(TypeScale.bodyBase, weight: .medium).foregroundStyle(CColor.heading)
                Text(body_).cText(TypeScale.bodySm).foregroundStyle(CColor.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .background(CColor.card, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(selected ? CColor.heading : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// A checkbox row with a label.
struct CheckRow: View {
    @Binding var checked: Bool
    let label: String
    var body: some View {
        Button { checked.toggle() } label: {
            HStack(alignment: .top, spacing: Spacing.xs) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(checked ? CColor.heading : CColor.inkTertiary)
                    .padding(.top, 1)
                Text(label).cText(TypeScale.bodySm).foregroundStyle(CColor.ink)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(checked ? [.isSelected] : [])
    }
}

/// Label / value pair in an article's meta strip.
struct MetaPair: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).cText(TypeScale.bodySm, weight: .medium).foregroundStyle(CColor.inkTertiary)
            Text(value).cText(TypeScale.bodyBase).foregroundStyle(CColor.ink)
        }
    }
}

/// Section heading inside a screen (Userkind sets these in the sans at medium).
struct SectionHeading: View {
    let text: String
    var size: CGFloat = TypeScale.headingXL
    var body: some View {
        Text(text)
            .cText(size, weight: .medium)
            .tracking(-0.3)
            .foregroundStyle(CColor.heading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(CColor.hairline).frame(height: 1) }
}
