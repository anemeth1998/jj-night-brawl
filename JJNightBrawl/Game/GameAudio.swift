import Foundation
import AVFoundation
import CoreGraphics

/// Procedural SFX via AVAudioEngine (no external sound files).
///
/// Important: AVAudioEngine attach/detach **must** stay on the main thread.
/// Detaching from a buffer completion callback (audio thread) freezes / crashes
/// on device — that matched “freeze right after START” (uiConfirm + waveStart).
final class GameAudio {
    private var engine: AVAudioEngine?
    private var mainMixer: AVAudioMixerNode?
    private var muted = false
    private var started = false
    /// Cap concurrent one-shot nodes so combat spam cannot pin the audio graph.
    private var livePlayers = 0
    private let maxLivePlayers = 12
    private let lock = NSLock()

    func unlock() {
        // Always hop to main — AVAudioSession / engine start is not thread-safe here.
        if Thread.isMainThread {
            unlockOnMain()
        } else {
            DispatchQueue.main.async { [weak self] in self?.unlockOnMain() }
        }
    }

    private func unlockOnMain() {
        guard !started else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let eng = AVAudioEngine()
            engine = eng
            mainMixer = eng.mainMixerNode
            // Touch the graph so the output format is valid before first buffer.
            _ = eng.mainMixerNode
            eng.prepare()
            try eng.start()
            started = true
            mainMixer?.outputVolume = muted ? 0 : 0.7
        } catch {
            // Audio optional — never crash the game loop for SFX.
            print("[JJ] audio unlock failed: \(error.localizedDescription)")
        }
    }

    func setMuted(_ m: Bool) {
        muted = m
        let apply: () -> Void = { [weak self] in
            self?.mainMixer?.outputVolume = m ? 0 : 0.7
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    func toggleMute() -> Bool {
        setMuted(!muted)
        return muted
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

    func uiConfirm() {
        tone(520, dur: 0.08, type: .square, gain: 0.08)
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

    private func tone(_ freq: CGFloat, dur: CGFloat, type: Wave, gain: CGFloat, slideTo: CGFloat? = nil) {
        let work: () -> Void = { [weak self] in
            self?.playTone(freq, dur: dur, type: type, gain: gain, slideTo: slideTo)
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private func playTone(_ freq: CGFloat, dur: CGFloat, type: Wave, gain: CGFloat, slideTo: CGFloat?) {
        guard started, !muted, let engine else { return }
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
