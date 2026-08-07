import SwiftUI
import UIKit

/// UIKit host that runs the 60fps game loop and draws with Core Graphics.
final class GameCanvasUIView: UIView {
    let engine = GameEngine()
    let assets = GameAssets()
    private var displayLink: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var lastHud: HudSnapshot?
    private var appObservers: [NSObjectProtocol] = []
    var onPhaseChange: ((GamePhase) -> Void)?
    var onHudTick: ((HudSnapshot) -> Void)?

    struct HudSnapshot: Equatable {
        var phase: GamePhase
        var hasGun: Bool
        var special: Int
        var hp: Int
        var wave: Int
        var score: Int
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true
        backgroundColor = .black
        isOpaque = true
        contentMode = .redraw
        // Pro Max is @3x; full-screen Core Graphics at 120Hz×3x will watchdog-kill.
        // Cap backing scale — still sharp enough, far cheaper to redraw.
        contentScaleFactor = min(UIScreen.main.scale, 2.0)
        layer.drawsAsynchronously = true

        // Load assets off the main thread (chroma-key on large sheets used to block launch).
        assets.loadAsync { [weak self] in
            self?.setNeedsDisplay()
        }
        engine.audio.unlock()
        installLifecycleObservers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopLoop()
        for o in appObservers {
            NotificationCenter.default.removeObserver(o)
        }
    }

    private func installLifecycleObservers() {
        let center = NotificationCenter.default
        appObservers.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.displayLink?.isPaused = true
        })
        appObservers.append(center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.displayLink?.isPaused = false
            self?.lastTime = CACurrentMediaTime()
            self?.engine.audio.unlock()
        })
    }

    func startLoop() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        // iPhone 16 Pro Max is 120Hz ProMotion — uncapped CADisplayLink + full-scene
        // CG redraw freezes the main thread shortly after combat starts.
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        } else {
            link.preferredFramesPerSecond = 60
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastTime = CACurrentMediaTime()
    }

    func stopLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        var dt = now - lastTime
        lastTime = now
        if dt > 0.05 { dt = 0.05 }
        if dt < 0 { dt = 1.0 / 60.0 }
        if assets.ready {
            engine.update(dt: CGFloat(dt))
        }
        // Only push SwiftUI bindings when HUD-relevant values change.
        // Writing @State every frame forces layout thrash and freezes overlays.
        let s = engine.state
        let snap = HudSnapshot(
            phase: s.phase,
            hasGun: s.hasGun,
            special: Int(s.specialMeter),
            hp: max(0, Int(s.player.hp)),
            wave: s.wave,
            score: s.score
        )
        if snap != lastHud {
            lastHud = snap
            onPhaseChange?(snap.phase)
            onHudTick?(snap)
        }
        setNeedsDisplay()
    }

    // MARK: - Touch (title / game-over / victory)

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        // Allow tapping the canvas itself to start / retry (not only the SwiftUI button).
        let ph = engine.state.phase
        if ph == .title || ph == .gameover || ph == .victory {
            engine.audio.unlock()
            engine.startGame()
            engine.clearTouch()
            _ = becomeFirstResponder()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        // Map view → 960×540 logical
        let bw = max(1, bounds.width)
        let bh = max(1, bounds.height)
        let scaleX = bw / GameRenderer.viewW
        let scaleY = bh / GameRenderer.viewH
        let scale = min(scaleX, scaleY)
        let drawW = GameRenderer.viewW * scale
        let drawH = GameRenderer.viewH * scale
        let ox = (bw - drawW) / 2
        let oy = (bh - drawH) / 2

        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(bounds)

        ctx.saveGState()
        ctx.translateBy(x: ox, y: oy)
        ctx.scaleBy(x: scale, y: scale)
        // Pixel-art friendly
        ctx.interpolationQuality = .none

        if assets.ready {
            GameRenderer.render(ctx: ctx, state: engine.state, assets: assets)
            let phase = engine.state.phase
            let now = CACurrentMediaTime()
            switch phase {
            case .title:
                GameRenderer.drawTitle(ctx: ctx, assets: assets, now: now)
            case .paused:
                GameRenderer.drawBanner(ctx: ctx, title: "PAUSED", subtitle: "Tap RESUME")
            case .gameover:
                GameRenderer.drawBanner(ctx: ctx, title: "KNOCKED OUT", subtitle: "Score \(engine.state.score) — tap RETRY")
            case .victory:
                GameRenderer.drawBanner(ctx: ctx, title: "STREET CLEARED", subtitle: "Score \(engine.state.score) — tap PLAY AGAIN")
            default:
                break
            }
        } else {
            let s = "Loading…" as NSString
            s.draw(at: CGPoint(x: 400, y: 250), withAttributes: [
                .font: UIFont.systemFont(ofSize: 20),
                .foregroundColor: UIColor.lightGray
            ])
        }
        ctx.restoreGState()
    }

    // Keyboard (iPad / Mac Catalyst / external)
    override var canBecomeFirstResponder: Bool { true }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for p in presses {
            guard let key = p.key else { continue }
            handleKey(key, down: true)
        }
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for p in presses {
            guard let key = p.key else { continue }
            handleKey(key, down: false)
        }
        super.pressesEnded(presses, with: event)
    }

    private func handleKey(_ key: UIKey, down: Bool) {
        engine.audio.unlock()
        let chars = key.charactersIgnoringModifiers.lowercased()
        if chars == "\r" || chars == "\n" {
            if down {
                let ph = engine.state.phase
                if ph == .title || ph == .gameover || ph == .victory {
                    engine.startGame()
                }
            }
            return
        }
        if chars == "p" || key.keyCode == .keyboardEscape {
            if down { engine.togglePause() }
            return
        }
        switch key.keyCode {
        case .keyboardA, .keyboardLeftArrow: engine.setKey("left", down: down)
        case .keyboardD, .keyboardRightArrow: engine.setKey("right", down: down)
        case .keyboardW, .keyboardUpArrow: engine.setKey("up", down: down)
        case .keyboardS, .keyboardDownArrow: engine.setKey("down", down: down)
        case .keyboardJ, .keyboardZ: engine.setKey("punch", down: down)
        case .keyboardK, .keyboardX: engine.setKey("kick", down: down)
        case .keyboardL, .keyboardC: engine.setKey("special", down: down)
        case .keyboardF, .keyboardU, .keyboardG: engine.setKey("gun", down: down)
        case .keyboardSpacebar, .keyboardLeftShift, .keyboardRightShift:
            engine.setKey("jump", down: down)
        default: break
        }
    }
}

// MARK: - Bridge (reliable engine access from SwiftUI)

/// Holds the live UIKit canvas. Using a class avoids the classic SwiftUI bug where
/// assigning `@State` from `makeUIView` is dropped, leaving START / controls as no-ops.
final class GameCanvasBridge: ObservableObject {
    weak var canvas: GameCanvasUIView?

    var engine: GameEngine? { canvas?.engine }

    @discardableResult
    func startGame() -> Bool {
        guard let canvas else { return false }
        canvas.engine.audio.unlock()
        canvas.engine.startGame()
        canvas.engine.clearTouch()
        _ = canvas.becomeFirstResponder()
        return true
    }
}

// MARK: - UIViewRepresentable

struct GameCanvasRepresentable: UIViewRepresentable {
    @Binding var phase: GamePhase
    @Binding var hasGun: Bool
    @Binding var special: Int
    var bridge: GameCanvasBridge

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    func makeUIView(context: Context) -> GameCanvasUIView {
        let v = GameCanvasUIView()
        context.coordinator.bind(v)
        v.onPhaseChange = { [weak coordinator = context.coordinator] newPhase in
            // Bindings are refreshed in updateUIView; coordinator holds latest.
            coordinator?.phaseBinding?.wrappedValue = newPhase
        }
        v.onHudTick = { [weak coordinator = context.coordinator] snap in
            coordinator?.phaseBinding?.wrappedValue = snap.phase
            coordinator?.hasGunBinding?.wrappedValue = snap.hasGun
            coordinator?.specialBinding?.wrappedValue = snap.special
        }
        // Publish after the current SwiftUI update cycle so @StateObject sees it.
        DispatchQueue.main.async {
            context.coordinator.bridge.canvas = v
        }
        v.startLoop()
        DispatchQueue.main.async { _ = v.becomeFirstResponder() }
        return v
    }

    func updateUIView(_ uiView: GameCanvasUIView, context: Context) {
        context.coordinator.phaseBinding = $phase
        context.coordinator.hasGunBinding = $hasGun
        context.coordinator.specialBinding = $special
        context.coordinator.bridge.canvas = uiView
    }

    static func dismantleUIView(_ uiView: GameCanvasUIView, coordinator: Coordinator) {
        uiView.stopLoop()
        if coordinator.bridge.canvas === uiView {
            coordinator.bridge.canvas = nil
        }
    }

    final class Coordinator {
        let bridge: GameCanvasBridge
        var phaseBinding: Binding<GamePhase>?
        var hasGunBinding: Binding<Bool>?
        var specialBinding: Binding<Int>?

        init(bridge: GameCanvasBridge) {
            self.bridge = bridge
        }

        func bind(_ view: GameCanvasUIView) {
            bridge.canvas = view
        }
    }
}

// MARK: - Root UI

struct ContentView: View {
    @StateObject private var bridge = GameCanvasBridge()
    @State private var phase: GamePhase = .title
    @State private var hasGun = false
    @State private var special = 0
    @State private var muted = false

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                Color.black.ignoresSafeArea()

                GameCanvasRepresentable(
                    phase: $phase,
                    hasGun: $hasGun,
                    special: $special,
                    bridge: bridge
                )
                .ignoresSafeArea()

                // Overlay chrome only — empty space must NOT steal taps from the canvas.
                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                        .allowsHitTesting(false)
                    if showsMenuButton {
                        menuButton
                            .padding(.bottom, 8)
                    }
                    if showsTouchPad {
                        TouchControlPad(
                            landscape: landscape,
                            hasGun: hasGun,
                            specialReady: special >= 40,
                            onMove: { left, right, up, down in
                                bridge.engine?.setTouch(left: left, right: right, up: up, down: down)
                            },
                            onClearMove: {
                                bridge.engine?.clearTouch()
                            },
                            onAction: { action in
                                guard let engine = bridge.engine else { return }
                                engine.audio.unlock()
                                switch action {
                                case .punch: engine.queueAction(.punch)
                                case .kick: engine.queueAction(.kick)
                                case .jump: engine.queueJump()
                                case .riff: engine.queueAction(.special)
                                case .gun:
                                    if engine.state.hasGun { engine.queueAction(.gun) }
                                case .pause: engine.togglePause()
                                }
                            }
                        )
                        .padding(.horizontal, landscape ? 16 : 10)
                        .padding(.bottom, max(10, geo.safeAreaInsets.bottom + 6))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: phase) { newPhase in
            // Drop stuck d-pad / stick when leaving combat
            if newPhase != .playing {
                bridge.engine?.clearTouch()
            }
        }
    }

    private var showsTouchPad: Bool {
        phase == .playing || phase == .waveClear || phase == .paused
    }

    private var showsMenuButton: Bool {
        phase == .title || phase == .gameover || phase == .victory
    }

    private var topBar: some View {
        HStack {
            if phase == .playing || phase == .paused {
                TouchChip(
                    title: phase == .paused ? "RESUME" : "PAUSE",
                    color: Color.white.opacity(0.15)
                ) {
                    bridge.engine?.audio.unlock()
                    bridge.engine?.togglePause()
                }
            }
            Spacer()
                .allowsHitTesting(false)
            TouchChip(
                title: muted ? "SOUND OFF" : "SOUND ON",
                color: Color.white.opacity(0.12)
            ) {
                muted = bridge.engine?.audio.toggleMute() ?? false
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private var menuButton: some View {
        Button {
            if bridge.startGame() {
                // Immediate UI feedback — don't wait for the next display-link tick.
                phase = .playing
            }
        } label: {
            Text(phase == .title ? "START BRAWL" : (phase == .victory ? "PLAY AGAIN" : "RETRY"))
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color(red: 1, green: 0.18, blue: 0.54))
                .clipShape(Capsule())
                .shadow(color: Color(red: 1, green: 0.18, blue: 0.54).opacity(0.45), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}

// MARK: - Touch control pad

private enum TouchAction {
    case punch, kick, jump, riff, gun, pause
}

/// On-screen virtual stick + action cluster for phones/tablets.
private struct TouchControlPad: View {
    var landscape: Bool
    var hasGun: Bool
    var specialReady: Bool
    var onMove: (_ left: Bool, _ right: Bool, _ up: Bool, _ down: Bool) -> Void
    var onClearMove: () -> Void
    var onAction: (TouchAction) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: landscape ? 20 : 12) {
            VirtualStick(onMove: onMove, onClear: onClearMove)
                .frame(width: landscape ? 148 : 132, height: landscape ? 148 : 132)

            Spacer(minLength: 8)

            actionCluster
        }
        // Only the pad itself intercepts touches — not empty regions outside
        .allowsHitTesting(true)
    }

    private var actionCluster: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack(spacing: 10) {
                ActionPadButton(title: "JUMP", color: Color(white: 0.35), minW: 72) {
                    onAction(.jump)
                }
                ActionPadButton(
                    title: "RIFF",
                    color: specialReady
                        ? Color(red: 0.18, green: 0.89, blue: 0.9)
                        : Color(red: 0.18, green: 0.89, blue: 0.9).opacity(0.4),
                    minW: 72
                ) {
                    onAction(.riff)
                }
                if hasGun {
                    ActionPadButton(
                        title: "GUN",
                        color: Color(red: 1, green: 0.9, blue: 0.4),
                        minW: 72
                    ) {
                        onAction(.gun)
                    }
                }
            }
            HStack(spacing: 12) {
                ActionPadButton(title: "KICK", color: Color(white: 0.4), minW: 88, minH: 64) {
                    onAction(.kick)
                }
                ActionPadButton(
                    title: "PUNCH",
                    color: Color(red: 1, green: 0.18, blue: 0.54),
                    minW: 100,
                    minH: 72
                ) {
                    onAction(.punch)
                }
            }
        }
    }
}

// MARK: - Virtual analog stick

private struct VirtualStick: View {
    var onMove: (_ left: Bool, _ right: Bool, _ up: Bool, _ down: Bool) -> Void
    var onClear: () -> Void

    @State private var knob: CGSize = .zero
    @State private var dragging = false

    private let radius: CGFloat = 56
    private let dead: CGFloat = 14

    var body: some View {
        ZStack {
            // Base
            Circle()
                .fill(Color.white.opacity(0.08))
                .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 2))
            // Crosshair guides
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .padding(28)

            // Knob
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1, green: 0.35, blue: 0.65),
                            Color(red: 0.85, green: 0.12, blue: 0.45)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 54, height: 54)
                .shadow(color: Color(red: 1, green: 0.18, blue: 0.54).opacity(0.5), radius: 8, y: 2)
                .offset(knob)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                        .offset(knob)
                        .frame(width: 54, height: 54)
                )

            Text("MOVE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(dragging ? 0 : 0.35))
                .offset(y: 58)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragging = true
                    let raw = value.translation
                    let len = sqrt(raw.width * raw.width + raw.height * raw.height)
                    let clamped: CGSize
                    if len > radius && len > 0.001 {
                        let s = radius / len
                        clamped = CGSize(width: raw.width * s, height: raw.height * s)
                    } else {
                        clamped = raw
                    }
                    knob = clamped
                    apply(clamped)
                }
                .onEnded { _ in
                    dragging = false
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                        knob = .zero
                    }
                    onClear()
                }
        )
        .accessibilityLabel("Move stick")
    }

    private func apply(_ o: CGSize) {
        let left = o.width < -dead
        let right = o.width > dead
        let up = o.height < -dead
        let down = o.height > dead
        onMove(left, right, up, down)
    }
}

// MARK: - Buttons

/// Fire-on-press action button (game-feel; not wait-for-release).
private struct ActionPadButton: View {
    var title: String
    var color: Color
    var minW: CGFloat = 72
    var minH: CGFloat = 56
    var action: () -> Void

    @State private var pressed = false

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(.white)
            .frame(minWidth: minW, minHeight: minH)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color.opacity(pressed ? 1 : 0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .scaleEffect(pressed ? 0.94 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressed {
                            pressed = true
                            action() // fire once on press
                        }
                    }
                    .onEnded { _ in
                        pressed = false
                    }
            )
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

private struct TouchChip: View {
    var title: String
    var color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(color)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
