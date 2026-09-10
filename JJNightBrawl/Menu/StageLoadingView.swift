import SwiftUI
import AVFoundation
import UIKit

/// Between-stage hold: loops the bundled Running Animation clip while the next stage warms.
struct StageLoadingView: View {
    var title: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RunningLoopPlayer()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            VStack(spacing: 10) {
                Spacer()
                Text("NEXT STREET")
                    .font(MenuTheme.display(12, weight: .bold))
                    .tracking(2.4)
                    .foregroundColor(MenuTheme.gold)
                Text(title)
                    .font(MenuTheme.display(28, weight: .black))
                    .tracking(1.2)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text("LOADING")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 36)
            }
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading \(title)")
    }
}

/// Muted looping AVPlayer for `Running Animation .MP4`. Missing URL → black plate, never a crash.
private final class RunningLoopPlayerView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var queue: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isUserInteractionEnabled = false
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
        NotificationCenter.default.addObserver(
            self, selector: #selector(appBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
        start()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stop()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }

    private func start() {
        guard queue == nil else {
            queue?.play()
            return
        }
        guard let url = Self.runningURL() else {
            print("[JJ] Running Animation .MP4 missing — loading plate only")
            return
        }
        let item = AVPlayerItem(url: url)
        let q = AVQueuePlayer()
        q.isMuted = true
        looper = AVPlayerLooper(player: q, templateItem: item)
        queue = q
        playerLayer.player = q
        q.play()
    }

    private func stop() {
        queue?.pause()
        playerLayer.player = nil
        looper = nil
        queue = nil
    }

    @objc private func appBackground() { queue?.pause() }
    @objc private func appForeground() { queue?.play() }

    private static func runningURL() -> URL? {
        let names = ["Running Animation ", "Running Animation", "RunningAnimation"]
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: "MP4") { return url }
            if let url = Bundle.main.url(forResource: name, withExtension: "mp4") { return url }
            if let url = Bundle.main.url(forResource: name, withExtension: "MP4", subdirectory: "Video") { return url }
            if let url = Bundle.main.url(forResource: name, withExtension: "mp4", subdirectory: "Video") { return url }
        }
        return Bundle.main.urls(forResourcesWithExtension: "MP4", subdirectory: nil)?
            .first(where: { $0.lastPathComponent.localizedCaseInsensitiveContains("running animation") })
            ?? Bundle.main.urls(forResourcesWithExtension: "mp4", subdirectory: nil)?
            .first(where: { $0.lastPathComponent.localizedCaseInsensitiveContains("running animation") })
    }
}

private struct RunningLoopPlayer: UIViewRepresentable {
    func makeUIView(context: Context) -> RunningLoopPlayerView {
        RunningLoopPlayerView()
    }

    func updateUIView(_ uiView: RunningLoopPlayerView, context: Context) {}

    static func dismantleUIView(_ uiView: RunningLoopPlayerView, coordinator: ()) {
        // deinit stops the player
    }
}
