import SwiftUI
import UIKit

/// UIKit host that runs the 60fps game loop and draws with Core Graphics.
final class GameCanvasUIView: UIView {
    let engine = GameEngine()
    let assets = GameAssets()
    private var displayLink: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    var onPhaseChange: ((GamePhase) -> Void)?
    var onHudTick: ((HudSnapshot) -> Void)?

    struct HudSnapshot {
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
        contentMode = .redraw
        assets.load()
        engine.audio.unlock()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startLoop() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
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
        if assets.ready {
            engine.update(dt: CGFloat(dt))
            let s = engine.state
            onPhaseChange?(s.phase)
            onHudTick?(HudSnapshot(
                phase: s.phase,
                hasGun: s.hasGun,
                special: Int(s.specialMeter),
                hp: max(0, Int(s.player.hp)),
                wave: s.wave,
                score: s.score
            ))
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        // Map view → 960×540 logical
        let scaleX = bounds.width / GameRenderer.viewW
        let scaleY = bounds.height / GameRenderer.viewH
        let scale = min(scaleX, scaleY)
        let drawW = GameRenderer.viewW * scale
        let drawH = GameRenderer.viewH * scale
        let ox = (bounds.width - drawW) / 2
        let oy = (bounds.height - drawH) / 2

        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(bounds)

        ctx.saveGState()
        ctx.translateBy(x: ox, y: oy)
        ctx.scaleBy(x: scale, y: scale)

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

// MARK: - UIViewRepresentable

struct GameCanvasRepresentable: UIViewRepresentable {
    @Binding var phase: GamePhase
    @Binding var hasGun: Bool
    @Binding var special: Int
    var canvasRef: (GameCanvasUIView) -> Void

    func makeUIView(context: Context) -> GameCanvasUIView {
        let v = GameCanvasUIView()
        v.onPhaseChange = { phase = $0 }
        v.onHudTick = { snap in
            phase = snap.phase
            hasGun = snap.hasGun
            special = snap.special
        }
        canvasRef(v)
        v.startLoop()
        DispatchQueue.main.async { _ = v.becomeFirstResponder() }
        return v
    }

    func updateUIView(_ uiView: GameCanvasUIView, context: Context) {}

    static func dismantleUIView(_ uiView: GameCanvasUIView, coordinator: ()) {
        uiView.stopLoop()
    }
}

// MARK: - Root UI

struct ContentView: View {
    @State private var phase: GamePhase = .title
    @State private var hasGun = false
    @State private var special = 0
    @State private var canvas: GameCanvasUIView?
    @State private var muted = false

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                Color.black.ignoresSafeArea()

                GameCanvasRepresentable(
                    phase: $phase,
                    hasGun: $hasGun,
                    special: $special
                ) { canvas = $0 }
                .ignoresSafeArea()

                // Full-screen pass-through shell; only interactive children eat touches
                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
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
                                canvas?.engine.setTouch(left: left, right: right, up: up, down: down)
                            },
                            onClearMove: {
                                canvas?.engine.clearTouch()
                            },
                            onAction: { action in
                                guard let engine = canvas?.engine else { return }
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
                .allowsHitTesting(true)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: phase) { newPhase in
            // Drop stuck d-pad / stick when leaving combat
            if newPhase != .playing {
                canvas?.engine.clearTouch()
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
                    canvas?.engine.audio.unlock()
                    canvas?.engine.togglePause()
                }
            }
            Spacer()
            TouchChip(
                title: muted ? "SOUND OFF" : "SOUND ON",
                color: Color.white.opacity(0.12)
            ) {
                muted = canvas?.engine.audio.toggleMute() ?? false
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private var menuButton: some View {
        Button {
            canvas?.engine.audio.unlock()
            canvas?.engine.startGame()
            canvas?.engine.clearTouch()
            _ = canvas?.becomeFirstResponder()
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
