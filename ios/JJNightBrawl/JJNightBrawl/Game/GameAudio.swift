import AVFoundation
import UIKit

/// Procedural one-shot SFX via synthesized PCM buffers (no bundled samples).
/// Freeze mitigation: NEVER attach / schedule / play / stop / detach AVAudioPlayerNode off main.
final class GameAudio {
    private let engine = AVAudioEngine()
    private let maxOneShots = 6
    private var oneShotNodes: [AVAudioPlayerNode] = []
    private var started = false
    private var pcmFormat: AVAudioFormat?
    private var bufferCache: [String: AVAudioPCMBuffer] = [:]

    func prepare() {
        guard !started else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            let _ = engine.mainMixerNode
            try engine.start()
            let mixer = engine.mainMixerNode.outputFormat(forBus: 0)
            let rate = mixer.sampleRate > 0 ? mixer.sampleRate : 44_100
            pcmFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: rate,
                channels: 1,
                interleaved: false
            )
            started = pcmFormat != nil
        } catch {
            started = false
        }
    }

    func play(_ name: String) {
        // Attach / schedule / play / detach must stay on main (AVAudioEngine rule).
        if Thread.isMainThread {
            playOnMain(name)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.playOnMain(name)
            }
        }
    }

    private func playOnMain(_ name: String) {
        assert(Thread.isMainThread)
        guard started, let format = pcmFormat else { return }
        pruneOneShotsOnMain()
        guard let buffer = cachedBuffer(named: name, format: format) else { return }

        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        oneShotNodes.append(node)

        node.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self, weak node] _ in
            // Completion may fire off-main — hop before stop/detach.
            DispatchQueue.main.async {
                guard let self, let node else { return }
                self.retireNodeOnMain(node)
            }
        }
        node.play()
    }

    /// Cap concurrent one-shot nodes; stop/detach only on main.
    private func pruneOneShotsOnMain() {
        assert(Thread.isMainThread)
        while oneShotNodes.count >= maxOneShots {
            let node = oneShotNodes.removeFirst()
            node.stop()
            // NEVER detach from an audio render thread callback — callers hop to main first.
            engine.detach(node)
        }
    }

    private func retireNodeOnMain(_ node: AVAudioPlayerNode) {
        assert(Thread.isMainThread)
        node.stop()
        if let idx = oneShotNodes.firstIndex(where: { $0 === node }) {
            oneShotNodes.remove(at: idx)
        }
        engine.detach(node)
    }

    private func cachedBuffer(named name: String, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if let hit = bufferCache[name] { return hit }
        guard let built = synthesize(name: name, format: format) else { return nil }
        bufferCache[name] = built
        return built
    }

    // MARK: - Synthesis

    /// Approximate peak gains (linear) from suggested dB targets.
    private enum Peak {
        static let punch: Float = 0.40      // ~-8 dB
        static let kick: Float = 0.45       // ~-7 dB
        static let special: Float = 0.25    // ~-12 dB — ducked so it won't clip
        static let gun: Float = 0.355       // ~-9 dB
        static let hurt: Float = 0.32       // ~-10 dB
        static let ko: Float = 0.50         // ~-6 dB
        static let waveClear: Float = 0.28  // ~-11 dB
        static let victory: Float = 0.32    // ~-10 dB
        static let smoke: Float = 0.20      // ~-14 dB
        static let uiConfirm: Float = 0.16  // ~-16 dB
    }

    private func synthesize(name: String, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sr = format.sampleRate
        switch name {
        case "punch":
            return makeBuffer(format: format, seconds: 0.09) { i, _ in
                let t = Double(i) / sr
                let env = Float(exp(-t * 42))
                let thump = sin(2 * .pi * lerp(140, 70, t / 0.09) * t) * env
                let click = (i < Int(sr * 0.004) ? Float.random(in: -1...1) : 0) * 0.55 * Float(exp(-t * 280))
                return softLimit((thump * 0.85 + click) * Peak.punch)
            }
        case "kick":
            return makeBuffer(format: format, seconds: 0.14) { i, _ in
                let t = Double(i) / sr
                let env = Float(exp(-t * 28))
                let thud = sin(2 * .pi * lerp(90, 42, min(1, t / 0.1)) * t) * env
                let whoosh = noise() * Float(exp(-t * 18)) * Float(t < 0.06 ? 1 : 0.35)
                return softLimit((thud * 0.9 + whoosh * 0.28) * Peak.kick)
            }
        case "special":
            // Bright short stab / riff hit — intentionally quieter than punch/kick.
            return makeBuffer(format: format, seconds: 0.16) { i, _ in
                let t = Double(i) / sr
                let env = Float(exp(-t * 22)) * attack(t, 0.004)
                let f1 = 523.25 // C5
                let f2 = 659.25 // E5
                let f3 = 783.99 // G5
                let stab =
                    sin(2 * .pi * f1 * t) * 0.45 +
                    sin(2 * .pi * f2 * t) * 0.35 +
                    sin(2 * .pi * f3 * t) * 0.25 +
                    sin(2 * .pi * f1 * 2 * t) * 0.12
                let grit = noise() * 0.08 * Float(exp(-t * 60))
                return softLimit((stab * env + grit) * Peak.special)
            }
        case "gun":
            return makeBuffer(format: format, seconds: 0.12) { i, _ in
                let t = Double(i) / sr
                let click = (i < Int(sr * 0.003) ? Float.random(in: -1...1) : 0) * Float(exp(-t * 400))
                let body = sin(2 * .pi * lerp(900, 180, min(1, t / 0.05)) * t) * Float(exp(-t * 35))
                let tail = noise() * Float(exp(-t * 22)) * 0.55
                return softLimit((click * 0.9 + body * 0.45 + tail * 0.4) * Peak.gun)
            }
        case "hurt":
            return makeBuffer(format: format, seconds: 0.14) { i, _ in
                let t = Double(i) / sr
                let env = Float(exp(-t * 20))
                let body = sin(2 * .pi * lerp(220, 90, min(1, t / 0.12)) * t) * env
                let dull = noise() * Float(exp(-t * 30)) * 0.35
                return softLimit((body * 0.8 + dull) * Peak.hurt)
            }
        case "ko":
            return makeBuffer(format: format, seconds: 0.32) { i, _ in
                let t = Double(i) / sr
                let impact = sin(2 * .pi * lerp(160, 55, min(1, t / 0.18)) * t) * Float(exp(-t * 10))
                let fall = sin(2 * .pi * lerp(70, 28, min(1, t / 0.3)) * t) * Float(exp(-t * 6)) * 0.7
                let crunch = noise() * Float(exp(-t * 25)) * 0.35
                return softLimit((impact * 0.75 + fall + crunch) * Peak.ko)
            }
        case "waveClear":
            return makeArpeggio(
                format: format,
                freqs: [392.00, 493.88, 587.33, 783.99], // G4 B4 D5 G5
                noteLen: 0.07,
                gap: 0.015,
                peak: Peak.waveClear
            )
        case "victory":
            return makeArpeggio(
                format: format,
                freqs: [523.25, 659.25, 783.99, 1046.50, 783.99, 1046.50], // C5 E5 G5 C6 G5 C6
                noteLen: 0.09,
                gap: 0.02,
                peak: Peak.victory,
                brighter: true
            )
        case "smoke":
            return makeBuffer(format: format, seconds: 0.28) { i, _ in
                let t = Double(i) / sr
                let env = attack(t, 0.03) * Float(exp(-t * 7))
                // Soft band-ish noise puff (no true filter — shape with slow AM).
                let air = noise() * env * (0.55 + 0.45 * sin(2 * .pi * 18 * t))
                return softLimit(air * Peak.smoke)
            }
        case "uiConfirm":
            return makeBuffer(format: format, seconds: 0.08) { i, _ in
                let t = Double(i) / sr
                let env = attack(t, 0.004) * Float(exp(-t * 28))
                let blip =
                    sin(2 * .pi * 880 * t) * 0.7 +
                    sin(2 * .pi * 1320 * t) * 0.3
                return softLimit(blip * env * Peak.uiConfirm)
            }
        default:
            return nil
        }
    }

    private func makeArpeggio(
        format: AVAudioFormat,
        freqs: [Double],
        noteLen: Double,
        gap: Double,
        peak: Float,
        brighter: Bool = false
    ) -> AVAudioPCMBuffer? {
        let sr = format.sampleRate
        let total = Double(freqs.count) * (noteLen + gap) + 0.04
        return makeBuffer(format: format, seconds: total) { i, _ in
            let t = Double(i) / sr
            var sample: Float = 0
            var cursor = 0.0
            for (idx, f) in freqs.enumerated() {
                let start = cursor
                let end = start + noteLen
                if t >= start && t < end {
                    let local = t - start
                    let env = attack(local, 0.006) * Float(exp(-local * 14))
                    var tone = sin(2 * .pi * f * local)
                    if brighter {
                        tone += sin(2 * .pi * f * 2 * local) * 0.25
                    }
                    // Slight rise across the arpeggio for a stinger feel.
                    let stepGain = 0.85 + 0.15 * Float(idx) / Float(max(1, freqs.count - 1))
                    sample += Float(tone) * env * stepGain
                }
                cursor = end + gap
            }
            return softLimit(sample * peak)
        }
    }

    private func makeBuffer(
        format: AVAudioFormat,
        seconds: Double,
        fill: (_ i: Int, _ n: Int) -> Float
    ) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(max(1, Int((format.sampleRate * seconds).rounded(.up))))
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buf.frameLength = frames
        guard let ch = buf.floatChannelData?[0] else { return nil }
        let n = Int(frames)
        for i in 0..<n {
            ch[i] = fill(i, n)
        }
        return buf
    }

    private func softLimit(_ x: Float) -> Float {
        // Gentle tanh limiter keeps stacked one-shots from hard-clipping.
        tanh(x * 1.15) * 0.92
    }

    private func attack(_ t: Double, _ a: Double) -> Float {
        guard a > 0 else { return 1 }
        return Float(min(1, t / a))
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * max(0, min(1, t))
    }

    private func noise() -> Float {
        Float.random(in: -1...1)
    }
}
