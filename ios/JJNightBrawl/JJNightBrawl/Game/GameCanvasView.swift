import SwiftUI
import UIKit

// MARK: - Bridge

final class GameBridge: ObservableObject {
    let engine = GameEngine()
    let assets = GameAssets()
    let audio = GameAudio()
    let renderer = GameRenderer()

    @Published var phase: GamePhase = .title
    @Published var specialMeter: CGFloat = 0
    @Published var hasGun = false
    @Published var hudScore = 0
    @Published var hudWave = 0
    @Published var hudHP: CGFloat = 100

    init() {
        engine.onSfx = { [weak self] name in
            self?.audio.play(name)
        }
    }

    func syncHUD() {
        let s = engine.state
        if phase != s.phase { phase = s.phase }
        if abs(specialMeter - s.specialMeter) > 0.5 { specialMeter = s.specialMeter }
        if hasGun != s.hasGun { hasGun = s.hasGun }
        if hudScore != s.score { hudScore = s.score }
        if hudWave != s.wave { hudWave = s.wave }
        if abs(hudHP - s.player.hp) > 0.25 { hudHP = s.player.hp }
    }
}

// MARK: - SwiftUI shell

struct ContentView: View {
    @StateObject private var bridge = GameBridge()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GameCanvasRepresentable(bridge: bridge)
                .ignoresSafeArea()
            hud
            if bridge.phase == .title {
                titleOverlay
            }
            if bridge.phase == .playing || bridge.phase == .paused || bridge.phase == .waveClear {
                TouchControlPad(
                    onMove: { x, y in
                        bridge.engine.setMoveAxis(x: x, y: y)
                    },
                    onClearMove: {
                        bridge.engine.clearTouch()
                    },
                    onPunch: { bridge.engine.queueAttack(.punch) },
                    onKick: { bridge.engine.queueAttack(.kick) },
                    onJump: { bridge.engine.queueJump() },
                    onSpecial: { bridge.engine.queueAttack(.special) },
                    onGun: { bridge.engine.queueAttack(.gun) },
                    showGun: bridge.hasGun
                )
            }
        }
        .statusBarHidden()
        .onAppear {
            bridge.audio.prepare()
            if ProcessInfo.processInfo.arguments.contains("JJAutoStart")
                || ProcessInfo.processInfo.environment["JJ_AUTO_START"] == "1" {
                bridge.engine.startGame()
                bridge.syncHUD()
            }
        }
    }

    private var titleOverlay: some View {
        VStack(spacing: 18) {
            Text("JJ: NIGHT BRAWL")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text("Streets of the night. Clear the pack.")
                .foregroundColor(.white.opacity(0.75))
            Button {
                bridge.audio.play("uiConfirm")
                bridge.engine.startGame()
                bridge.syncHUD()
            } label: {
                Text("START BRAWL")
                    .font(.system(size: 20, weight: .bold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.85))
                    .foregroundColor(.white)
            }
        }
    }

    private var hud: some View {
        VStack {
            HStack {
                Text("HP \(Int(bridge.hudHP))")
                    .foregroundColor(.white)
                Spacer()
                Text("WAVE \(bridge.hudWave)")
                    .foregroundColor(.white)
                Spacer()
                Text("SCORE \(bridge.hudScore)")
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(Color.cyan.opacity(0.85))
                        .frame(width: geo.size.width * (bridge.specialMeter / 100))
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 24)
            Spacer()
        }
        .allowsHitTesting(false)
        .opacity(bridge.phase == .title ? 0 : 1)
    }
}

// MARK: - UIView representable

struct GameCanvasRepresentable: UIViewRepresentable {
    let bridge: GameBridge

    func makeUIView(context: Context) -> GameCanvasUIView {
        let v = GameCanvasUIView(bridge: bridge)
        return v
    }

    func updateUIView(_ uiView: GameCanvasUIView, context: Context) {}
}

final class GameCanvasUIView: UIView {
    let bridge: GameBridge
    private var displayLink: CADisplayLink?
    private var lastTs: CFTimeInterval = 0

    init(bridge: GameBridge) {
        self.bridge = bridge
        super.init(frame: .zero)
        backgroundColor = .black
        isMultipleTouchEnabled = true
        // Cap retina work — freeze mitigation.
        contentScaleFactor = min(UIScreen.main.scale, 2)
        NotificationCenter.default.addObserver(
            self, selector: #selector(appBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:)") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            bridge.assets.loadAsync { [weak self] in
                self?.startLink()
            }
        } else {
            stopLink()
        }
    }

    private func startLink() {
        stopLink()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        } else {
            link.preferredFramesPerSecond = 60
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastTs = 0
    }

    private func stopLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func appBackground() { stopLink() }
    @objc private func appForeground() { startLink() }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTs == 0 { lastTs = link.timestamp; return }
        let dt = CGFloat(link.timestamp - lastTs)
        lastTs = link.timestamp
        bridge.engine.update(dt: dt)
        bridge.syncHUD()
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        bridge.renderer.draw(
            context: ctx,
            rect: bounds,
            state: bridge.engine.state,
            assets: bridge.assets
        )
    }

    // Keyboard (Simulator / external)
    override var canBecomeFirstResponder: Bool { true }
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        becomeFirstResponder()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key {
                handleKey(key, down: true)
            }
        }
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key {
                handleKey(key, down: false)
            }
        }
        super.pressesEnded(presses, with: event)
    }

    private func handleKey(_ key: UIKey, down: Bool) {
        let chars = key.charactersIgnoringModifiers.lowercased()
        if chars == "a" || key.keyCode == .keyboardLeftArrow { bridge.engine.setKey("a", down: down) }
        if chars == "d" || key.keyCode == .keyboardRightArrow { bridge.engine.setKey("d", down: down) }
        if chars == "w" || key.keyCode == .keyboardUpArrow { bridge.engine.setKey("w", down: down) }
        if chars == "s" || key.keyCode == .keyboardDownArrow { bridge.engine.setKey("s", down: down) }
        if down {
            if chars == "j" || chars == "z" { bridge.engine.queueAttack(.punch) }
            if chars == "k" || chars == "x" { bridge.engine.queueAttack(.kick) }
            if chars == "l" || chars == "c" { bridge.engine.queueAttack(.special) }
            if chars == "f" || chars == "u" || chars == "g" { bridge.engine.queueAttack(.gun) }
            if chars == " " || key.keyCode == .keyboardSpacebar { bridge.engine.queueJump() }
            if chars == "p" { bridge.engine.togglePause() }
        }
    }
}

// MARK: - Touch controls (analog stick)

struct TouchControlPad: View {
    var onMove: (_ x: CGFloat, _ y: CGFloat) -> Void
    var onClearMove: () -> Void
    var onPunch: () -> Void
    var onKick: () -> Void
    var onJump: () -> Void
    var onSpecial: () -> Void
    var onGun: () -> Void
    var showGun: Bool

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                VirtualStick(onMove: onMove, onClear: onClearMove)
                    .frame(width: 140, height: 140)
                    .padding(.leading, 28)
                    .padding(.bottom, 18)
                Spacer()
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        actionButton("PUNCH", onPunch)
                        actionButton("KICK", onKick)
                    }
                    HStack(spacing: 10) {
                        actionButton("JUMP", onJump)
                        actionButton("RIFF", onSpecial)
                    }
                    if showGun {
                        actionButton("GUN", onGun)
                    }
                }
                .padding(.trailing, 24)
                .padding(.bottom, 18)
            }
        }
    }

    private func actionButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 72, height: 44)
                .background(Color.white.opacity(0.14))
                .foregroundColor(.white)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.35), lineWidth: 1))
        }
    }
}

/// Analog virtual stick. Reports normalized -1...1 axes via onMove.
struct VirtualStick: View {
    var onMove: (_ x: CGFloat, _ y: CGFloat) -> Void
    var onClear: () -> Void

    @State private var drag: CGSize = .zero
    private let radius: CGFloat = 52

    var body: some View {
        GeometryReader { geo in
            let mid = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .background(Circle().fill(Color.white.opacity(0.06)))
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 54, height: 54)
                    .position(x: mid.x + drag.width, y: mid.y + drag.height)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        apply(offset: CGSize(
                            width: value.translation.width,
                            height: value.translation.height
                        ))
                    }
                    .onEnded { _ in
                        drag = .zero
                        onClear()
                    }
            )
        }
    }

    private func apply(offset: CGSize) {
        let len = hypot(offset.width, offset.height)
        let clamped: CGSize
        if len > radius && len > 0 {
            let s = radius / len
            clamped = CGSize(width: offset.width * s, height: offset.height * s)
        } else {
            clamped = offset
        }
        drag = clamped
        // Normalize by stick radius → -1...1
        let x = clamped.width / radius
        let y = clamped.height / radius
        onMove(max(-1, min(1, x)), max(-1, min(1, y)))
    }
}
