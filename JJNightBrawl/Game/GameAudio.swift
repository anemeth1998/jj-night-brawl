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

    // MARK: - Menu theme (tdm-8bit.mp3) — title → charSelect only

    /// Start / keep looping TDM on title + charSelect. Main-thread attach/play only.
    func playMenuTheme() {
        let work: () -> Void = { [weak self] in
            self?.playMenuThemeOnMain()
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    /// Stop TDM when leaving menu (Act I / gameover / etc). Main-thread stop/detach only.
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
