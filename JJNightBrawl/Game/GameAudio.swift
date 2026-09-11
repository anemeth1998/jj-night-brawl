import Foundation
import AVFoundation
import CoreGraphics

/// Procedural SFX via AVAudioEngine (no external sound files).
///
/// Important: AVAudioEngine attach/detach **must** stay on the main thread.
/// Detaching from a buffer completion callback (audio thread) freezes / crashes
/// on device — that matched “freeze right after START” (uiConfirm + waveStart).
final class GameAudio {
    /// UserDefaults keys (shared with the Options panel).
    enum Keys {
        static let muted = "jj.muted"
        static let musicVolume = "jj.musicVolume"
        static let sfxVolume = "jj.sfxVolume"
    }

    private var engine: AVAudioEngine?
    private var mainMixer: AVAudioMixerNode?
    private var muted = UserDefaults.standard.bool(forKey: Keys.muted)
    /// Bumped on every mute change so a delayed "mute after click" cannot land on a newer state.
    private var muteGeneration = 0
    private var started = false
    /// Cap concurrent one-shot nodes so combat spam cannot pin the audio graph.
    private var livePlayers = 0
    private let maxLivePlayers = 12
    private let lock = NSLock()
    /// Looping title/menu BGM node — attach/play/detach main-thread only.
    private var musicPlayer: AVAudioPlayerNode?
    private var musicBuffer: AVAudioPCMBuffer?
    private var musicFormat: AVAudioFormat?
    /// Base theme level; user MUSIC gain (0…1) multiplies it.
    private let menuThemeVolume: Float = 0.58
    private var menuThemeWanted = false
    /// Menu theme fade-out length when combat starts (spec: ~250ms).
    private let menuThemeFade: TimeInterval = 0.25
    /// True while session activation is in flight (async — must not re-enter).
    private var activating = false
    /// User gains from Options (0…1). Persisted. Mixer master stays 0.7 / 0 for mute.
    private(set) var musicVolume: Float = GameAudio.loadGain(Keys.musicVolume)
    private(set) var sfxVolume: Float = GameAudio.loadGain(Keys.sfxVolume)

    var isMuted: Bool { muted }

    /// Posted (main thread) whenever SOUND or MUSIC changes, so AVPlayer-backed audio that lives
    /// outside this engine (the main-menu loop's soundtrack) can follow the same settings.
    static let gainDidChange = Notification.Name("jj.audio.gainDidChange")
    /// Base level for the main-menu loop's embedded soundtrack; MUSIC (0…1) multiplies it.
    private let menuLoopVolume: Float = 0.9
    /// Volume for the `menu-select-loop.mp4` audio track: 0 while muted, else MUSIC-scaled.
    var menuLoopGain: Float { muted ? 0 : menuLoopVolume * musicVolume }

    private func notifyGainChanged() {
        let post = { NotificationCenter.default.post(name: GameAudio.gainDidChange, object: nil) }
        if Thread.isMainThread { post() } else { DispatchQueue.main.async(execute: post) }
    }

    private static func loadGain(_ key: String) -> Float {
        guard UserDefaults.standard.object(forKey: key) != nil else { return 1 }
        return max(0, min(1, UserDefaults.standard.float(forKey: key)))
    }

    private var themeGain: Float { muted ? 0 : menuThemeVolume * musicVolume }

    func unlock() {
        // Engine attach/start is main-thread only; session I/O is not.
        if Thread.isMainThread {
            beginUnlock()
        } else {
            DispatchQueue.main.async { [weak self] in self?.beginUnlock() }
        }
    }

    private func beginUnlock() {
        guard !started, !activating else { return }
        activating = true
        // sharedInstance / setCategory / setActive can stall for hundreds of ms
        // (AVAudioSession_iOS hang detector). Never run them on the main thread.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.configureAndActivateSession()
        }
    }

    /// Session configuration + activation. Must not run on the main thread.
    /// Apple's hang detector flags `setActive` / `setCategory` on main; the
    /// async `activate(options:)` API is for main-thread callers. We never call
    /// from main, so the synchronous APIs are safe here.
    private func configureAndActivateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            finishActivation(nil)
        } catch {
            finishActivation(error)
        }
    }

    private func finishActivation(_ error: Error?) {
        let work: () -> Void = { [weak self] in
            guard let self else { return }
            if let error {
                self.activating = false
                print("[JJ] audio unlock failed: \(error.localizedDescription)")
                return
            }
            self.startEngineOnMain()
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private func startEngineOnMain() {
        assert(Thread.isMainThread)
        defer { activating = false }
        guard !started else { return }
        do {
            let eng = AVAudioEngine()
            self.engine = eng
            self.mainMixer = eng.mainMixerNode
            // Touch the graph so the output format is valid before first buffer.
            _ = eng.mainMixerNode
            eng.prepare()
            try eng.start()
            self.started = true
            self.mainMixer?.outputVolume = self.muted ? 0 : 0.7
            if menuThemeWanted {
                playMenuThemeOnMain()
            }
        } catch {
            // Audio optional — never crash the game loop for SFX.
            print("[JJ] audio engine start failed: \(error.localizedDescription)")
        }
    }

    /// Programmatic mute — immediate and silent. Persists `jj.muted`.
    func setMuted(_ m: Bool) {
        muted = m
        muteGeneration += 1
        UserDefaults.standard.set(m, forKey: Keys.muted)
        let apply: () -> Void = { [weak self] in self?.applyMixerGain() }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
        notifyGainChanged()
    }

    /// Mute chip / Options SOUND toggle. Order matters (spec §2):
    /// - turning sound OFF: play `uiToggle` first, then mute — the last click must be audible.
    /// - turning sound ON: unmute first, then play `uiToggle` — the first click must be audible.
    /// Returns the new muted state. Main thread only (UI caller).
    @discardableResult
    func toggleMute() -> Bool {
        if muted {
            setMuted(false)
            uiToggle(on: true)
        } else {
            // Flag now (UI shows OFF, other SFX suppressed); the toggle click bypasses the flag and
            // the mixer stays up until it has played, then drops to zero.
            muted = true
            muteGeneration += 1
            let gen = muteGeneration
            UserDefaults.standard.set(true, forKey: Keys.muted)
            uiToggle(on: false)
            // The menu loop's soundtrack is not on this mixer — drop it right away.
            notifyGainChanged()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
                guard let self, self.muted, self.muteGeneration == gen else { return }
                self.applyMixerGain()
            }
        }
        return muted
    }

    /// Options MUSIC detent (0…1). Live on the theme node; persisted.
    func setMusicVolume(_ v: Float) {
        musicVolume = max(0, min(1, v))
        UserDefaults.standard.set(musicVolume, forKey: Keys.musicVolume)
        let apply: () -> Void = { [weak self] in
            guard let self else { return }
            self.musicPlayer?.volume = self.themeGain
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
        notifyGainChanged()
    }

    /// Options SFX detent (0…1). Applied per one-shot node at schedule time; persisted.
    func setSfxVolume(_ v: Float) {
        sfxVolume = max(0, min(1, v))
        UserDefaults.standard.set(sfxVolume, forKey: Keys.sfxVolume)
    }

    private func applyMixerGain() {
        assert(Thread.isMainThread)
        mainMixer?.outputVolume = muted ? 0 : 0.7
        musicPlayer?.volume = themeGain
    }

    // MARK: - TDM theme (tdm-8bit.mp3) — reserved for Credits

    /// TDM used to loop under title → charSelect. The main menu now carries its own soundtrack
    /// (the audio track inside `menu-select-loop.mp4`, driven by `CharSelectLoopStackView`), so
    /// nothing calls this on the menu routes any more. Kept intact for the Credits screen.
    /// Main-thread attach/play only; no-ops while already looping.
    func playMenuTheme() {
        let work: () -> Void = { [weak self] in
            self?.playMenuThemeOnMain()
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    /// Stop TDM (if it is looping). Main-thread stop/detach only.
    /// Default is a short fade; pass `immediate: true` from background handlers.
    func stopMenuTheme(immediate: Bool = false) {
        let work: () -> Void = { [weak self] in
            self?.stopMenuThemeOnMain(fade: immediate ? 0 : (self?.menuThemeFade ?? 0))
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private func playMenuThemeOnMain() {
        assert(Thread.isMainThread)
        menuThemeWanted = true
        if !started { beginUnlock() }
        guard started, let engine else { return }
        if musicBuffer == nil {
            guard let url = Bundle.main.url(forResource: "tdm-8bit", withExtension: "mp3") else {
                print("[JJ] menu theme missing: tdm-8bit.mp3 not in bundle")
                return
            }
            do {
                let file = try AVAudioFile(forReading: url)
                let format = file.processingFormat
                let frames = AVAudioFrameCount(file.length)
                guard frames > 0,
                      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
                try file.read(into: buffer)
                musicBuffer = buffer
                musicFormat = format
            } catch {
                print("[JJ] menu theme load failed: \(error.localizedDescription)")
                return
            }
        }
        guard let buffer = musicBuffer, let format = musicFormat else { return }
        // Already looping (title ↔ menu ↔ select) — never restart, just refresh gain.
        if let existing = musicPlayer, engine.attachedNodes.contains(existing), existing.isPlaying {
            existing.volume = themeGain
            return
        }
        // Fresh node — never reuse a detached player.
        if let old = musicPlayer, engine.attachedNodes.contains(old) {
            old.stop()
            engine.detach(old)
        }
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        player.volume = themeGain
        musicPlayer = player
        if !engine.isRunning {
            do { try engine.start() } catch {
                print("[JJ] menu theme engine restart failed: \(error.localizedDescription)")
                return
            }
        }
        player.scheduleBuffer(buffer, at: nil, options: [.loops])
        player.play()
    }

    private func stopMenuThemeOnMain(fade: TimeInterval) {
        assert(Thread.isMainThread)
        menuThemeWanted = false
        guard let engine, let player = musicPlayer else {
            musicPlayer = nil
            return
        }
        // Drop our reference first so a re-entry during the fade builds a fresh node.
        musicPlayer = nil
        guard engine.attachedNodes.contains(player) else { return }
        if fade <= 0 || player.volume <= 0.001 {
            player.stop()
            engine.detach(player)
            return
        }
        // Short main-thread ramp, then stop + detach (still on main).
        let steps = 5
        let startVol = player.volume
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + fade * Double(i) / Double(steps)) { [weak engine] in
                guard let engine else { return }
                if i < steps {
                    player.volume = startVol * Float(steps - i) / Float(steps)
                } else if engine.attachedNodes.contains(player) {
                    player.stop()
                    engine.detach(player)
                }
            }
        }
    }

    // MARK: - SFX API (matches web)

    func punch(player: Bool = true) { whoosh(kind: .punch, vol: player ? 1 : 0.55) }
    func kick(player: Bool = true) { whoosh(kind: .kick, vol: player ? 1 : 0.55) }
    func special(player: Bool = true) {
        whoosh(kind: .special, vol: player ? 1 : 0.55)
        guitarRiff()
    }

    func jump() {
        tone(240, dur: 0.1, type: .square, gain: 0.08, slideTo: 420)
        noise(0.08, gain: 0.12, freq: 2000, highpass: true)
    }

    func land() {
        noise(0.06, gain: 0.14, freq: 350, highpass: false)
        tone(90, dur: 0.05, type: .sine, gain: 0.08, slideTo: 50)
    }

    func gunshot() {
        noise(0.09, gain: 0.4, freq: 900, highpass: false)
        tone(180, dur: 0.08, type: .square, gain: 0.16, slideTo: 40)
        tone(90, dur: 0.12, type: .sine, gain: 0.14, slideTo: 30)
        noise(0.05, gain: 0.2, freq: 2800, highpass: true)
    }

    func hit(_ kind: AttackKind?, combo: Int) {
        let heavy = kind == .kick || kind == .special
        impact(heavy: heavy, combo: combo)
        if kind == .special {
            tone(520 + CGFloat(min(4, combo)) * 40, dur: 0.09, type: .triangle, gain: 0.07, slideTo: 200)
        }
    }

    func hurt() {
        tone(180, dur: 0.12, type: .sawtooth, gain: 0.12, slideTo: 70)
        noise(0.1, gain: 0.18, freq: 700, highpass: false)
    }

    func ko() {
        noise(0.22, gain: 0.35, freq: 200, highpass: false)
        tone(70, dur: 0.25, type: .square, gain: 0.15, slideTo: 30)
    }

    func playerDown() {
        tone(160, dur: 0.35, type: .sawtooth, gain: 0.14, slideTo: 40)
    }

    func gameOver() {
        tone(200, dur: 0.4, type: .square, gain: 0.1, slideTo: 60)
        tone(150, dur: 0.5, type: .triangle, gain: 0.08, slideTo: 40)
    }

    func victory() {
        tone(523, dur: 0.15, type: .square, gain: 0.1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.tone(659, dur: 0.15, type: .square, gain: 0.1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { [weak self] in
            self?.tone(784, dur: 0.3, type: .square, gain: 0.12)
        }
    }

    func waveStart(_ wave: Int) {
        tone(300 + CGFloat(wave) * 40, dur: 0.15, type: .square, gain: 0.08)
    }

    func waveClear() {
        tone(440, dur: 0.12, type: .triangle, gain: 0.1)
        tone(660, dur: 0.18, type: .triangle, gain: 0.1)
    }

    // MARK: - Moveset bank. Same palette (tone / noise, main-scheduled, mute-aware) — one swing
    // and one impact per chain step so jab → cross → hook never sound like the same punch.

    /// Swing whoosh for a move step. Enemies play quieter.
    func swing(_ sfx: MoveSFX, player: Bool = true) {
        let vol: CGFloat = player ? 1 : 0.55
        switch sfx {
        case .jab:
            noise(0.07, gain: 0.20 * vol, freq: 2000, highpass: true)
            tone(240, dur: 0.06, type: .sawtooth, gain: 0.05 * vol, slideTo: 110)
        case .cross:
            noise(0.09, gain: 0.24 * vol, freq: 1600, highpass: true)
            tone(200, dur: 0.08, type: .sawtooth, gain: 0.07 * vol, slideTo: 80)
        case .hook:
            noise(0.12, gain: 0.30 * vol, freq: 1100, highpass: false)
            tone(170, dur: 0.11, type: .sawtooth, gain: 0.09 * vol, slideTo: 60)
        case .kick:
            whoosh(kind: .kick, vol: vol)
        case .roundhouse:
            noise(0.17, gain: 0.32 * vol, freq: 700, highpass: false)
            tone(120, dur: 0.15, type: .sawtooth, gain: 0.10 * vol, slideTo: 45)
            tone(360, dur: 0.12, type: .triangle, gain: 0.04 * vol, slideTo: 140)
        case .airKick:
            noise(0.14, gain: 0.26 * vol, freq: 1300, highpass: true)
            tone(300, dur: 0.14, type: .square, gain: 0.05 * vol, slideTo: 120)
        case .dash:
            noise(0.16, gain: 0.30 * vol, freq: 1500, highpass: true)
            tone(160, dur: 0.16, type: .sawtooth, gain: 0.08 * vol, slideTo: 320)
        case .special:
            whoosh(kind: .special, vol: vol)
        case .gun:
            gunshot()
        }
    }

    /// Impact per move step: jab snaps, cross thumps, hook / roundhouse crunch, air kick cracks,
    /// dash slams. Combo count adds a little weight like before.
    func impact(_ sfx: MoveSFX, combo: Int) {
        let boost = min(1.35, 1 + CGFloat(max(0, combo - 1)) * 0.06)
        switch sfx {
        case .jab:
            noise(0.07, gain: 0.26 * boost, freq: 520, highpass: false)
            tone(150, dur: 0.06, type: .square, gain: 0.10 * boost, slideTo: 60)
        case .cross:
            noise(0.09, gain: 0.30 * boost, freq: 450, highpass: false)
            tone(130, dur: 0.08, type: .square, gain: 0.12 * boost, slideTo: 45)
        case .hook, .roundhouse:
            noise(0.17, gain: 0.44 * boost, freq: 260, highpass: false)
            tone(85, dur: 0.15, type: .square, gain: 0.19 * boost, slideTo: 35)
        case .kick:
            impact(heavy: true, combo: combo)
        case .airKick:
            noise(0.12, gain: 0.36 * boost, freq: 380, highpass: false)
            tone(110, dur: 0.10, type: .square, gain: 0.15 * boost, slideTo: 40)
            noise(0.04, gain: 0.16, freq: 3000, highpass: true)
        case .dash:
            noise(0.18, gain: 0.42 * boost, freq: 300, highpass: false)
            tone(95, dur: 0.16, type: .square, gain: 0.17 * boost, slideTo: 30)
        case .special:
            impact(heavy: true, combo: combo)
            tone(520 + CGFloat(min(4, combo)) * 40, dur: 0.09, type: .triangle, gain: 0.07, slideTo: 200)
        case .gun:
            impact(heavy: true, combo: combo)
        }
    }

    /// Body hitting the pavement after a finisher — delayed so it lands after the strike.
    func knockdown() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            self?.noise(0.2, gain: 0.34, freq: 180, highpass: false)
            self?.tone(60, dur: 0.22, type: .sine, gain: 0.16, slideTo: 28)
        }
    }

    /// Chain finisher sting layered on the impact — the payoff for landing step 3.
    func chainFinisher() {
        tone(330, dur: 0.08, type: .square, gain: 0.06)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.tone(495, dur: 0.12, type: .square, gain: 0.07, slideTo: 440)
        }
    }

    /// 5 / 10 / 15… hit combo: short rising arpeggio, one note longer from 10 up.
    func comboMilestone(_ combo: Int) {
        let base: CGFloat = combo >= 10 ? 523 : 440
        let steps: [CGFloat] = combo >= 10 ? [1, 1.25, 1.5, 2] : [1, 1.25, 1.5]
        for (i, r) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) { [weak self] in
                self?.tone(base * r, dur: 0.09, type: .square, gain: 0.07)
            }
        }
    }

    /// Enemy wind-up tick — the audible cue that a swing is coming. Elites ring lower and longer.
    func telegraph(elite: Bool) {
        tone(elite ? 300 : 420, dur: elite ? 0.12 : 0.07, type: .square,
             gain: elite ? 0.07 : 0.05, slideTo: elite ? 240 : 380)
        if elite { noise(0.06, gain: 0.08, freq: 600, highpass: false) }
    }

    /// Footsteps: soft thud, brighter and harder when sprinting. Capped to one live step so a
    /// sprint never eats the 12 voice slots.
    private var footstepBusyUntil: CFAbsoluteTime = 0
    func footstep(run: Bool) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now >= footstepBusyUntil else { return }
        footstepBusyUntil = now + (run ? 0.11 : 0.14)
        noise(run ? 0.05 : 0.06, gain: run ? 0.10 : 0.07, freq: run ? 420 : 300, highpass: false)
        tone(run ? 95 : 80, dur: 0.035, type: .sine, gain: run ? 0.05 : 0.035, slideTo: 45)
    }

    /// New enemy walks in — low blip so an off-screen spawn still registers. Elites growl.
    func enemySpawn(elite: Bool) {
        tone(elite ? 110 : 150, dur: elite ? 0.16 : 0.09, type: .square, gain: 0.06, slideTo: elite ? 70 : 120)
        if elite { tone(165, dur: 0.16, type: .sawtooth, gain: 0.03, slideTo: 105) }
    }

    /// Stage title / loading-screen sting.
    func stageLoad() {
        tone(196, dur: 0.18, type: .square, gain: 0.08)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
            self?.tone(294, dur: 0.22, type: .square, gain: 0.08)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.tone(392, dur: 0.34, type: .triangle, gain: 0.08, slideTo: 380)
        }
    }

    /// Round that hits nothing — ricochet whine off into the night.
    func bulletMiss() {
        tone(1400, dur: 0.16, type: .sine, gain: 0.05, slideTo: 500)
        noise(0.05, gain: 0.06, freq: 2600, highpass: true)
    }

    /// Per-fighter riff: JJ = punk guitar, Andrew = 8-bit glitch, Han = anime chime run.
    func riff(fighter: String) {
        whoosh(kind: .special, vol: 1)
        switch fighter.lowercased() {
        case "andrew": glitchRiff()
        case "han": chimeRiff()
        default: guitarRiff()
        }
    }

    /// Andrew: chiptune arpeggio with a detuned "bit-crush" double and a data-dump slide.
    private func glitchRiff() {
        let notes: [(CGFloat, Double, CGFloat)] = [
            (131, 0, 0.08), (196, 0.08, 0.08), (262, 0.16, 0.08), (392, 0.24, 0.10),
            (330, 0.36, 0.08), (494, 0.44, 0.08), (659, 0.52, 0.18)
        ]
        for (f, delay, hold) in notes {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.tone(f, dur: hold, type: .square, gain: 0.10)
                self?.tone(f * 1.01, dur: hold, type: .square, gain: 0.04)
                self?.noise(0.02, gain: 0.05, freq: 4000, highpass: true)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.tone(1046, dur: 0.22, type: .square, gain: 0.07, slideTo: 60)
        }
    }

    /// Han: bright pentatonic run with an octave shimmer, then a held sparkle.
    private func chimeRiff() {
        let notes: [(CGFloat, Double, CGFloat)] = [
            (587, 0, 0.10), (659, 0.09, 0.10), (784, 0.18, 0.10), (880, 0.27, 0.10),
            (1046, 0.36, 0.12), (1318, 0.48, 0.16)
        ]
        for (f, delay, hold) in notes {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.tone(f, dur: hold, type: .triangle, gain: 0.09)
                self?.tone(f * 2, dur: hold * 0.7, type: .sine, gain: 0.04)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.66) { [weak self] in
            self?.tone(1568, dur: 0.3, type: .sine, gain: 0.06, slideTo: 1760)
            self?.noise(0.2, gain: 0.05, freq: 5000, highpass: true)
        }
    }

    // MARK: - UI bank (menu chrome). Procedural, main-scheduled, respects mute + livePlayers.
    // Ported from the web palette — same language, not a new one.

    /// Every live row / chip / card / toggle press-down.
    func uiTap() {
        tone(640, dur: 0.045, type: .square, gain: 0.06)
    }

    /// Focus change only (new fighter card id) — softer / higher than tap.
    func uiHover() {
        tone(880, dur: 0.03, type: .sine, gain: 0.04)
    }

    /// Primary success: STORY, FIGHT / START BRAWL, RETRY, PLAY AGAIN, apply options.
    /// Two staggered squares (520 → 780) so it reads as a "door", not a tick.
    func uiConfirm() {
        tone(520, dur: 0.08, type: .square, gain: 0.08)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            self?.tone(780, dur: 0.12, type: .square, gain: 0.08)
        }
    }

    /// Alias — menu buttons that enter combat. Never fires waveStart (that lives in beginWave).
    func uiStart() { uiConfirm() }

    /// BACK, swipe-dismiss, Escape on menu.
    func uiBack() {
        tone(400, dur: 0.09, type: .triangle, gain: 0.06, slideTo: 280)
    }

    /// Disabled row, locked fighter — short dissonant blip + noise.
    func uiDeny() {
        tone(180, dur: 0.07, type: .square, gain: 0.07, slideTo: 150)
        tone(191, dur: 0.07, type: .sawtooth, gain: 0.035, slideTo: 160)
        noise(0.05, gain: 0.07, freq: 1200, highpass: true)
    }

    /// Two-note toggle: up (280→400) when enabling sound, down (400→280) when muting.
    /// The "down" pair bypasses the mute flag — `toggleMute` has already flagged `muted` but holds
    /// the mixer at 0.7 for ~220ms so this last click is audible.
    func uiToggle(on: Bool) {
        let a: CGFloat = on ? 280 : 400
        let b: CGFloat = on ? 400 : 280
        tone(a, dur: 0.06, type: .triangle, gain: 0.06, bypassMute: !on)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { [weak self] in
            self?.tone(b, dur: 0.08, type: .triangle, gain: 0.06, bypassMute: !on)
        }
    }

    func pause() { tone(200, dur: 0.08, type: .sine, gain: 0.06) }
    func resume() { tone(320, dur: 0.08, type: .sine, gain: 0.06) }

    func smokeBreak() {
        noise(0.05, gain: 0.08, freq: 3200, highpass: true)
        tone(180, dur: 0.08, type: .triangle, gain: 0.04, slideTo: 90)
    }

    func exhale() {
        noise(0.28, gain: 0.07, freq: 500, highpass: false)
    }

    func guitarRiff() {
        let roots: [(CGFloat, Double, CGFloat)] = [
            (82, 0, 0.14), (98, 0.12, 0.12), (110, 0.23, 0.14),
            (82, 0.36, 0.2), (147, 0.52, 0.26)
        ]
        for (root, delay, hold) in roots {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.tone(root, dur: hold, type: .sawtooth, gain: 0.12)
                self?.tone(root * 1.5, dur: hold * 0.9, type: .square, gain: 0.06)
                self?.noise(hold * 0.55, gain: 0.07, freq: 900, highpass: false)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.68) { [weak self] in
            self?.tone(880, dur: 0.28, type: .sawtooth, gain: 0.06, slideTo: 1200)
        }
    }

    // MARK: - Low level

    private enum Wave: Int {
        case sine = 0, square, sawtooth, triangle
    }

    private enum WhooshKind { case punch, kick, special }

    private func whoosh(kind: WhooshKind, vol: CGFloat) {
        switch kind {
        case .punch:
            noise(0.08, gain: 0.22 * vol, freq: 1800, highpass: true)
            tone(220, dur: 0.07, type: .sawtooth, gain: 0.06 * vol, slideTo: 90)
        case .kick:
            noise(0.12, gain: 0.28 * vol, freq: 900, highpass: false)
            tone(140, dur: 0.1, type: .sawtooth, gain: 0.08 * vol, slideTo: 55)
        case .special:
            noise(0.18, gain: 0.32 * vol, freq: 1400, highpass: true)
            tone(320, dur: 0.2, type: .square, gain: 0.1 * vol, slideTo: 80)
        }
    }

    private func impact(heavy: Bool, combo: Int) {
        let boost = min(1.35, 1 + CGFloat(combo - 1) * 0.06)
        noise(heavy ? 0.16 : 0.09, gain: (heavy ? 0.42 : 0.3) * boost, freq: heavy ? 280 : 450, highpass: false)
        tone(heavy ? 90 : 130, dur: heavy ? 0.14 : 0.08, type: .square, gain: (heavy ? 0.18 : 0.12) * boost, slideTo: 40)
    }

    private func tone(_ freq: CGFloat, dur: CGFloat, type: Wave, gain: CGFloat, slideTo: CGFloat? = nil, bypassMute: Bool = false) {
        let work: () -> Void = { [weak self] in
            self?.playTone(freq, dur: dur, type: type, gain: gain, slideTo: slideTo, bypassMute: bypassMute)
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private func playTone(_ freq: CGFloat, dur: CGFloat, type: Wave, gain: CGFloat, slideTo: CGFloat?, bypassMute: Bool = false) {
        guard started, bypassMute || !muted, let engine else { return }
        guard reservePlayerSlot() else { return }

        var sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        if sampleRate < 1 { sampleRate = 44_100 }
        let count = Int(sampleRate * Double(dur) + sampleRate * 0.05)
        guard count > 0 else { releasePlayerSlot(); return }
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(count)) else {
            releasePlayerSlot()
            return
        }
        buffer.frameLength = AVAudioFrameCount(count)
        guard let data = buffer.floatChannelData?[0] else { releasePlayerSlot(); return }

        var phase: Double = 0
        let twoPi = 2.0 * Double.pi
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let env: Float
            let attack = 0.005
            let decay = Double(dur)
            if t < attack {
                env = Float(t / attack)
            } else if t > decay {
                env = max(0, Float(1 - (t - decay) / 0.05))
            } else {
                env = Float(1 - (t - attack) / max(0.001, decay - attack)) * 0.9 + 0.1
            }
            let f0 = Double(freq)
            let f1 = Double(slideTo ?? freq)
            let f = f0 + (f1 - f0) * min(1, t / Double(dur))
            phase += twoPi * f / sampleRate
            let sample: Double
            switch type {
            case .sine: sample = sin(phase)
            case .square: sample = sin(phase) >= 0 ? 1 : -1
            case .sawtooth: sample = 2 * (phase / twoPi - floor(phase / twoPi + 0.5))
            case .triangle: sample = abs(2 * (phase / twoPi - floor(phase / twoPi + 0.5))) * 2 - 1
            }
            data[i] = Float(sample) * env * Float(gain) * 0.35
        }
        schedule(buffer: buffer, format: fmt, engine: engine)
    }

    private func noise(_ dur: CGFloat, gain: CGFloat, freq: CGFloat, highpass: Bool) {
        let work: () -> Void = { [weak self] in
            self?.playNoise(dur, gain: gain, freq: freq, highpass: highpass)
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private func playNoise(_ dur: CGFloat, gain: CGFloat, freq: CGFloat, highpass: Bool) {
        guard started, !muted, let engine else { return }
        guard reservePlayerSlot() else { return }

        var sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        if sampleRate < 1 { sampleRate = 44_100 }
        let count = Int(sampleRate * Double(dur) + sampleRate * 0.02)
        guard count > 0 else { releasePlayerSlot(); return }
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(count)) else {
            releasePlayerSlot()
            return
        }
        buffer.frameLength = AVAudioFrameCount(count)
        guard let data = buffer.floatChannelData?[0] else { releasePlayerSlot(); return }
        var last: Float = 0
        // Simple one-pole; highpass flag tilts the mix slightly
        let tilt: Float = highpass ? 0.55 : 0.02
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let env = Float(max(0, 1 - t / Double(dur)))
            let w = Float.random(in: -1...1)
            last = (last + tilt * w) / (1 + tilt)
            let mix = highpass ? (w * 0.65 + last * 0.35) : (last * 3)
            data[i] = mix * env * Float(gain) * 0.4
        }
        schedule(buffer: buffer, format: fmt, engine: engine)
    }

    private func schedule(buffer: AVAudioPCMBuffer, format: AVAudioFormat, engine: AVAudioEngine) {
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        // Options SFX gain — per node so the theme (music gain) is untouched.
        player.volume = sfxVolume
        // Completion fires on an audio thread — NEVER detach there.
        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self, weak engine, weak player] in
            DispatchQueue.main.async {
                if let player, let engine, engine.attachedNodes.contains(player) {
                    player.stop()
                    engine.detach(player)
                }
                self?.releasePlayerSlot()
            }
        }
        // Engine can stop if interrupted (call, background) — restart quietly.
        if !engine.isRunning {
            do { try engine.start() } catch { releasePlayerSlot(); return }
        }
        player.play()
    }

    private func reservePlayerSlot() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard livePlayers < maxLivePlayers else { return false }
        livePlayers += 1
        return true
    }

    private func releasePlayerSlot() {
        lock.lock()
        livePlayers = max(0, livePlayers - 1)
        lock.unlock()
    }
}
