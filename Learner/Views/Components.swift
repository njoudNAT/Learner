import SwiftUI

// MARK: - Goal form (shared by Onboarding, Learning Goal and Set a goal)

/// "I want to learn ___" + "I want to learn it in a Week / Month / Year".
/// One component, so every page looks and behaves identically.
struct GoalFormFields: View {
    @Binding var title: String
    @Binding var duration: GoalDuration
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("I want to learn")
                    .font(.subheadline)

                TextField("Swift", text: $title)
                    .focused(isFocused)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onSubmit { isFocused.wrappedValue = false }
                    .onChange(of: title) { _, newValue in
                        if newValue.count > 40 { title = String(newValue.prefix(40)) }
                    }

                Divider()
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("I want to learn it in a")
                    .font(.subheadline)

                // The container lets neighbouring glass shapes blend and animate together.
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(GoalDuration.allCases) { option in
                            DurationChip(title: option.title, isSelected: duration == option) {
                                withAnimation(.snappy) { duration = option }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Duration chip

struct DurationChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected
                ? .regular.tint(Color.brandOrange).interactive()
                : .regular.interactive(),
            in: .capsule
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Bottom action button (hidden while the keyboard is open)

/// The main button at the bottom of a form page.
/// Like Apple's own apps, it never floats over the keyboard: it is hidden while the
/// user types, and comes back when the keyboard closes (Done, scroll, or tap away).
struct BottomActionButton: View {
    let title: String
    let isEnabled: Bool
    var footnote: String? = nil
    var isTyping = false          // true while the keyboard is open
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if !isTyping {
                Button(action: action) {
                    Text(title)
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Color.brandOrange)
                .controlSize(.large)
                .disabled(!isEnabled)

                if let footnote {
                    Text(footnote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isTyping ? 0 : 16)
        .animation(.smooth, value: isTyping)
    }
}
// MARK: - Day styling (shared by the week strip and the calendar)

enum DayStyle {
    static func foreground(_ type: EntryType?, isToday: Bool) -> Color {
        switch type {
        case .learned: Color.brandOrange
        case .frozen:  Color.brandFreezeBlue
        case nil:      isToday ? Color.white : Color.primary
        }
    }

    static func background(_ type: EntryType?, isToday: Bool) -> Color {
        switch type {
        case .learned: Color.brandOrange.opacity(0.22)
        case .frozen:  Color.brandFreezeBlue.opacity(0.22)
        case nil:      isToday ? Color.brandOrange : Color.clear
        }
    }
}

// MARK: - Day circle

struct DayBubble: View {
    let day: Date
    let isToday: Bool
    let type: EntryType?

    var body: some View {
        Text(day, format: .dateTime.day())
            .font(.callout.weight(.medium))
            .foregroundStyle(DayStyle.foreground(type, isToday: isToday))
            .frame(width: 34, height: 34)
            .background(DayStyle.background(type, isToday: isToday), in: Circle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(day.formatted(.dateTime.day().month(.wide)))\(stateWord)")
    }

    private var stateWord: String {
        switch type {
        case .learned: ", learned"
        case .frozen:  ", freezed"
        case nil:      isToday ? ", today" : ""
        }
    }
}

// MARK: - Preview

private struct ComponentsPreview: View {
    @State private var title = "Swift"
    @State private var duration: GoalDuration = .week
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            GoalFormFields(title: $title, duration: $duration, isFocused: $focused)
            
            HStack(spacing: 12) {
                DayBubble(day: .now, isToday: true, type: nil)
                DayBubble(day: .now, isToday: false, type: .learned)
                DayBubble(day: .now, isToday: false, type: .frozen)
                DayBubble(day: .now, isToday: false, type: nil)
            }
            
        }
    }
}

#Preview("Components") {
    ComponentsPreview()
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}
