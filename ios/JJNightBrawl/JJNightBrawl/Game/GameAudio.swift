import AVFoundation
import UIKit

/// Lightweight SFX helper. Full sample bank lives on the local Mac project.
/// Freeze mitigation: NEVER attach / play / detach AVAudioPlayerNode off the main thread.
final class GameAudio {
    private let engine = AVAudioEngine()
    private let maxOneShots = 6
    private var oneShotNodes: [AVAudioPlayerNode] = []
    private var started = false

    func prepare() {
        guard !started else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            // Safe sample-rate fallback — some sims reject odd hardware rates.
            let _ = engine.mainMixerNode
            try engine.start()
            started = true
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
        guard started else { return }
        pruneOneShotsOnMain()
        // Placeholder bank: no bundled wavs in this partial sync.
        // When samples land, attach → schedule buffer → play here on main, and hop
        // completion handlers back to main before stop/detach (never detach on the
        // audio render thread).
        _ = name
    }

    /// Cap concurrent one-shot nodes; stop/detach only on main.
    private func pruneOneShotsOnMain() {
        assert(Thread.isMainThread)
        while oneShotNodes.count > maxOneShots {
            let node = oneShotNodes.removeFirst()
            node.stop()
            // NEVER detach from an audio render thread callback — callers hop to main first.
            engine.detach(node)
        }
    }
}
