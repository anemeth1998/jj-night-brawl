import SwiftUI

/// OPTIONS — a real panel on the same alley (loop keeps playing behind the left column).
/// SOUND master · MUSIC / SFX detents · HAPTICS · a short control legend · BACK.
/// Every toggle / detent fires SFX; BACK plays `uiBack`.
struct OptionsPanel: View {
    var bridge: GameCanvasBridge
    var sfx: MenuSFX
    @Binding var muted: Bool
    var onBack: () -> Void

    private static let detents = 4 // 0…4 → 0 / 25 / 50 / 75 / 100 %

    @State private var music: Int = OptionsPanel.detents
    @State private var effects: Int = OptionsPanel.detents
    @State private var haptics: Bool = FeelHaptics.enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            MenuPanelHeader(eyebrow: "OPTIONS", title: "SOUND & FEEL")
                .padding(.bottom, 8)

            MenuToggleRow(title: "SOUND", hint: "Master", isOn: !muted, sfx: sfx, pressCue: nil) {
                // GameAudio orders the click: OFF → click then mute, ON → unmute then click.
                muted = sfx.toggleMute(current: muted)
            }

            DetentBar(title: "MUSIC", value: music, steps: Self.detents + 1, sfx: sfx) { v in
                music = v
                bridge.engine?.audio.setMusicVolume(Float(v) / Float(Self.detents))
            }

            DetentBar(title: "SFX", value: effects, steps: Self.detents + 1, sfx: sfx) { v in
                effects = v
                bridge.engine?.audio.setSfxVolume(Float(v) / Float(Self.detents))
            }

            MenuToggleRow(title: "HAPTICS", hint: "Taps & hits", isOn: haptics, sfx: sfx) {
                haptics.toggle()
                FeelHaptics.enabled = haptics
                if haptics { FeelHaptics.medium() }
            }

            legend
                .padding(.top, 8)
                .padding(.bottom, 6)

            MenuRow(title: "BACK", hint: "Main menu", style: .back, sfx: sfx, action: onBack)
        }
        .onAppear(perform: syncFromAudio)
    }

    /// Static control legend — not a new screen.
    private var legend: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("CONTROLS")
                .font(.system(size: 9, weight: .bold))
                .tracking(3)
                .foregroundColor(MenuTheme.gold.opacity(0.9))
            legendLine("STICK", "move · hold SPRINT to run")
            legendLine("PUNCH · KICK · JUMP", "right-thumb cluster")
            legendLine("RIFF", "full meter clears the crowd")
            legendLine("GUN", "unlocks after Club Floor")
        }
        .padding(.horizontal, 14)
        .accessibilityElement(children: .combine)
    }

    private func legendLine(_ key: String, _ what: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(key)
                .font(MenuTheme.display(10, weight: .bold))
                .tracking(0.8)
                .foregroundColor(MenuTheme.cyan.opacity(0.9))
            Text(what)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.white.opacity(0.55))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    private func syncFromAudio() {
        haptics = FeelHaptics.enabled
        guard let audio = bridge.engine?.audio else { return }
        muted = audio.isMuted
        music = Int((audio.musicVolume * Float(Self.detents)).rounded())
        effects = Int((audio.sfxVolume * Float(Self.detents)).rounded())
    }
}
