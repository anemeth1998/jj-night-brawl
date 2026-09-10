import SwiftUI
import UIKit

// MARK: - Palette / motion

/// Zine palette for every pre-combat surface. No system blue, no `.borderedProminent`.
enum MenuTheme {
    static let pink = Color(red: 1.0, green: 0.18, blue: 0.54)          // #FF2E8A primary
    static let cyan = Color(red: 0.18, green: 0.89, blue: 0.90)         // #2EE3E6 accent
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.42)          // #FFD66B eyebrow
    static let surface = Color(red: 0.027, green: 0.024, blue: 0.047)   // #07060C
    static let surface2 = Color(red: 0.086, green: 0.067, blue: 0.122)  // #16111F

    /// Route chrome slides in from the left edge over the same alley backdrop.
    static let slide: AnyTransition = .opacity.combined(with: .move(edge: .leading))
    static let slideAnim: Animation = .easeInOut(duration: 0.22)

    /// Condensed heavy — the closest bundled stand-in for a display face (no new font files).
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
}

// MARK: - Haptics (shared with combat pad)

/// Light device feedback on taps / punches / kicks. No-op on sim without Taptic and when the
/// Options HAPTICS toggle is off (`jj.hapticsEnabled`, default on).
enum FeelHaptics {
    static let key = "jj.hapticsEnabled"
    private static let lightGen = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGen = UIImpactFeedbackGenerator(style: .medium)

    private static var storedEnabled: Bool = loadEnabled()

    static var enabled: Bool {
        get { storedEnabled }
        set {
            storedEnabled = newValue
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    private static func loadEnabled() -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    static func light() {
        guard enabled else { return }
        lightGen.prepare()
        lightGen.impactOccurred(intensity: 0.7)
    }

    static func medium() {
        guard enabled else { return }
        mediumGen.prepare()
        mediumGen.impactOccurred(intensity: 0.9)
    }
}

enum MenuHaptic {
    case none, light, medium

    func fire() {
        switch self {
        case .none: break
        case .light: FeelHaptics.light()
        case .medium: FeelHaptics.medium()
        }
    }
}

// MARK: - SFX helper

/// One door for menu sounds. Every control routes through here so the UI bank stays consistent
/// and `unlock()` always precedes the first SFX on a cold app. Engine nav helpers are silent.
struct MenuSFX {
    enum Cue { case tap, hover, confirm, back, deny }

    let bridge: GameCanvasBridge

    private var audio: GameAudio? { bridge.engine?.audio }

    func play(_ cue: Cue) {
        guard let audio else { return }
        audio.unlock()
        switch cue {
        case .tap: audio.uiTap()
        case .hover: audio.uiHover()
        case .confirm: audio.uiConfirm()
        case .back: audio.uiBack()
        case .deny: audio.uiDeny()
        }
    }

    /// Mute chip / SOUND toggle. `GameAudio.toggleMute` owns the order
    /// (click → mute when turning off, unmute → click when turning on). Returns new muted state.
    func toggleMute(current: Bool) -> Bool {
        guard let audio else { return current }
        audio.unlock()
        return audio.toggleMute()
    }
}

// MARK: - Core press / release behaviour

/// The single gesture contract for every menu control (spec §3.3):
/// - SFX + haptic on press-down so it feels instant
/// - the action fires on release **inside** the hit box; sliding off cancels
/// - the action is never called from `onChanged` (that was the double-fire bug)
/// - disabled controls play `uiDeny` on press and never run the action
struct MenuPressable<Label: View>: View {
    var enabled: Bool = true
    var sfx: MenuSFX
    var pressCue: MenuSFX.Cue? = .tap
    var successCue: MenuSFX.Cue? = nil
    var pressHaptic: MenuHaptic = .light
    var successHaptic: MenuHaptic = .none
    var accessibilityLabel: String
    var accessibilityHint: String = ""
    var action: () -> Void
    @ViewBuilder var label: (_ pressed: Bool) -> Label

    @State private var pressed = false
    @State private var tracking = false
    @State private var size: CGSize = .zero

    var body: some View {
        label(pressed && enabled)
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { size = g.size }
                        .onChange(of: g.size) { size = $0 }
                }
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if !tracking {
                            tracking = true
                            pressed = true
                            if enabled {
                                if let pressCue { sfx.play(pressCue) }
                                pressHaptic.fire()
                            } else {
                                sfx.play(.deny)
                            }
                        } else {
                            pressed = inside(value.location)
                        }
                    }
                    .onEnded { value in
                        let ok = tracking && enabled && inside(value.location)
                        tracking = false
                        pressed = false
                        guard ok else { return }
                        if let successCue { sfx.play(successCue) }
                        successHaptic.fire()
                        action()
                    }
            )
            .onDisappear {
                tracking = false
                pressed = false
            }
            .animation(.easeOut(duration: 0.08), value: pressed)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(enabled ? accessibilityHint : "Unavailable")
            .accessibilityAddTraits(.isButton)
    }

    private func inside(_ p: CGPoint) -> Bool {
        guard size.width > 0, size.height > 0 else { return true }
        return CGRect(origin: .zero, size: size).insetBy(dx: -14, dy: -14).contains(p)
    }
}

// MARK: - Left-column row

/// `▶ TITLE ……… hint` row. Primary rows confirm (medium haptic), back rows play `uiBack`.
struct MenuRow: View {
    enum Style { case standard, primary, back }

    var title: String
    var hint: String = ""
    var enabled: Bool = true
    var style: Style = .standard
    var sfx: MenuSFX
    var action: () -> Void

    var body: some View {
        MenuPressable(
            enabled: enabled,
            sfx: sfx,
            pressCue: .tap,
            successCue: successCue,
            pressHaptic: .light,
            successHaptic: style == .primary ? .medium : (style == .back ? .light : .none),
            accessibilityLabel: title,
            accessibilityHint: hint,
            action: action
        ) { pressed in
            HStack(spacing: 10) {
                Text("▶")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(pressed ? MenuTheme.pink : .clear)
                    .frame(width: 14, alignment: .leading)
                Text(title)
                    .font(MenuTheme.display(14))
                    .tracking(1.1)
                    .foregroundColor(enabled
                        ? (pressed ? .white : Color.white.opacity(0.82))
                        : Color.white.opacity(0.35))
                Spacer(minLength: 8)
                if !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.white.opacity(enabled ? 0.42 : 0.22))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(pressed ? MenuTheme.pink.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(pressed ? MenuTheme.pink.opacity(0.75) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(pressed ? 0.96 : 1, anchor: .leading)
        }
    }

    private var successCue: MenuSFX.Cue? {
        switch style {
        case .primary: return .confirm
        case .back: return .back
        case .standard: return nil
        }
    }
}

// MARK: - Capsule (primary / ghost)

/// START BRAWL, RETRY, PLAY AGAIN, CONTINUE. `pulse` = optional living-CTA breathing.
struct MenuCapsule: View {
    enum Style { case primary, ghost }

    var title: String
    var style: Style = .primary
    var enabled: Bool = true
    var minHeight: CGFloat = 52
    var pulse: Bool = false
    var sfx: MenuSFX
    var pressCue: MenuSFX.Cue? = .tap
    var successCue: MenuSFX.Cue? = nil
    var successHaptic: MenuHaptic = .none
    var accessibilityLabel: String
    var action: () -> Void

    @State private var glow = false

    var body: some View {
        MenuPressable(
            enabled: enabled,
            sfx: sfx,
            pressCue: pressCue,
            successCue: successCue,
            pressHaptic: .light,
            successHaptic: successHaptic,
            accessibilityLabel: accessibilityLabel,
            action: action
        ) { pressed in
            Text(title)
                .font(MenuTheme.display(17))
                .tracking(1.4)
                .foregroundColor(enabled ? .white : Color.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(minHeight: max(minHeight, 44))
                .padding(.horizontal, 26)
                .background(Capsule().fill(fillColor(pressed)))
                .overlay(Capsule().stroke(strokeColor(pressed), lineWidth: 1))
                .shadow(color: style == .primary && enabled ? MenuTheme.pink.opacity(0.45) : .clear, radius: 12, y: 4)
                .scaleEffect(pressed ? 0.96 : 1)
                .opacity(pulse && !pressed ? (glow ? 1 : 0.75) : 1)
        }
        .onAppear {
            guard pulse else { return }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }

    private func fillColor(_ pressed: Bool) -> Color {
        switch style {
        case .primary:
            return enabled ? MenuTheme.pink.opacity(pressed ? 1 : 0.92) : Color.white.opacity(0.12)
        case .ghost:
            return pressed ? MenuTheme.pink.opacity(0.18) : Color.white.opacity(0.12)
        }
    }

    private func strokeColor(_ pressed: Bool) -> Color {
        switch style {
        case .primary: return Color.white.opacity(pressed ? 0.4 : 0.25)
        case .ghost: return pressed ? MenuTheme.pink.opacity(0.75) : Color.white.opacity(0.25)
        }
    }
}

// MARK: - Sound chip (glyph, top-trailing)

/// Mute toggle. No `uiTap` on down — `GameAudio.toggleMute` plays the two-note `uiToggle`
/// in the right order (click then mute / unmute then click).
struct SoundChip: View {
    var muted: Bool
    var sfx: MenuSFX
    var action: () -> Void

    var body: some View {
        MenuPressable(
            enabled: true,
            sfx: sfx,
            pressCue: nil,
            successCue: nil,
            pressHaptic: .light,
            successHaptic: .none,
            accessibilityLabel: muted ? "Sound off" : "Sound on",
            accessibilityHint: muted ? "Unmutes music and effects" : "Mutes music and effects",
            action: action
        ) { pressed in
            HStack(spacing: 6) {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(muted ? "SOUND OFF" : "SOUND ON")
                    .font(MenuTheme.display(11, weight: .bold))
                    .tracking(1)
            }
            .foregroundColor(muted ? Color.white.opacity(0.6) : .white)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Capsule().fill(pressed ? MenuTheme.pink.opacity(0.18) : Color.black.opacity(0.55)))
            .overlay(Capsule().stroke(pressed ? MenuTheme.pink.opacity(0.7) : Color.white.opacity(0.15), lineWidth: 1))
            .scaleEffect(pressed ? 0.96 : 1)
        }
    }
}

// MARK: - Fighter card (Endless select)

struct FighterCard: View {
    var title: String
    /// Only a state word (e.g. "LOCKED") — never a description of the fighter.
    var subtitle: String? = nil
    var asset: String?
    var selected: Bool
    var locked: Bool = false
    var sfx: MenuSFX
    var action: () -> Void

    var body: some View {
        MenuPressable(
            enabled: !locked,
            sfx: sfx,
            pressCue: .tap,
            successCue: nil,
            pressHaptic: .light,
            successHaptic: .none,
            accessibilityLabel: subtitle.map { "\(title). \($0)" } ?? title,
            accessibilityHint: selected ? "Selected" : "Previews this fighter",
            action: action
        ) { pressed in
            VStack(spacing: 6) {
                Group {
                    if let asset, let ui = UIImage(named: asset) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        // Missing art → dark monogram tile, never a pink placeholder box.
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                            .overlay(
                                Text(String(title.prefix(2)))
                                    .font(MenuTheme.display(22, weight: .black))
                                    .foregroundColor(.white.opacity(0.85))
                            )
                    }
                }
                .frame(width: 80, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .saturation(locked ? 0 : 1)
                Text(title)
                    .font(MenuTheme.display(13, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(selected ? MenuTheme.pink : .white)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(MenuTheme.gold)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 84, minHeight: 130)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(pressed ? 0.16 : (selected ? 0.14 : 0.08)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? MenuTheme.pink : Color.white.opacity(0.25), lineWidth: selected ? 2 : 1)
            )
            .shadow(color: MenuTheme.pink.opacity(selected ? 0.4 : 0), radius: 8)
            .scaleEffect(pressed ? 0.96 : 1)
            .opacity(locked ? 0.55 : 1)
        }
    }
}

// MARK: - Options: toggle row

struct MenuToggleRow: View {
    var title: String
    var hint: String = ""
    var isOn: Bool
    var sfx: MenuSFX
    /// SOUND passes `nil` — the mute toggle plays its own two-note cue.
    var pressCue: MenuSFX.Cue? = .tap
    var action: () -> Void

    var body: some View {
        MenuPressable(
            enabled: true,
            sfx: sfx,
            pressCue: pressCue,
            successCue: nil,
            pressHaptic: .light,
            successHaptic: .none,
            accessibilityLabel: "\(title), \(isOn ? "on" : "off")",
            accessibilityHint: hint,
            action: action
        ) { pressed in
            HStack(spacing: 10) {
                Text(title)
                    .font(MenuTheme.display(14))
                    .tracking(1.1)
                    .foregroundColor(pressed ? .white : Color.white.opacity(0.82))
                if !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.42))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? MenuTheme.pink : Color.white.opacity(0.14))
                        .frame(width: 44, height: 24)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .padding(3)
                }
                Text(isOn ? "ON" : "OFF")
                    .font(MenuTheme.display(11, weight: .bold))
                    .foregroundColor(isOn ? MenuTheme.pink : Color.white.opacity(0.5))
                    .frame(width: 28, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(pressed ? MenuTheme.pink.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(pressed ? MenuTheme.pink.opacity(0.75) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(pressed ? 0.97 : 1, anchor: .leading)
        }
    }
}

// MARK: - Options: detent bar (MUSIC / SFX gain)

/// Five-detent bar. `uiTap` on touch-down, `uiHover` tick on every detent change while dragging.
struct DetentBar: View {
    var title: String
    var value: Int
    var steps: Int = 5
    var sfx: MenuSFX
    var onChange: (Int) -> Void

    @State private var dragIndex: Int? = nil

    private var percent: Int {
        guard steps > 1 else { return 100 }
        return value * 100 / (steps - 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(MenuTheme.display(14))
                    .tracking(1.1)
                    .foregroundColor(Color.white.opacity(0.82))
                Spacer(minLength: 8)
                Text("\(percent)%")
                    .font(MenuTheme.display(11, weight: .bold))
                    .foregroundColor(value == 0 ? Color.white.opacity(0.5) : MenuTheme.pink)
                    .frame(width: 40, alignment: .trailing)
            }
            GeometryReader { g in
                HStack(spacing: 4) {
                    ForEach(0..<steps, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(i <= value && value > 0
                                ? MenuTheme.pink.opacity(dragIndex != nil ? 1 : 0.9)
                                : Color.white.opacity(0.14))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { v in
                            let idx = index(for: v.location.x, width: g.size.width)
                            if dragIndex == nil {
                                sfx.play(.tap)
                                FeelHaptics.light()
                                dragIndex = idx
                                if idx != value { onChange(idx) }
                            } else if idx != dragIndex {
                                dragIndex = idx
                                sfx.play(.hover)
                                onChange(idx)
                            }
                        }
                        .onEnded { _ in dragIndex = nil }
                )
            }
            .frame(height: 16)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(percent) percent")
        .accessibilityAdjustableAction { direction in
            let next: Int
            switch direction {
            case .increment: next = min(steps - 1, value + 1)
            case .decrement: next = max(0, value - 1)
            @unknown default: next = value
            }
            if next != value {
                sfx.play(.hover)
                onChange(next)
            }
        }
    }

    private func index(for x: CGFloat, width: CGFloat) -> Int {
        guard width > 0, steps > 0 else { return value }
        let t = max(0, min(0.999, x / width))
        return Int(t * CGFloat(steps))
    }
}

// MARK: - Panel header (eyebrow + title)

struct MenuPanelHeader: View {
    var eyebrow: String
    var title: String
    var titleColor: Color = .white
    /// Wordmark treatment: 1px cyan offset shadow under the pink title.
    var cyanOffset: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .bold))
                .tracking(3.5)
                .foregroundColor(MenuTheme.gold)
                .shadow(color: .black.opacity(0.6), radius: 2)
            Text(title)
                .font(MenuTheme.display(26, weight: .black))
                .tracking(0.5)
                .foregroundColor(titleColor)
                .shadow(color: cyanOffset ? MenuTheme.cyan : .clear, radius: 0, x: 1, y: 1)
                .shadow(color: .black.opacity(0.6), radius: 2)
        }
    }
}
