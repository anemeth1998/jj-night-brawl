import SwiftUI
import UIKit
import AVKit
import AVFoundation

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
    /// Keyboard Escape / Return while SwiftUI owns the route (Options, Credits, card focus).
    /// Return `true` when handled; the canvas then leaves the key alone.
    var onMenuBackKey: (() -> Bool)?
    var onMenuConfirmKey: (() -> Bool)?
    /// A bare title tap: `uiTap` on touch-down, `enterMainMenu` on touch-up (one finger).
    private var titleTouchArmed = false

    struct HudSnapshot: Equatable {
        var phase: GamePhase
        var hasGun: Bool
        var special: Int
        var hp: Int
        var wave: Int
        var score: Int
        /// Stage / loading banner text (empty outside combat/loading).
        var stageLabel: String
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
        // NOTE: drawsAsynchronously can leave a blank/black framebuffer on device.
        layer.drawsAsynchronously = false

        // Load sprites off the main thread so device launch never sits on a black main thread.
        assets.loadAsync { [weak self] in
            guard let self else { return }
            self.setNeedsDisplay()
            self.maybeAutoStartAfterAssetsReady()
        }
        // Defer audio until after first layout — AVAudioSession can stall first paint on device.
        // Menu music is the soundtrack inside menu-select-loop.mp4 (CharSelectLoopStackView);
        // TDM is held back for Credits, so nothing starts it here.
        DispatchQueue.main.async { [weak self] in
            self?.engine.audio.unlock()
        }
        installLifecycleObservers()
    }

    /// Sim/automation: pass launch arg `-JJAutoStart` (or env `JJ_AUTO_START=1`) to enter combat
    /// after assets load — same path as START BRAWL, for headless freeze checks.
    private func maybeAutoStartAfterAssetsReady() {
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        let want = args.contains("-JJAutoStart")
            || env["JJ_AUTO_START"] == "1"
            || env["JJ_AUTO_START"]?.lowercased() == "true"
        guard want else { return }
        // One frame of title first so layout/HUD settle like a real tap.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            let ph = self.engine.state.phase
            guard ph == .title || ph == .gameover || ph == .victory else { return }
            print("[JJ] auto-start → startGame (phase was \(ph.rawValue))")
            self.engine.audio.unlock()
            self.engine.startGame()
            self.engine.clearTouch()
            _ = self.becomeFirstResponder()
        }
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
            // No fade while suspending — detach now, on main.
            self?.engine.audio.stopMenuTheme(immediate: true)
            self?.engine.flushInput()
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

    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure the loop is running once we have a real size (device can lay out late).
        if bounds.width > 1, bounds.height > 1, displayLink == nil {
            startLoop()
        }
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
        setNeedsDisplay()
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
        
        // Skip heavy combat redraw on static menus / the between-stage loading hold.
        let shouldUpdate = assets.ready && (engine.state.phase == .playing ||
                                           engine.state.phase == .waveClear ||
                                           engine.state.phase == .victory ||
                                           engine.state.particles.count > 0)

        if assets.ready {
            // Frame count of whichever run sheet the selected fighter actually draws with
            // (JJ 16-frame bake vs Andrew / Han 4-frame walk) so sprint fps stays sane.
            engine.playerRunFrames = assets.sheetForPlayer(
                anim: .run, attackKind: nil, fighter: engine.state.selectedFighter
            ).frameCount
            engine.playerSpecialFrames = assets.sheetForPlayer(
                anim: .attack, attackKind: .special, fighter: engine.state.selectedFighter
            ).frameCount
            // Frames in the sheet the current melee move actually draws with (variant sheets
            // from the clip pipeline can be 8–12; the legacy atlases are 4).
            if let kind = engine.state.player.attackKind, kind != .special {
                engine.playerAttackFrames = assets.sheetForPlayer(
                    anim: .attack, attackKind: kind, variant: engine.state.player.attackVariant,
                    fighter: engine.state.selectedFighter
                ).frameCount
            }
            // Warm the next stage's parallax while the loading clip plays.
            if engine.state.phase == .loading, let pending = engine.state.pendingStageIndex {
                _ = assets.maps(forStageIndex: pending)
            }
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
            score: s.score,
            stageLabel: s.phase == .loading
                ? (s.stageName.isEmpty ? s.message : s.stageName.uppercased())
                : s.stageName
        )
        let changed = snap != lastHud
        if changed {
            lastHud = snap
            onPhaseChange?(snap.phase)
            onHudTick?(snap)
        }

        // Only redraw when necessary. The title plate is static now (SwiftUI owns the CTA), so
        // menu phases repaint on phase change only; the procedural fallback title still animates.
        let animatedTitle = s.phase == .title && assets.titleScreen == nil
        if shouldUpdate || changed || animatedTitle {
            setNeedsDisplay()
        }
    }

    // MARK: - Touch (title only)

    /// The one "press start" door. A bare canvas tap on `.title`, the VoiceOver start action
    /// and the Return key all land here. Guarded on phase so two paths in the same frame cannot
    /// double-enter — and it can never start combat.
    @discardableResult
    func requestEnterMainMenu() -> Bool {
        guard assets.ready, engine.state.phase == .title else { return false }
        engine.audio.unlock()
        engine.enterMainMenu()
        engine.clearTouch()
        _ = becomeFirstResponder()
        return true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        // Title is the arcade exception: bare brick = PRESS START. Everything else is solid.
        guard engine.state.phase == .title, assets.ready, !titleTouchArmed else { return }
        titleTouchArmed = true
        engine.audio.unlock()
        engine.audio.uiTap()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        // gameover / victory no longer start a run from a canvas tap — RETRY is a button only.
        // mainMenu / charSelect / Options / Credits: canvas misses are dead by design.
        let armed = titleTouchArmed
        titleTouchArmed = false
        if armed, engine.state.phase == .title {
            requestEnterMainMenu()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        titleTouchArmed = false
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
            let phase = engine.state.phase
            let now = CACurrentMediaTime()
            // Title plate stays under main menu / char select too, so title ↔ menu ↔ select
            // crossfade over one painting instead of flashing the combat stage between them.
            let menuPlate = phase == .title || phase == .mainMenu || phase == .charSelect
            if !menuPlate || assets.titleScreen == nil {
                GameRenderer.render(ctx: ctx, state: engine.state, assets: assets)
            }
            switch phase {
            case .title, .mainMenu, .charSelect:
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
            // Visible on black so device users know we aren't frozen.
            let s = "Loading…" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: UIColor(white: 0.85, alpha: 1)
            ]
            let sz = s.size(withAttributes: attrs)
            s.draw(at: CGPoint(x: (GameRenderer.viewW - sz.width) / 2,
                               y: (GameRenderer.viewH - sz.height) / 2),
                   withAttributes: attrs)
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
        let ph = engine.state.phase
        // Return: only when a primary action is valid (title door, retry, focused fighter).
        if chars == "\r" || chars == "\n" {
            if down {
                switch ph {
                case .title:
                    engine.audio.uiTap()
                    requestEnterMainMenu()
                case .gameover, .victory:
                    engine.audio.uiConfirm()
                    engine.startGame()
                    engine.clearTouch()
                default:
                    // charSelect → SwiftUI confirms the focused card; mainMenu has no focus → nothing.
                    _ = onMenuConfirmKey?()
                }
            }
            return
        }
        // Escape: BACK on menu surfaces, pause in combat.
        if key.keyCode == .keyboardEscape {
            if down {
                switch ph {
                case .mainMenu, .charSelect:
                    if !(onMenuBackKey?() ?? false) {
                        engine.audio.uiBack()
                        if ph == .charSelect { engine.returnToMainMenu() } else { engine.quitToTitle() }
                    }
                case .playing, .paused:
                    engine.togglePause()
                default:
                    break
                }
            }
            return
        }
        if chars == "p" {
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
        case .keyboardV, .keyboardLeftControl, .keyboardRightControl:
            engine.setKey("sprint", down: down)
        case .keyboardSpacebar, .keyboardLeftShift, .keyboardRightShift:
            engine.setKey("jump", down: down)
        default: break
        }
    }
}

// MARK: - Bridge (reliable engine access from SwiftUI)

/// Holds the live UIKit canvas. Using a class avoids the classic SwiftUI bug where
/// assigning `@State` from `makeUIView` is dropped, leaving START / controls as no-ops.
///
/// Navigation here is **silent** — the pressed control plays uiTap / uiBack / uiConfirm via
/// `MenuSFX`. Each door is guarded on the engine phase so a jittery finger or a stale SwiftUI
/// `phase` cannot enter twice or start a run from the wrong screen.
final class GameCanvasBridge: ObservableObject {
    weak var canvas: GameCanvasUIView?
    /// True once sprite sheets finished loading (drives SwiftUI Loading overlay).
    @Published var assetsReady = false
    /// SwiftUI route handlers for hardware keys (set by ContentView). Return true when handled.
    var menuBackKey: (() -> Bool)?
    var menuConfirmKey: (() -> Bool)?

    var engine: GameEngine? { canvas?.engine }

    /// Fighters that can actually start a run. Anything else → `uiDeny` at START BRAWL,
    /// never a silent fallback to JJ.
    static let playableFighters: Set<String> = ["jj", "andrew", "han"]
    static func isPlayable(_ who: String) -> Bool { playableFighters.contains(who.lowercased()) }

    /// Title → main menu. Funnels through the canvas so capsule / canvas tap / Return share one door.
    @discardableResult
    func enterMainMenu() -> Bool {
        guard let canvas else { return false }
        guard canvas.assets.ready else {
            print("[JJ] enterMainMenu ignored — assets not ready")
            return false
        }
        return canvas.requestEnterMainMenu()
    }

    @discardableResult
    func startStoryMode() -> Bool {
        guard let canvas, canvas.assets.ready else { return false }
        guard canvas.engine.state.phase == .mainMenu else { return false }
        canvas.engine.audio.unlock()
        canvas.engine.startStoryMode()
        canvas.engine.clearTouch()
        _ = canvas.becomeFirstResponder()
        return true
    }

    @discardableResult
    func enterEndlessCharSelect() -> Bool {
        guard let canvas, canvas.assets.ready else { return false }
        guard canvas.engine.state.phase == .mainMenu else { return false }
        canvas.engine.audio.unlock()
        canvas.engine.enterEndlessCharSelect()
        canvas.engine.clearTouch()
        _ = canvas.becomeFirstResponder()
        return true
    }

    /// Legacy title path — opens main menu (cards are Endless-only).
    @discardableResult
    func enterCharSelect() -> Bool {
        return enterMainMenu()
    }

    @discardableResult
    func confirmCharSelect(who: String) -> Bool {
        guard let canvas, canvas.assets.ready else { return false }
        guard canvas.engine.state.phase == .charSelect else { return false }
        guard Self.isPlayable(who) else { return false }
        canvas.engine.audio.unlock()
        canvas.engine.confirmCharSelect(who: who)
        canvas.engine.clearTouch()
        _ = canvas.becomeFirstResponder()
        return true
    }

    @discardableResult
    func returnToMainMenu() -> Bool {
        guard let canvas else { return false }
        guard canvas.engine.state.phase == .charSelect else { return false }
        canvas.engine.audio.unlock()
        canvas.engine.returnToMainMenu()
        canvas.engine.clearTouch()
        _ = canvas.becomeFirstResponder()
        return true
    }

    @discardableResult
    func quitToTitle() -> Bool {
        guard let canvas else { return false }
        let ph = canvas.engine.state.phase
        guard ph == .mainMenu || ph == .charSelect else { return false }
        canvas.engine.audio.unlock()
        canvas.engine.quitToTitle()
        canvas.engine.clearTouch()
        _ = canvas.becomeFirstResponder()
        return true
    }

    /// RETRY / PLAY AGAIN only. Title, menu and select never reach this.
    @discardableResult
    func startGame() -> Bool {
        guard let canvas else { return false }
        // Don't start combat until art is ready — otherwise pure black / empty combat.
        guard canvas.assets.ready else {
            print("[JJ] startGame ignored — assets not ready")
            return false
        }
        let ph = canvas.engine.state.phase
        guard ph == .gameover || ph == .victory else { return false }
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
    @Binding var stageLabel: String
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
            coordinator?.stageLabelBinding?.wrappedValue = snap.stageLabel
        }
        // Hardware Escape / Return on SwiftUI-owned routes (Options, Credits, card focus).
        v.onMenuBackKey = { [weak bridge = context.coordinator.bridge] in
            bridge?.menuBackKey?() ?? false
        }
        v.onMenuConfirmKey = { [weak bridge = context.coordinator.bridge] in
            bridge?.menuConfirmKey?() ?? false
        }
        // Publish after the current SwiftUI update cycle so @StateObject sees it.
        DispatchQueue.main.async {
            context.coordinator.bridge.canvas = v
            context.coordinator.bridge.assetsReady = v.assets.ready
        }
        // Poll ready once so SwiftUI overlay clears when background load finishes.
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak bridge = context.coordinator.bridge, weak v] timer in
            guard let bridge, let v else {
                timer.invalidate()
                return
            }
            if v.assets.ready {
                if !bridge.assetsReady {
                    bridge.assetsReady = true
                }
                timer.invalidate()
            }
        }
        v.startLoop()
        DispatchQueue.main.async { _ = v.becomeFirstResponder() }
        return v
    }

    func updateUIView(_ uiView: GameCanvasUIView, context: Context) {
        context.coordinator.phaseBinding = $phase
        context.coordinator.hasGunBinding = $hasGun
        context.coordinator.specialBinding = $special
        context.coordinator.stageLabelBinding = $stageLabel
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
        var stageLabelBinding: Binding<String>?

        init(bridge: GameCanvasBridge) {
            self.bridge = bridge
        }

        func bind(_ view: GameCanvasUIView) {
            bridge.canvas = view
        }
    }
}

// MARK: - Root UI

/// One living night alley, many layers (spec §2 / §3.4):
///   1. canvas — title plate under title / menu / select, combat later. Never transitioned.
///   2. alley loop backdrop — one player stack across main menu + char select (JJ loop on menu,
///      focused fighter on select). Survives Options / Credits / Back.
///   3. left dim gradient so the nav column reads; the right third of the loop stays clear.
///   4. route chrome — slides in from the leading edge (220ms) over the same backdrop.
struct ContentView: View {
    enum MenuRoute: Equatable { case root, options, credits }

    private static let lastFighterKey = "jj.lastFighter"

    @StateObject private var bridge = GameCanvasBridge()
    @State private var phase: GamePhase = .title
    @State private var hasGun = false
    @State private var special = 0
    @State private var stageLabel = ""
    @State private var muted = UserDefaults.standard.bool(forKey: GameAudio.Keys.muted)
    /// Sub-route inside `.mainMenu` (Options / Credits are SwiftUI-only — the engine stays in mainMenu).
    @State private var menuRoute: MenuRoute = .root
    /// Endless char-select focus — drives the loop backdrop (jj / andrew / han).
    @State private var previewFighter: String = ContentView.lastFighter()
    /// 80ms nameplate punch-in on START BRAWL.
    @State private var nameplatePunch = false

    private var sfx: MenuSFX { MenuSFX(bridge: bridge) }
    private var isMenuPhase: Bool { phase == .mainMenu || phase == .charSelect }
    private var isCombatPhase: Bool {
        switch phase {
        case .playing, .paused, .waveClear, .stageClear, .gameover, .victory: return true
        case .title, .mainMenu, .charSelect, .loading: return false
        }
    }

    /// Main-menu JJ keeps the old alley loop; Endless JJ focus uses the guitar sit-loop.
    private var alleyActiveId: String {
        guard phase == .charSelect else { return "jj" }
        return previewFighter == "jj" ? "jj-endless" : previewFighter
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let safe = geo.safeAreaInsets
            ZStack {
                Color.black.ignoresSafeArea()

                // 1. Canvas — always present. Do NOT wrap in a transition (prior freeze class).
                GameCanvasRepresentable(
                    phase: $phase,
                    hasGun: $hasGun,
                    special: $special,
                    stageLabel: $stageLabel,
                    bridge: bridge
                )
                .ignoresSafeArea()

                // Device-visible loading state (canvas "Loading…" can be easy to miss).
                if !bridge.assetsReady {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                        Text("Loading…")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.55))
                    .allowsHitTesting(false)
                }

                // 2 + 3. Alley loop + dim. Fades in over the title plate; stays alive across routes.
                Group {
                    if isMenuPhase && bridge.assetsReady {
                        CharSelectLoopStack(activeId: alleyActiveId, audio: bridge.engine?.audio)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .transition(.opacity)
                        menuSideGradient
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .transition(.opacity)
                        LinearGradient(
                            colors: [Color.black.opacity(0.3), Color.clear],
                            startPoint: .bottom,
                            endPoint: .center
                        )
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        // Solid alley: a tap on bare brick goes nowhere.
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .transition(.identity)
                    }
                }
                .animation(MenuTheme.slideAnim, value: phase)

                // 4. Route chrome — same backdrop, slides from the leading edge.
                Group {
                    if bridge.assetsReady {
                        if phase == .title {
                            titleChrome(safe: safe)
                                .transition(.opacity)
                        }
                        if phase == .mainMenu && menuRoute == .root {
                            menuColumn(landscape: landscape) { mainMenuRows }
                                .transition(MenuTheme.slide)
                        }
                        if phase == .mainMenu && menuRoute == .options {
                            menuColumn(landscape: landscape) {
                                OptionsPanel(bridge: bridge, sfx: sfx, muted: $muted) {
                                    menuRoute = .root
                                }
                            }
                            .transition(MenuTheme.slide)
                        }
                        if phase == .mainMenu && menuRoute == .credits {
                            menuColumn(landscape: landscape) {
                                CreditsPanel(sfx: sfx) { menuRoute = .root }
                            }
                            .transition(MenuTheme.slide)
                        }
                        if phase == .charSelect {
                            menuColumn(landscape: landscape) { charSelectRows }
                                .transition(MenuTheme.slide)
                        }
                        // Persistent menu chrome (does not slide): SOUND chip top-trailing.
                        if phase == .title || isMenuPhase {
                            SoundChip(muted: muted, sfx: sfx) {
                                muted = sfx.toggleMute(current: muted)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(.top, 10)
                            .padding(.trailing, 14)
                            .transition(.opacity)
                        }
                    }
                }
                .animation(MenuTheme.slideAnim, value: phase)
                .animation(MenuTheme.slideAnim, value: menuRoute)

                // Between-stage loading — looping run clip over a black hold (no combat chrome).
                if phase == .loading {
                    StageLoadingView(title: stageLabel.isEmpty ? "LOADING" : stageLabel)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(20)
                }

                // Combat chrome (unchanged layout): top bar, end-state button, continue, touch pad.
                VStack(spacing: 0) {
                    if isCombatPhase {
                        topBar
                    }
                    Spacer(minLength: 0)
                        .allowsHitTesting(false)
                    if phase == .stageClear {
                        // Own ≥44pt target — not under the stick (campaign Continue).
                        stageContinueStrip
                            .padding(.leading, max(24, safe.leading + 8))
                            .padding(.trailing, max(24, safe.trailing + 8))
                            .padding(.bottom, max(10, safe.bottom + 6))
                    } else if phase == .gameover || phase == .victory {
                        endStateButton
                            .padding(.bottom, 8)
                            .opacity(bridge.assetsReady ? 1 : 0.45)
                            .disabled(!bridge.assetsReady)
                    }
                    if showsTouchPad {
                        TouchControlPad(
                            landscape: landscape,
                            hasGun: hasGun,
                            specialReady: special >= 40,
                            onMove: { x, y in
                                bridge.engine?.setMoveAxis(x: x, y: y)
                            },
                            onClearMove: {
                                bridge.engine?.clearTouch()
                            },
                            onSprint: { down in
                                bridge.engine?.setKey("sprint", down: down)
                            },
                            onAction: { action in
                                guard let engine = bridge.engine else { return }
                                engine.audio.unlock()
                                switch action {
                                case .punch:
                                    FeelHaptics.medium()
                                    engine.queueAction(.punch)
                                case .kick:
                                    FeelHaptics.medium()
                                    engine.queueAction(.kick)
                                case .jump:
                                    FeelHaptics.light()
                                    engine.queueJump()
                                case .riff: engine.queueAction(.special)
                                case .gun:
                                    if engine.state.hasGun { engine.queueAction(.gun) }
                                case .pause: engine.togglePause()
                                }
                            }
                        )
                        .padding(.leading, max(landscape ? 16 : 10, safe.leading + 8))
                        .padding(.trailing, max(landscape ? 16 : 10, safe.trailing + 8))
                        .padding(.bottom, max(10, safe.bottom + 6))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            // Hardware keys on SwiftUI-owned routes (Escape = BACK, Return = focused primary).
            bridge.menuBackKey = { handleBackKey() }
            bridge.menuConfirmKey = { handleConfirmKey() }
        }
        .onChange(of: phase) { newPhase in
            // Drop stuck d-pad / stick when leaving combat
            if newPhase != .playing {
                bridge.engine?.clearTouch()
            }
            if newPhase != .mainMenu {
                menuRoute = .root
            }
            if newPhase == .charSelect {
                previewFighter = Self.lastFighter()
            }
            // Menu music lives in menu-select-loop.mp4 (CharSelectLoopStackView plays its audio
            // track on mainMenu / charSelect and fades it on dismantle). TDM is parked for
            // Credits; make sure it is never left looping into combat.
            if newPhase == .title || newPhase == .mainMenu || newPhase == .charSelect {
                bridge.engine?.audio.unlock()
            } else {
                bridge.engine?.audio.stopMenuTheme()
            }
        }
        .onChange(of: bridge.assetsReady) { ready in
            // First paint of title after async load — bring the SFX engine up once assets are in.
            guard ready else { return }
            muted = bridge.engine?.audio.isMuted ?? muted
            if phase == .title || phase == .mainMenu || phase == .charSelect {
                bridge.engine?.audio.unlock()
            }
        }
    }

    // MARK: Phase helpers

    private var showsTouchPad: Bool {
        phase == .playing || phase == .waveClear || phase == .paused
    }

    private static func lastFighter() -> String {
        let saved = UserDefaults.standard.string(forKey: lastFighterKey) ?? "jj"
        return GameCanvasBridge.isPlayable(saved) ? saved : "jj"
    }

    /// Escape on a menu surface. Options / Credits close first, then select → menu → title.
    private func handleBackKey() -> Bool {
        if phase == .mainMenu && menuRoute != .root {
            sfx.play(.back)
            menuRoute = .root
            return true
        }
        if phase == .charSelect {
            sfx.play(.back)
            if bridge.returnToMainMenu() { phase = .mainMenu }
            return true
        }
        if phase == .mainMenu {
            sfx.play(.back)
            if bridge.quitToTitle() { phase = .title }
            return true
        }
        return false
    }

    /// Return on char select confirms the focused card. Main menu has no focus → nothing.
    private func handleConfirmKey() -> Bool {
        guard phase == .charSelect else { return false }
        guard GameCanvasBridge.isPlayable(previewFighter) else {
            sfx.play(.deny)
            return true
        }
        sfx.play(.confirm)
        FeelHaptics.medium()
        confirmSelectedFighter()
        return true
    }

    // MARK: Combat chrome

    private var topBar: some View {
        // Keep chips on the RIGHT so they do not cover the canvas-drawn HEALTH / RIFF meters (left).
        HStack(spacing: 10) {
            Spacer()
                .allowsHitTesting(false)
            if phase == .playing || phase == .paused {
                TouchChip(
                    title: phase == .paused ? "RESUME" : "PAUSE",
                    color: Color.white.opacity(0.15)
                ) {
                    bridge.engine?.audio.unlock()
                    bridge.engine?.togglePause()
                }
            }
            SoundChip(muted: muted, sfx: sfx) {
                muted = sfx.toggleMute(current: muted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    /// RETRY / PLAY AGAIN — the only way back into a run from an end-state card.
    private var endStateButton: some View {
        MenuCapsule(
            title: phase == .victory ? "PLAY AGAIN" : "RETRY",
            style: .primary,
            minHeight: 52,
            sfx: sfx,
            successCue: .confirm,
            successHaptic: .medium,
            accessibilityLabel: phase == .victory ? "Play again" : "Retry"
        ) {
            if bridge.startGame() {
                // Immediate UI feedback — don't wait for the next display-link tick.
                phase = .playing
            }
        }
        .frame(maxWidth: 260)
    }

    /// Wide bottom Continue for stageClear — ≥56pt, not under the stick.
    private var stageContinueStrip: some View {
        MenuCapsule(
            title: "CONTINUE",
            style: .primary,
            minHeight: 56,
            sfx: sfx,
            successCue: nil, // beginStage → beginWave plays waveStart
            successHaptic: .light,
            accessibilityLabel: "Continue to next stage"
        ) {
            bridge.engine?.audio.unlock()
            bridge.engine?.continueToNextStage()
        }
        .padding(.horizontal, 24)
    }

    // MARK: Title

    /// No SwiftUI CTA on the title — the painting already carries the wordmark + yellow PRESS START.
    /// A bare canvas tap (arcade press-start) is the door: `GameCanvasView.touchesEnded` →
    /// `requestEnterMainMenu()`. This is an invisible, non-hit-testing layer that only exists so
    /// VoiceOver still has a "Start" element. Calls `enterMainMenu` only; never `startGame`.
    private func titleChrome(safe: EdgeInsets) -> some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel("Press start")
            .accessibilityHint("Opens the main menu")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                if bridge.enterMainMenu() { phase = .mainMenu }
            }
    }

    // MARK: Main menu

    /// Left third over `menuSideGradient`. Shared by menu, Options, Credits and select so the
    /// column never jumps between routes.
    private func menuColumn<Content: View>(landscape: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                content()
            }
            .frame(maxWidth: landscape ? 420 : .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.trailing, 12)
            .padding(.top, 14)
            .padding(.bottom, 12)
            Spacer(minLength: 0)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// Phone IA: four live rows + BACK. Everything "coming soon" is hidden, not greyed.
    private var mainMenuRows: some View {
        Group {
            MenuPanelHeader(eyebrow: "MENU SELECT", title: "JJ NIGHT BRAWL", titleColor: MenuTheme.pink, cyanOffset: true)
                .padding(.bottom, 14)
            MenuRow(title: "STORY MODE", hint: "Act I — JJ", style: .primary, sfx: sfx) {
                if bridge.startStoryMode() { phase = .playing }
            }
            MenuRow(title: "ENDLESS", hint: "Pick a fighter", sfx: sfx) {
                if bridge.enterEndlessCharSelect() { phase = .charSelect }
            }
            MenuRow(title: "OPTIONS", hint: "Sound · Haptics", sfx: sfx) {
                menuRoute = .options
            }
            MenuRow(title: "CREDITS", hint: "The cast", sfx: sfx) {
                menuRoute = .credits
            }
            MenuRow(title: "BACK", hint: "Title", style: .back, sfx: sfx) {
                if bridge.quitToTitle() { phase = .title }
            }
            Text("Clear the alley. Chain combos. Fill the riff meter.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
                .padding(.top, 12)
                .padding(.horizontal, 14)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Shared left-column darkening for menu + char select. Clear past ~65% width so the
    /// loop art (JJ centered, Andrew / Han center-right) is never dimmed.
    private var menuSideGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0.78), location: 0),
                .init(color: Color.black.opacity(0.55), location: 0.25),
                .init(color: Color.black.opacity(0.12), location: 0.5),
                .init(color: Color.clear, location: 0.7)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: Character select

    private var charSelectRows: some View {
        let playable = GameCanvasBridge.isPlayable(previewFighter)
        return Group {
            MenuPanelHeader(eyebrow: "ENDLESS", title: "SELECT FIGHTER")
            Text("Tap a fighter to preview. Each has their own riff.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
                .padding(.bottom, 10)

            // Each card is a still from that fighter's own hover loop, so tap → loop is continuous.
            HStack(spacing: 10) {
                fighterCard("JJ", who: "jj", asset: "select_jj")
                fighterCard("ANDREW", who: "andrew", asset: "select_andrew")
                fighterCard("HAN", who: "han", asset: "select_han")
            }
            .padding(.bottom, 8)

            // Nameplate — name only, punches in for 80ms on confirm.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(previewFighter.uppercased())
                    .font(MenuTheme.display(18, weight: .black))
                    .tracking(1.2)
                    .foregroundColor(MenuTheme.pink)
                if !playable {
                    Text("LOCKED")
                        .font(MenuTheme.display(10, weight: .bold))
                        .foregroundColor(MenuTheme.gold)
                }
            }
            .scaleEffect(nameplatePunch ? 1.06 : 1, anchor: .leading)
            .padding(.horizontal, 2)
            .padding(.bottom, 8)
            .accessibilityElement(children: .combine)

            MenuCapsule(
                title: "START BRAWL",
                style: .primary,
                enabled: playable,
                minHeight: 54,
                sfx: sfx,
                successCue: .confirm,
                successHaptic: .medium,
                accessibilityLabel: "Start brawl as \(previewFighter)"
            ) {
                confirmSelectedFighter()
            }
            .padding(.bottom, 4)

            MenuRow(title: "BACK", hint: "Main menu", style: .back, sfx: sfx) {
                if bridge.returnToMainMenu() { phase = .mainMenu }
            }
        }
    }

    private func fighterCard(_ title: String, who: String, asset: String?) -> some View {
        let selected = previewFighter == who
        let playable = GameCanvasBridge.isPlayable(who)
        return FighterCard(
            title: title,
            subtitle: playable ? nil : "LOCKED",
            asset: asset,
            selected: selected,
            locked: !playable,
            sfx: sfx
        ) {
            // uiHover once per new focus id — not per finger jitter (the card already tapped).
            guard previewFighter != who else { return }
            sfx.play(.hover)
            previewFighter = who
        }
    }

    /// uiConfirm has already played (control or key). Punch the nameplate, then enter the run.
    /// Locked fighters never get here from the strip (disabled → uiDeny); guard anyway.
    private func confirmSelectedFighter() {
        guard GameCanvasBridge.isPlayable(previewFighter) else {
            sfx.play(.deny)
            return
        }
        UserDefaults.standard.set(previewFighter, forKey: Self.lastFighterKey)
        withAnimation(.easeOut(duration: 0.08)) { nameplatePunch = true }
        let who = previewFighter
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            nameplatePunch = false
            // Bridge guards on engine phase == .charSelect, so a double-tap cannot start twice.
            if bridge.confirmCharSelect(who: who) {
                phase = .playing
            }
        }
    }
}

// MARK: - Menu / char-select loops (one visible; JJ's loop is also the menu soundtrack)

/// Four loop layers (JJ video / JJ Endless frames / Andrew / Han). Players / animators are
/// created lazily. Only the active id is visible; hover loops pause after a 160ms crossfade.
/// The JJ slot (`menu-select-loop.mp4`) carries the menu's audio track, so it keeps playing —
/// hidden — while Andrew / Han are focused and only stops when the stack is dismantled (with a
/// short fade). At most two AVPlayers play at once (JJ + one hover loop); the Andrew / Han mp4s
/// have no audio. Image sequences use UIImageView.animationImages (no second CADisplayLink).
private final class CharSelectLoopStackView: UIView {
    private struct Slot {
        let id: String
        /// mp4 resource name (nil → image-sequence slot).
        let resource: String?
        let frameAssets: [String]?
        let poster: String?
        /// True for the slot whose mp4 audio track is the menu soundtrack.
        let soundtrack: Bool
        let layer: AVPlayerLayer
        let posterView: UIImageView
        let animView: UIImageView
        var queue: AVQueuePlayer?
        var looper: AVPlayerLooper?
        var framesReady = false
    }

    private var slots: [Slot] = []
    private(set) var activeId: String = "jj"
    private static let crossfade: TimeInterval = 0.16
    private static let jjFrameDuration: TimeInterval = 0.22
    /// Soundtrack fade when the menu goes away (matches the old TDM fade).
    private static let soundtrackFade: TimeInterval = 0.25

    /// Source of truth for SOUND / MUSIC. The soundtrack player is an AVPlayer, not a node on the
    /// engine's mixer, so it reads `menuLoopGain` and follows `GameAudio.gainDidChange`.
    weak var audio: GameAudio? {
        didSet { applyGain() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .black
        clipsToBounds = true
        // Poster = frame 0 of that fighter's loop (also the Endless select card art), so the
        // poster → video / frame handoff is seamless. Main-menu JJ is menu-select-loop (with its
        // own audio track); Endless JJ uses a distinct guitar sit-loop (jj-endless).
        let specs: [(String, String?, String?, [String]?, Bool)] = [
            ("jj", "menu-select-loop", "menu_select_poster", nil, true),
            ("jj-endless", nil, "select_jj", [
                "jj_endless_loop_0", "jj_endless_loop_1", "jj_endless_loop_2", "jj_endless_loop_3"
            ], false),
            ("andrew", "andrew-hover", "select_andrew", nil, false),
            ("han", "han-hover", "select_han", nil, false),
        ]
        for (id, res, poster, frames, soundtrack) in specs {
            let posterView = UIImageView()
            posterView.contentMode = .scaleAspectFill
            posterView.clipsToBounds = true
            posterView.alpha = 0
            if let poster { posterView.image = UIImage(named: poster) }
            addSubview(posterView)

            let animView = UIImageView()
            animView.contentMode = .scaleAspectFill
            animView.clipsToBounds = true
            animView.alpha = 0
            animView.animationDuration = Self.jjFrameDuration * Double(frames?.count ?? 4)
            animView.animationRepeatCount = 0
            addSubview(animView)

            let layer = AVPlayerLayer()
            layer.videoGravity = .resizeAspectFill
            layer.opacity = 0
            self.layer.addSublayer(layer)

            slots.append(Slot(
                id: id, resource: res, frameAssets: frames, poster: poster, soundtrack: soundtrack,
                layer: layer, posterView: posterView, animView: animView,
                queue: nil, looper: nil, framesReady: false
            ))
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(gainChanged),
            name: GameAudio.gainDidChange,
            object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopAll()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for s in slots {
            s.posterView.frame = bounds
            s.animView.frame = bounds
            s.layer.frame = bounds
        }
        CATransaction.commit()
    }

    /// Focus change: 160ms crossfade, new player starts now, old one pauses after the fade.
    /// The soundtrack slot is exempt from the pause — it plays (visible or not) for the whole
    /// life of the stack.
    func setActive(_ id: String, animated: Bool = true) {
        let previous = activeId
        activeId = id
        ensureMedia(for: id)
        for s in slots where s.soundtrack && s.id != id {
            ensureMedia(for: s.id)
        }
        let dur = animated ? Self.crossfade : 0

        CATransaction.begin()
        if dur <= 0 {
            CATransaction.setDisableActions(true)
        } else {
            CATransaction.setAnimationDuration(dur)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        }
        UIView.animate(withDuration: dur) {
            for s in self.slots {
                let on = s.id == id
                let usesFrames = s.frameAssets != nil
                s.layer.opacity = (on && !usesFrames) ? 1 : 0
                s.animView.alpha = (on && usesFrames) ? 1 : 0
                // Keep poster under the video; for frame slots the anim view is the surface.
                s.posterView.alpha = on ? 1 : 0
            }
        }
        CATransaction.commit()

        for i in slots.indices where slots[i].id == id || slots[i].soundtrack {
            if slots[i].frameAssets != nil {
                slots[i].animView.startAnimating()
            } else {
                slots[i].queue?.play()
            }
        }
        if previous != id || dur <= 0 {
            let pauseOthers = { [weak self] in
                guard let self else { return }
                for i in self.slots.indices
                where self.slots[i].id != self.activeId && !self.slots[i].soundtrack {
                    self.slots[i].queue?.pause()
                    self.slots[i].animView.stopAnimating()
                }
            }
            if dur <= 0 {
                pauseOthers()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + dur, execute: pauseOthers)
            }
        }
    }

    func start() {
        setActive(activeId, animated: false)
    }

    func stopAll() {
        for i in slots.indices {
            slots[i].queue?.pause()
            slots[i].layer.player = nil
            slots[i].looper = nil
            slots[i].queue = nil
            slots[i].animView.stopAnimating()
            slots[i].animView.animationImages = nil
            slots[i].framesReady = false
        }
    }

    /// Leaving the menu: ramp the soundtrack down over `soundtrackFade`, then stop everything.
    /// The soundtrack player is handed to the ramp closure first so `deinit → stopAll` (which
    /// may run as soon as SwiftUI drops the view) cannot cut it mid-fade.
    func fadeOutAndStop() {
        for i in slots.indices where slots[i].soundtrack {
            guard let queue = slots[i].queue else { continue }
            let looper = slots[i].looper
            slots[i].queue = nil
            slots[i].looper = nil
            slots[i].layer.player = nil
            let steps = 5
            let startVol = queue.volume
            for k in 1...steps {
                let delay = Self.soundtrackFade * Double(k) / Double(steps)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    if k < steps {
                        queue.volume = startVol * Float(steps - k) / Float(steps)
                    } else {
                        queue.pause()
                        _ = looper   // keep the looper alive until the player is parked
                    }
                }
            }
        }
        stopAll()
    }

    /// Current soundtrack volume: SOUND off → 0, else MUSIC-scaled. Falls back to the persisted
    /// mute flag before the engine exists.
    private var soundtrackGain: Float {
        if let audio { return audio.menuLoopGain }
        return UserDefaults.standard.bool(forKey: GameAudio.Keys.muted) ? 0 : 1
    }

    func applyGain() {
        let gain = soundtrackGain
        for s in slots where s.soundtrack {
            s.queue?.volume = gain
        }
    }

    @objc private func gainChanged() {
        applyGain()
    }

    /// Lazily build one looping player (muted unless it is the soundtrack slot) or load the
    /// image-sequence frames.
    private func ensureMedia(for id: String) {
        guard let i = slots.firstIndex(where: { $0.id == id }) else { return }
        if let frames = slots[i].frameAssets {
            guard !slots[i].framesReady else { return }
            let images = frames.compactMap { UIImage(named: $0) }
            guard !images.isEmpty else {
                print("[JJ] endless JJ frames missing — poster only")
                return
            }
            slots[i].animView.animationImages = images
            slots[i].animView.image = images[0]
            slots[i].animView.animationDuration = Self.jjFrameDuration * Double(images.count)
            slots[i].framesReady = true
            return
        }
        guard slots[i].queue == nil, let name = slots[i].resource else { return }
        let url =
            Bundle.main.url(forResource: name, withExtension: "mp4")
            ?? Bundle.main.url(forResource: name, withExtension: "mp4", subdirectory: "Video")
        guard let url else {
            print("[JJ] menu loop missing: \(name).mp4 — poster only")
            return
        }
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        if slots[i].soundtrack {
            queue.isMuted = false
            queue.volume = soundtrackGain
        } else {
            queue.isMuted = true
        }
        let looper = AVPlayerLooper(player: queue, templateItem: item)
        slots[i].queue = queue
        slots[i].looper = looper
        slots[i].layer.player = queue
    }

    @objc private func appBackground() {
        for s in slots {
            s.queue?.pause()
            s.animView.stopAnimating()
        }
    }

    @objc private func appForeground() {
        setActive(activeId, animated: false)
    }
}

private struct CharSelectLoopStack: UIViewRepresentable {
    var activeId: String
    /// Engine audio (SOUND / MUSIC source for the soundtrack slot). Optional: the stack only
    /// mounts after assets load, by which point the engine exists.
    var audio: GameAudio?

    func makeUIView(context: Context) -> CharSelectLoopStackView {
        let v = CharSelectLoopStackView()
        v.audio = audio
        v.setActive(activeId, animated: false)
        return v
    }

    func updateUIView(_ uiView: CharSelectLoopStackView, context: Context) {
        if uiView.audio == nil, let audio {
            uiView.audio = audio
        }
        // Only on a real focus change — SwiftUI re-runs this on every body evaluation.
        if uiView.activeId != activeId {
            uiView.setActive(activeId)
        }
    }

    static func dismantleUIView(_ uiView: CharSelectLoopStackView, coordinator: ()) {
        uiView.fadeOutAndStop()
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
    var onMove: (_ x: CGFloat, _ y: CGFloat) -> Void
    var onClearMove: () -> Void
    var onSprint: (_ down: Bool) -> Void = { _ in }
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
                HoldPadButton(title: "SPRINT", color: Color(red: 0.95, green: 0.45, blue: 0.12), minW: 72, minH: 56, onDown: { onSprint(true) }, onUp: { onSprint(false) })
                ActionPadButton(
                    title: "RIFF",
                    color: specialReady
                        ? Color(red: 0.18, green: 0.89, blue: 0.9)
                        : Color(red: 0.18, green: 0.89, blue: 0.9).opacity(0.4),
                    minW: 72,
                    minH: 56
                ) {
                    onAction(.riff)
                }
                if hasGun {
                    ActionPadButton(
                        title: "GUN",
                        color: Color(red: 1, green: 0.9, blue: 0.4),
                        minW: 72,
                        minH: 56
                    ) {
                        onAction(.gun)
                    }
                }
            }
            // One-handed right-thumb cluster: kick / jump / punch
            HStack(spacing: 10) {
                ActionPadButton(title: "KICK", color: Color(white: 0.4), minW: 80, minH: 64) {
                    onAction(.kick)
                }
                ActionPadButton(title: "JUMP", color: Color(white: 0.35), minW: 72, minH: 64) {
                    onAction(.jump)
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
    var onMove: (_ x: CGFloat, _ y: CGFloat) -> Void
    var onClear: () -> Void

    @State private var knob: CGSize = .zero
    @State private var dragging = false

    private let radius: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            let mid = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
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
                    .offset(y: min(geo.size.height / 2 - 8, 58))
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragging = true
                        // Finger location relative to pad center (not DragGesture.translation).
                        let raw = CGSize(
                            width: value.location.x - mid.x,
                            height: value.location.y - mid.y
                        )
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
        }
        .accessibilityLabel("Move stick")
    }

    private func apply(_ o: CGSize) {
        // Normalize to -1...1 from stick radius; dead zone / shaping live in the engine.
        let x = max(-1, min(1, o.width / radius))
        let y = max(-1, min(1, o.height / radius))
        onMove(x, y)
    }
}


// MARK: - Buttons

/// Hold-to-sprint (not fire-on-press — release must clear the key).
private struct HoldPadButton: View {
    var title: String
    var color: Color
    var minW: CGFloat = 72
    var minH: CGFloat = 56
    var onDown: () -> Void
    var onUp: () -> Void

    @State private var pressed = false

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(.white)
            .frame(minWidth: minW, minHeight: max(minH, 44))
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
                            onDown()
                        }
                    }
                    .onEnded { _ in
                        if pressed {
                            pressed = false
                            onUp()
                        }
                    }
            )
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

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
            .frame(minWidth: minW, minHeight: max(minH, 44))
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
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .padding(.vertical, 8)
                .background(color)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
