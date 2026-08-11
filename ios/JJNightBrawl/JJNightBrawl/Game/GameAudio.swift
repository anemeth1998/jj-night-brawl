import AVFoundation
import UIKit

/// Lightweight SFX helper. Full sample bank lives on the local Mac project.
/// Freeze mitigation: NEVER detach AVAudioPlayerNode off the main thread.
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
        // Placeholder: no bundled wavs in this partial sync. Keep API hot for Mac merge.
        // When samples land, schedule buffers on main and detach only via main.async.
        guard started else { return }
        pruneOneShotsOnMain()
    }

    private func pruneOneShotsOnMain() {
        // Cap concurrent one-shot nodes; detach only on main.
        if oneShotNodes.count > maxOneShots {
            let extra = oneShotNodes.prefix(oneShotNodes.count - maxOneShots)
            for node in extra {
                // NEVER detach from an audio render thread callback — hop to main.
                DispatchQueue.main.async { [weak self] in
                    self?.engine.detach(node)
                }
            }
            oneShotNodes.removeFirst(oneShotNodes.count - maxOneShots)
        }
    }
}
