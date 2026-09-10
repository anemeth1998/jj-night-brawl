import Foundation
import CoreGraphics

/// Core beat-em-up simulation — ported from the web engine.
final class GameEngine {
    static let viewW: CGFloat = 960
    static let viewH: CGFloat = 540

    private let laneTop: CGFloat = 310
    private let laneBottom: CGFloat = 500
    private let stageWidth: CGFloat = 2800

    private let playerSpeed: CGFloat = 210
    private let playerSprintMul: CGFloat = 1.55
    private let playerDepthSpeed: CGFloat = 135
    private let enemySpeed: CGFloat = 95
    private let enemyDepthSpeed: CGFloat = 70

    /// Ground accel / decel toward target velocity (units/sec^2).
    private let playerAccel: CGFloat = 2200
    private let playerDecel: CGFloat = 2800
    private let playerAirAccel: CGFloat = 1400

    private let jumpVel: CGFloat = 480
    private let jumpBuffer: CGFloat = 0.14
    private let gravity: CGFloat = 1650
    private let airControl: CGFloat = 0.78

    private let playerWalkFps: CGFloat = 12
    /// Unique cells in the JJ run sheet. 8 = atlas fallback; 16 after the movie bake.
    var playerRunFrames: Int = 8
    /// Frames in the selected fighter's riff sheet (JJ 8-frame 4×2, Andrew / Han 4-frame 2×2).
    /// Injected by the view each tick so the special anim spreads across the whole sheet.
    var playerSpecialFrames: Int = 4
    /// Hold a ~0.5s gait so extra in-betweens smooth the sprint instead of slowing it.
    private var playerRunFps: CGFloat { max(12, CGFloat(max(1, playerRunFrames)) * 2) }
    private let enemyWalkFps: CGFloat = 8
    /// Uneven idle holds (seconds). Frame 0 = rest pose — longer than the twitch frames.
    private let playerIdleHolds: [CGFloat] = [0.40, 0.16, 0.18, 0.14]
    private let enemyIdleHolds: [CGFloat] = [0.28, 0.14, 0.16, 0.14]

    private let attackDuration: [AttackKind: CGFloat] = [
        .punch: 0.30, .kick: 0.44, .special: 0.95, .gun: 0.42
    ]
    private let attackActive: [AttackKind: (CGFloat, CGFloat)] = [
        .punch: (0.08, 0.22), .kick: (0.14, 0.34), .special: (0.18, 0.82), .gun: (0.08, 0.22)
    ]
    private let gunDamage: CGFloat = 28
    private let gunBulletSpeed: CGFloat = 720
    private let gunBulletLife: CGFloat = 0.55
    private let gangViolenceLine = "Counting or not counting gang violence?"
    private let gangLineLife: CGFloat = 3.4

    private let riffRadiusMin: CGFloat = 90
    private let riffRadiusMax: CGFloat = 210
    private let riffDamage: CGFloat = 22
    private let riffKnock: CGFloat = 340
    private let hurtDuration: CGFloat = 0.35
    private let invulnAfterHit: CGFloat = 0.42
    private let comboWindow: CGFloat = 0.85
    private let speechBubbleLife: CGFloat = 1.15
    private let waveClearDuration: CGFloat = 3.2
    private let smokeFrameFps: CGFloat = 2.2

    /// JJ is the only smoker. Andrew / Han stand through the same intermission — no cig
    /// particles, no `jj_smoke` pose, no smokeBreak / exhale SFX. Phase + Continue flow unchanged.
    private var playerSmokes: Bool { state.selectedFighter.lowercased() == "jj" }

    private let punkSlogans = [
        "FUCK YEAH!", "EAT SHIT BOOTLICKERS!", "NOT MY PRESIDENT!",
        "EAT THE RICH!", "NO GODS NO MASTERS!", "SMASH THE STATE!",
        "DIE YUPPIE SCUM!", "THIS MACHINE KILLS FASCISTS!", "PUNKS NOT DEAD!",
        "BURN IT DOWN!", "ACAB!", "CLASS WAR NOW!", "NO FUTURE? MAKE ONE!",
        "SCREW YOUR SUIT!", "RIFF OR DIE!"
    ]
    /// Andrew's riff bubbles — hacker jargon, slogans, and Seattle grunge riffs.
    /// Keep under ~30 chars so the bubble wraps to two lines at most.
    private let andrewSlogans = [
        "SUDO RM -RF YOUR SUIT!", "SEGFAULT, SUIT!", "KERNEL PANIC!",
        "404: MERCY NOT FOUND", "GIT PUSH --FORCE!", "ROOT ACCESS GRANTED!",
        "STACK OVERFLOW!", "CTRL+ALT+DEFEAT!", "ZERO DAY, ZERO MERCY!",
        "BUFFER OVERFLOW!", "DDOS THIS, SUIT!", "IT WORKS ON MY MACHINE!",
        "HAVE YOU TRIED REBOOTING?", "ENCRYPT EVERYTHING!",
        "OPEN SOURCE, CLOSED FIST!", "TABS > SPACES > SUITS!",
        "SMELLS LIKE ROOT ACCESS!", "COME AS YOU ARE, LEAVE AS SUDO",
        "NEVERMIND YOUR FIREWALL!", "FLANNEL & FIREWALLS!",
        "SUB POP > YOUR STOCK!", "GRUNGE NEVER DIED!", "SEATTLE SOUND, SUIT!",
        "TOUCH ME I'M SUDO!", "EVEN FLOW, NO FLOW CONTROL!",
        "HERE WE ARE NOW, DEPLOY US!"
    ]
    /// Han's riff bubbles — Danganronpa / Yuri on Ice / otaku / night-shift nurse / cat beanie.
    /// Keep under ~30 chars so the bubble wraps to two lines at most.
    private let hanSlogans = [
        // Danganronpa
        "IT'S PUNISHMENT TIME!", "DESPAIR? TRY MY RIFF!", "ULTIMATE NURSE, ULTIMATE RIFF!",
        "HOPE'S PEAK THIS, SUIT!", "NO OBJECTION? OBJECTION!", "UPUPUPU... GET WRECKED!",
        // Yuri on Ice
        "SKATE OR DIE!", "HISTORY MAKER!", "ICE IN MY VEINS!", "YURI!!! ON ICE!!!",
        "QUAD FLIP TO YOUR FACE!", "BORN TO MAKE HISTORY!",
        // Anime / otaku
        "NANI?!", "PLUS ULTRA RIFF!", "SENPAI NOTICED MY RIFF!", "ANIME WAS RIGHT!",
        "WAIFU RIGHTS!", "OTAKU POWER!", "OMAE WA MOU SHINDEIRU!", "THIS ISN'T EVEN MY FINAL FORM!",
        // Night-shift nurse
        "VITALS: CRITICAL!", "CODE BLUE, SUIT!", "NURSE'S ORDERS!", "IV DRIP OF JUSTICE!",
        "BEDSIDE MANNER: FISTS!", "STAT! RIFF STAT!", "TAKE TWO AND SHUT UP!",
        // Character
        "CAT EARS, CLAWS OUT!", "BEANIE JUSTICE!", "PHONE DOWN, FISTS UP!", "BRB, WRECKING YOU!"
    ]

    private var nextId = 1
    let audio = GameAudio()
    private(set) var state: GameState

    init() {
        state = GameState(player: GameEngine.makeBlankPlayer(id: 0))
        resetToTitle()
    }

    // MARK: - Lifecycle

    func resetToTitle() {
        nextId = 1
        state = GameState(player: makePlayer())
        state.phase = .title
        state.stageWidth = stageWidth
        flushInput()
    }

    // Menu navigation is silent at the engine level — the SwiftUI control that was pressed owns
    // uiTap / uiBack / uiConfirm (see MenuSFX). Playing here too was the double-beep bug.

    /// Title → main menu (Story / Endless / …). Not char select.
    func enterMainMenu() {
        flushInput()
        state.phase = .mainMenu
        state.message = "MAIN MENU"
        state.messageSubtitle = "Story Mode · Endless"
        state.messageTimer = 1.6
    }

    /// Story Mode: Act I campaign, JJ only — no character card wall.
    func startStoryMode() {
        flushInput()
        state.playMode = .story
        state.selectedFighter = "jj"
        startGame()
    }

    /// Endless → character select cards only.
    func enterEndlessCharSelect() {
        flushInput()
        state.playMode = .endless
        state.phase = .charSelect
        state.message = "SELECT FIGHTER"
        state.messageSubtitle = "Endless — pick a fighter"
        state.messageTimer = 2.0
    }

    /// Legacy name — routes to main menu (cards are Endless-only).
    func enterCharSelect() {
        enterMainMenu()
    }

    /// Confirm Endless pick and start brawl with that fighter's own sheets.
    func confirmCharSelect(who: String) {
        flushInput()
        state.playMode = .endless
        state.selectedFighter = who
        startGame()
    }

    func startGame() {
        nextId = 1
        let pick = state.selectedFighter
        let mode = state.playMode
        state = GameState(player: makePlayer())
        state.selectedFighter = pick.isEmpty ? "jj" : pick
        state.playMode = mode
        state.phase = .playing
        state.stageWidth = stageWidth
        // Bradford: never inherit title/select stick/queue into Act I.
        flushInput()
        // No uiConfirm here: the STORY / START BRAWL / RETRY control already played it.
        // waveStart stays inside beginStage → beginWave.
        beginStage(0)
    }


    /// Char select / sub-screens → main menu.
    func returnToMainMenu() {
        flushInput()
        state.phase = .mainMenu
        state.message = "MAIN MENU"
        state.messageSubtitle = "Story Mode · Endless"
        state.messageTimer = 1.2
    }

    /// Quit any menu surface → title (does not exit the app process).
    func quitToTitle() {
        flushInput()
        resetToTitle()
    }

    /// UI / Canvas: Continue after stageClear (own ≥44pt target, not under stick).
    func continueToNextStage() {
        guard state.phase == .stageClear else { return }
        advanceStage()
    }

    func togglePause() {
        if state.phase == .playing {
            state.phase = .paused
            flushInput() // drop held sprint so Home/pause can't stick .run
            audio.pause()
        } else if state.phase == .paused {
            state.phase = .playing
            audio.resume()
        }
    }

    // MARK: - Input

    func setKey(_ code: String, down: Bool) {
        if down {
            state.keys.insert(code)
            switch code {
            case "punch": queueAction(.punch)
            case "kick": queueAction(.kick)
            case "special": queueAction(.special)
            case "gun": queueAction(.gun)
            case "jump": queueJump()
            default: break
            }
        } else {
            state.keys.remove(code)
        }
    }

    func setTouch(left: Bool? = nil, right: Bool? = nil, up: Bool? = nil, down: Bool? = nil) {
        if let left { state.touch.left = left }
        if let right { state.touch.right = right }
        if let up { state.touch.up = up }
        if let down { state.touch.down = down }
        // Mirror digital pad into axes when no analog stream is driving movement.
        if abs(state.touch.axisX) < 0.01 && abs(state.touch.axisY) < 0.01 {
            var mx: CGFloat = 0
            var my: CGFloat = 0
            if state.touch.left { mx -= 1 }
            if state.touch.right { mx += 1 }
            if state.touch.up { my -= 1 }
            if state.touch.down { my += 1 }
            if mx != 0 && my != 0 {
                let inv = 1 / sqrt(2.0 as CGFloat)
                mx *= inv; my *= inv
            }
            state.touch.axisX = mx
            state.touch.axisY = my
        }
    }

    /// Analog move input from the virtual stick, axes in -1...1.
    func setMoveAxis(x: CGFloat, y: CGFloat) {
        let nx = max(-1, min(1, x))
        let ny = max(-1, min(1, y))
        state.touch.axisX = nx
        state.touch.axisY = ny
        state.touch.left = nx < -0.25
        state.touch.right = nx > 0.25
        state.touch.up = ny < -0.25
        state.touch.down = ny > 0.25
    }

    /// Release all virtual-stick / d-pad directions (call on finger-up or phase change).
    func clearTouch() {
        state.touch = TouchState()
    }

    func queueAction(_ kind: AttackKind) {
        guard state.phase == .playing else { return }
        state.actionQueue = [kind]
    }

    func queueJump() {
        guard state.phase == .playing else { return }
        state.jumpQueued = true
        state.jumpBufferTimer = jumpBuffer
    }

    // MARK: - Update

    func update(dt rawDt: CGFloat) {
        let dt = min(max(rawDt, 0), 0.05)
        state.elapsed += dt

        if state.phase == .title || state.phase == .mainMenu || state.phase == .charSelect
            || state.phase == .paused || state.phase == .gameover {
            return
        }

        if state.phase == .loading {
            state.loadingTimer -= dt
            if state.loadingTimer <= 0 {
                finishLoading()
            }
            return
        }

        if state.phase == .victory {
            updateVictory(dt)
            return
        }

        if state.hitStop > 0 {
            state.hitStop -= dt
            return
        }

        if state.messageTimer > 0 { state.messageTimer -= dt }
        if state.shake > 0 { state.shake = max(0, state.shake - dt * 28) }

        if state.phase == .waveClear || state.phase == .stageClear {
            updateSmokeBreak(dt)
            state.enemies = state.enemies.filter { !($0.dead && $0.deathTimer <= 0) }
            for i in state.enemies.indices where state.enemies[i].dead {
                state.enemies[i].deathTimer -= dt
            }
            updateParticles(dt)
            followCamera(dt, lag: 4)
            if state.phase == .stageClear {
                if pressed("continue") || pressed("start") || pressed("confirm") {
                    state.keys.remove("continue")
                    state.keys.remove("start")
                    state.keys.remove("confirm")
                    advanceStage()
                }
                return
            }
        } else {
            updatePlayer(dt)
            // Snapshot count — enemies are only appended in updateSpawns after this loop.
            let enemyCount = state.enemies.count
            for i in 0..<enemyCount {
                updateEnemy(i, dt: dt)
            }
            state.enemies = state.enemies.filter { !($0.dead && $0.deathTimer <= 0) }
            updateSpawns(dt)
            updateBullets(dt)
            updateParticles(dt)
            followCamera(dt, lag: 6)
        }

        // Wave complete?
        if state.phase == .playing,
           state.spawnQueue <= 0,
           state.enemies.isEmpty,
           state.waveEnemiesLeft <= 0 {
            if state.wave >= state.maxWaves {
                beginStageClear()
            } else {
                state.phase = .waveClear
                beginSmokeBreak(playerSmokes ? "WAVE CLEAR — SMOKE BREAK" : "WAVE CLEAR — BREATHER",
                                duration: waveClearDuration)
                audio.waveClear()
            }
        }

        if state.phase == .waveClear && state.messageTimer <= 0 {
            state.player.anim = .idle
            state.player.animTime = 0
            state.player.animFrame = 0
            state.phase = .playing
            beginWave(state.wave + 1)
        }

    }

    // MARK: - Factories

    private static func makeBlankPlayer(id: Int) -> Fighter {
        Fighter(
            id: id, kind: .player, enemyType: nil,
            x: 220, y: 400, z: 0, zVel: 0, vx: 0, vy: 0, facing: 1,
            hp: 100, maxHp: 100, anim: .idle, animTime: 0, animFrame: 0,
            attackTimer: 0, attackActive: false, attackHit: false, attackKind: nil,
            specialHitIds: [], hurtTimer: 0, invulnTimer: 0, combo: 0, comboTimer: 0,
            dead: false, deathTimer: 0, aiCooldown: 0, flash: 0, scoreValue: 0,
            scale: 1.7, bodyW: 36, bodyH: 78
        )
    }

    private func makePlayer() -> Fighter {
        let p = GameEngine.makeBlankPlayer(id: nextId)
        nextId += 1
        return p
    }

    private func makeEnemy(
        x: CGFloat,
        y: CGFloat,
        wave: Int,
        type: EnemyType,
        elite: Bool = false
    ) -> Fighter {
        let typeMul: CGFloat = type == .biz ? 1.1 : type == .maga ? 1.05 : 0.95
        let eliteMul: CGFloat = elite ? 2.2 : 1.0
        let hp = round((28 + CGFloat(wave) * 8) * typeMul * state.waveHpScale * eliteMul)
        var scale: CGFloat = type == .gothf ? 1.4 : type == .biz ? 1.5 : 1.48
        if elite { scale *= 1.12 }
        let tele = state.waveTelegraphMul * (elite ? 1.4 : 1.0)
        let f = Fighter(
            id: nextId, kind: .enemy, enemyType: type,
            x: x, y: y, z: 0, zVel: 0, vx: 0, vy: 0, facing: -1,
            hp: hp, maxHp: hp, anim: .idle, animTime: 0, animFrame: 0,
            attackTimer: 0, attackActive: false, attackHit: false, attackKind: nil,
            specialHitIds: [], hurtTimer: 0, invulnTimer: 0, combo: 0, comboTimer: 0,
            dead: false, deathTimer: 0,
            aiCooldown: (0.4 + CGFloat.random(in: 0...0.6)) * tele,
            flash: 0,
            scoreValue: 100 + wave * 40 + (type == .biz ? 20 : 0) + (elite ? 80 : 0),
            scale: scale, bodyW: 40, bodyH: 78,
            isElite: elite, telegraphMul: tele
        )
        nextId += 1
        return f
    }

    private func beginStage(_ index: Int) {
        guard let stage = CampaignData.stage(at: index) else {
            state.phase = .victory
            beginSmokeBreak("STREET CLEARED", duration: 99)
            state.player.anim = .victory
            state.player.animTime = 0
            state.player.animFrame = 0
            audio.victory()
            return
        }
        state.stageIndex = index
        state.actIndex = stage.act
        state.stageName = stage.name
        state.maxWaves = stage.waves.count
        state.zineText = ""
        flushInput()
        beginWave(1)
    }

    private func beginWave(_ wave: Int) {
        guard let stage = CampaignData.stage(at: state.stageIndex),
              stage.waves.indices.contains(wave - 1) else { return }
        let def = stage.waves[wave - 1]
        state.wave = wave
        state.enemies = []
        state.bullets = []
        state.pendingSpawns = def.spawnList()
        let count = def.totalCount
        state.waveEnemiesLeft = count
        state.spawnQueue = count
        state.spawnTimer = 0.35
        state.waveHpScale = def.hpScale
        state.waveTelegraphMul = def.telegraphMul
        state.message = def.banner
        state.messageSubtitle = def.subtitle
        state.messageTimer = 1.6
        audio.waveStart(wave)
    }

    private func beginStageClear() {
        guard let stage = CampaignData.stage(at: state.stageIndex) else { return }
        applyUnlocks(stage.unlocksOnClear)
        flushInput()
        if stage.isFinale {
            state.phase = .victory
            beginSmokeBreak("STREET CLEARED", duration: 99)
            state.player.anim = .victory
            state.player.animTime = 0
            state.player.animFrame = 0
            audio.victory()
            return
        }
        state.phase = .stageClear
        state.zineText = stage.zineLines.joined(separator: "\n")
        let title = state.unlockFlags.contains(.hasGun) && stage.unlocksOnClear.contains(.hasGun)
            ? "PACKIN' HEAT — CONTINUE"
            : "STAGE CLEAR — CONTINUE"
        beginSmokeBreak(title, duration: 99)
        state.messageSubtitle = stage.zineLines.first ?? ""
        audio.waveClear()
    }

    private func advanceStage() {
        flushInput()
        let next = state.stageIndex + 1
        state.zineText = ""
        state.messageSubtitle = ""
        state.player.anim = .idle
        state.player.animTime = 0
        state.player.animFrame = 0
        // Hold on the run clip so the next stage's maps can warm without a black flash.
        state.pendingStageIndex = next
        state.loadingTimer = 1.85
        if let stage = CampaignData.stage(at: next) {
            state.stageName = stage.name
            state.message = stage.name.uppercased()
        } else {
            state.message = "NEXT STREET"
        }
        state.messageTimer = 2.0
        state.phase = .loading
    }

    /// Finish the between-stage hold and enter the pending stage (or victory if none).
    private func finishLoading() {
        let next = state.pendingStageIndex ?? (state.stageIndex + 1)
        state.pendingStageIndex = nil
        state.loadingTimer = 0
        state.phase = .playing
        state.player.anim = .idle
        state.player.animTime = 0
        state.player.animFrame = 0
        beginStage(next)
    }

    private func applyUnlocks(_ flags: [UnlockFlag]) {
        for flag in flags {
            state.unlockFlags.insert(flag)
            if flag == .hasGun {
                state.hasGun = true
                state.message = "GUN UNLOCKED — PACKIN' HEAT"
                state.messageTimer = 2.2
                audio.uiConfirm()
            }
        }
    }

    /// Bradford: never carry stick/queue/jump buffer across smoke/zine/stage.
    func flushInput() {
        state.keys.removeAll()
        state.touch = TouchState()
        state.actionQueue = []
        state.jumpQueued = false
        state.jumpBufferTimer = 0
    }

    // MARK: - Helpers

    private func grounded(_ f: Fighter) -> Bool {
        f.z <= 0.5 && f.zVel <= 0
    }

    private func canAct(_ f: Fighter) -> Bool {
        !f.dead && f.hurtTimer <= 0 && f.attackTimer <= 0
    }

    private func canAttack(_ f: Fighter) -> Bool {
        !f.dead && f.hurtTimer <= 0 && f.attackTimer <= 0
    }

    private func pressed(_ code: String) -> Bool {
        state.keys.contains(code)
    }

    private func moveAxis() -> (CGFloat, CGFloat) {
        // Keyboard digital input wins when held; otherwise use analog stick axes.
        var mx: CGFloat = 0
        var my: CGFloat = 0
        var digital = false
        if pressed("left") { mx -= 1; digital = true }
        if pressed("right") { mx += 1; digital = true }
        if pressed("up") { my -= 1; digital = true }
        if pressed("down") { my += 1; digital = true }
        if digital {
            if mx != 0 && my != 0 {
                let inv = 1 / sqrt(2.0 as CGFloat)
                mx *= inv; my *= inv
            }
            return (mx, my)
        }
        mx = state.touch.axisX
        my = state.touch.axisY
        let mag = sqrt(mx * mx + my * my)
        if mag < 0.08 {
            return (0, 0)
        }
        // Soft radial response: crawl near center, full speed at the rim.
        let shaped = min(1, (mag - 0.08) / 0.92)
        let gain = shaped * shaped * (3 - 2 * shaped) // smoothstep
        return (mx / mag * gain, my / mag * gain)
    }

    private func approach(_ current: CGFloat, _ target: CGFloat, _ rate: CGFloat, _ dt: CGFloat) -> CGFloat {
        let delta = target - current
        let maxStep = rate * dt
        if abs(delta) <= maxStep { return target }
        return current + (delta > 0 ? maxStep : -maxStep)
    }

    private func followCamera(_ dt: CGFloat, lag: CGFloat) {
        let target = state.player.x - Self.viewW * 0.38
        state.cameraX += (target - state.cameraX) * min(1, dt * lag)
        state.cameraX = max(0, min(stageWidth - Self.viewW, state.cameraX))
    }

    // MARK: - Attacks

    private func startAttack(_ kind: AttackKind, on index: FighterIndex) {
        switch index {
        case .player:
            mutatePlayer { f in
                applyStartAttack(&f, kind: kind, isPlayer: true)
            }
            if kind == .special {
                spawnPunkBubble()
            }
        case .enemy(let i):
            guard state.enemies.indices.contains(i) else { return }
            applyStartAttack(&state.enemies[i], kind: kind, isPlayer: false)
        }
    }

    private func applyStartAttack(_ f: inout Fighter, kind: AttackKind, isPlayer: Bool) {
        f.attackKind = kind
        f.attackTimer = attackDuration[kind] ?? 0.4
        f.attackActive = false
        f.attackHit = false
        f.specialHitIds = []
        f.anim = .attack
        f.animTime = 0
        f.animFrame = 0
        if kind == .special {
            f.vx = 0; f.vy = 0
            f.invulnTimer = max(f.invulnTimer, (attackDuration[.special] ?? 0.95) * 0.85)
        } else if kind == .gun {
            f.vy = 0
            f.vx = -f.facing * 40
        } else if grounded(f) {
            f.vy = 0
            f.vx = f.facing * (kind == .kick ? 220 : 140)
        } else {
            f.vx *= 0.85
        }
        switch kind {
        case .kick: audio.kick(player: isPlayer)
        case .special: audio.special(player: isPlayer)
        case .gun: audio.gunshot()
        case .punch: audio.punch(player: isPlayer)
        }
    }

    private func spawnBullet(from f: Fighter) {
        let muzzleX = f.x + f.facing * 36
        let muzzleY = f.y - f.bodyH * f.scale * 0.55 - f.z
        state.bullets.append(Bullet(
            x: muzzleX, y: f.y, z: f.z + f.bodyH * f.scale * 0.45,
            vx: f.facing * gunBulletSpeed, facing: f.facing,
            life: gunBulletLife, damage: gunDamage, hitIds: []
        ))
        state.particles.append(Particle(
            x: muzzleX, y: muzzleY, vx: f.facing * 20, vy: -10,
            life: 0.12, maxLife: 0.12, frame: 0, kind: .muzzle,
            radius: 14, colorHex: "#ffe566"
        ))
        state.shake = min(10, state.shake + 3)
    }

    private func spawnGangViolenceLine() {
        state.speechBubble = SpeechBubble(
            text: gangViolenceLine, life: gangLineLife, maxLife: gangLineLife
        )
    }

    private func spawnPunkBubble() {
        let slogan: String
        switch state.selectedFighter.lowercased() {
        case "han":
            slogan = hanSlogans.randomElement() ?? "NANI?!"
        case "andrew":
            slogan = andrewSlogans.randomElement() ?? "SEGFAULT!"
        default:
            slogan = punkSlogans.randomElement() ?? "FUCK YEAH!"
        }
        state.speechBubble = SpeechBubble(text: slogan, life: speechBubbleLife, maxLife: speechBubbleLife)
    }

    private func tryJump(_ f: inout Fighter) -> Bool {
        guard grounded(f), !f.dead, f.hurtTimer <= 0 else { return false }
        f.zVel = jumpVel
        f.z = 1
        f.anim = .jump
        f.animTime = 0
        f.animFrame = 1
        audio.jump()
        return true
    }

    private func updatePhysics(_ f: inout Fighter, dt: CGFloat, isPlayer: Bool) {
        if !grounded(f) || f.zVel > 0 {
            f.zVel -= gravity * dt
            f.z += f.zVel * dt
            if f.z <= 0 {
                f.z = 0
                f.zVel = 0
                if isPlayer && f.attackTimer <= 0 && f.hurtTimer <= 0 {
                    audio.land()
                }
            }
        } else {
            f.z = 0
            f.zVel = 0
        }
    }

    private func clampFighter(_ f: inout Fighter) {
        f.x = max(60, min(stageWidth - 60, f.x))
        f.y = max(laneTop, min(laneBottom, f.y))
    }

    // MARK: - Player

    private enum FighterIndex {
        case player
        case enemy(Int)
    }

    private func mutatePlayer(_ body: (inout Fighter) -> Void) {
        body(&state.player)
    }

    private func updatePlayer(_ dt: CGFloat) {
        if state.player.dead {
            state.player.deathTimer -= dt
            updatePhysics(&state.player, dt: dt, isPlayer: true)
            updateFighterAnim(&state.player, dt: dt, moving: false, walkFrames: 8, walkFps: playerWalkFps)
            if state.player.deathTimer <= 0 {
                if state.phase != .gameover { audio.gameOver() }
                state.phase = .gameover
            }
            return
        }

        if state.player.hurtTimer > 0 { state.player.hurtTimer -= dt }
        if state.player.invulnTimer > 0 { state.player.invulnTimer -= dt }
        if state.player.comboTimer > 0 {
            state.player.comboTimer -= dt
            if state.player.comboTimer <= 0 { state.player.combo = 0 }
        }
        if state.player.flash > 0 { state.player.flash -= dt }

        updateAttackPlayer(dt)

        if state.jumpQueued && state.jumpBufferTimer > 0 {
            if tryJump(&state.player) {
                state.jumpQueued = false
                state.jumpBufferTimer = 0
            }
        } else if grounded(state.player) && pressed("jump") {
            if tryJump(&state.player) {
                state.keys.remove("jump")
            }
        }

        if state.jumpBufferTimer > 0 {
            state.jumpBufferTimer -= dt
            if state.jumpBufferTimer <= 0 {
                state.jumpBufferTimer = 0
                state.jumpQueued = false
            }
        }

        var moving = false
        let air = !grounded(state.player)
        let (mx, my) = moveAxis()

        if canAct(state.player) || (air && state.player.attackTimer <= 0 && state.player.hurtTimer <= 0) {
            let sprinting = !air && pressed("sprint") && (abs(mx) + abs(my) > 0.2)
            let speedMul: CGFloat = air ? airControl : (sprinting ? playerSprintMul : 1)
            if state.player.attackTimer <= 0 {
                let targetVX = mx * playerSpeed * speedMul
                let targetVY: CGFloat = air ? 0 : my * playerDepthSpeed
                let accel = air ? playerAirAccel : playerAccel
                let decel = air ? playerAirAccel : playerDecel
                let sameDirX = (targetVX > 0) == (state.player.vx > 0) || state.player.vx == 0
                let sameDirY = (targetVY > 0) == (state.player.vy > 0) || state.player.vy == 0
                let rateX = (abs(targetVX) > abs(state.player.vx) || (targetVX != 0 && sameDirX)) ? accel : decel
                let rateY = (abs(targetVY) > abs(state.player.vy) || (targetVY != 0 && sameDirY)) ? accel : decel
                let turnX = !air && targetVX != 0 && state.player.vx != 0 && ((targetVX > 0) != (state.player.vx > 0))
                let turnY = !air && targetVY != 0 && state.player.vy != 0 && ((targetVY > 0) != (state.player.vy > 0))
                state.player.vx = approach(state.player.vx, targetVX, turnX ? decel * 1.35 : rateX, dt)
                state.player.vy = approach(state.player.vy, targetVY, turnY ? decel * 1.35 : rateY, dt)
                // Facing only flips past a real intent threshold (avoids stick jitter).
                if mx > 0.2 { state.player.facing = 1 }
                else if mx < -0.2 { state.player.facing = -1 }
                let speed2 = state.player.vx * state.player.vx + state.player.vy * state.player.vy
                moving = !air && speed2 > 30 * 30
            }
            consumePlayerAction()
        } else if state.player.attackTimer <= 0 && grounded(state.player) {
            state.player.vx = approach(state.player.vx, 0, playerDecel, dt)
            state.player.vy = approach(state.player.vy, 0, playerDecel, dt)
        }

        state.player.x += state.player.vx * dt
        state.player.y += state.player.vy * dt
        updatePhysics(&state.player, dt: dt, isPlayer: true)
        clampFighter(&state.player)
        updateFighterAnim(
            &state.player, dt: dt,
            moving: moving && canAct(state.player) && grounded(state.player),
            walkFrames: 8, walkFps: playerWalkFps
        )
    }

    private func consumePlayerAction() {
        guard canAttack(state.player) else { return }
        while !state.actionQueue.isEmpty {
            let kind = state.actionQueue.removeFirst()
            if kind == .special {
                if state.specialMeter < 40 { continue }
                if !grounded(state.player) { continue }
                state.specialMeter -= 40
            }
            if kind == .gun && !state.hasGun { continue }
            startAttack(kind, on: .player)
            return
        }
        if state.hasGun && pressed("gun") {
            startAttack(.gun, on: .player)
            state.keys.remove("gun")
        } else if pressed("punch") {
            startAttack(.punch, on: .player)
            state.keys.remove("punch")
        } else if pressed("kick") {
            startAttack(.kick, on: .player)
            state.keys.remove("kick")
        } else if grounded(state.player) && pressed("special") && state.specialMeter >= 40 {
            state.specialMeter -= 40
            startAttack(.special, on: .player)
            state.keys.remove("special")
        }
    }

    // MARK: - Enemy AI

    private func updateEnemy(_ i: Int, dt: CGFloat) {
        guard state.enemies.indices.contains(i) else { return }
        if state.enemies[i].dead {
            state.enemies[i].deathTimer -= dt
            updatePhysics(&state.enemies[i], dt: dt, isPlayer: false)
            updateFighterAnim(&state.enemies[i], dt: dt, moving: false, walkFrames: 4, walkFps: enemyWalkFps)
            return
        }
        if state.enemies[i].hurtTimer > 0 { state.enemies[i].hurtTimer -= dt }
        if state.enemies[i].invulnTimer > 0 { state.enemies[i].invulnTimer -= dt }
        if state.enemies[i].flash > 0 { state.enemies[i].flash -= dt }

        updateAttackEnemy(i, dt: dt)

        let p = state.player
        var moving = false
        if canAct(state.enemies[i]) && !p.dead {
            state.enemies[i].aiCooldown -= dt
            let dx = p.x - state.enemies[i].x
            let dy = p.y - state.enemies[i].y
            state.enemies[i].facing = dx >= 0 ? 1 : -1
            let distX = abs(dx)
            let distY = abs(dy)
            if distX > 50 || distY > 22 {
                let nx: CGFloat = dx == 0 ? 0 : dx / distX
                let ny: CGFloat = dy == 0 ? 0 : dy / abs(dy)
                state.enemies[i].vx = nx * enemySpeed * (0.85 + CGFloat.random(in: 0...0.2))
                state.enemies[i].vy = ny * enemyDepthSpeed
                moving = true
            } else {
                state.enemies[i].vx = 0
                state.enemies[i].vy = 0
                if state.enemies[i].aiCooldown <= 0 {
                    startAttack(CGFloat.random(in: 0...1) < 0.4 ? .kick : .punch, on: .enemy(i))
                    let tele = max(0.8, state.enemies[i].telegraphMul)
                    state.enemies[i].aiCooldown = (0.7 + CGFloat.random(in: 0...0.9)) * tele
                }
            }
        } else if state.enemies[i].attackTimer <= 0 {
            state.enemies[i].vx *= pow(0.05, dt)
        }

        state.enemies[i].x += state.enemies[i].vx * dt
        state.enemies[i].y += state.enemies[i].vy * dt
        updatePhysics(&state.enemies[i], dt: dt, isPlayer: false)
        clampFighter(&state.enemies[i])
        updateFighterAnim(
            &state.enemies[i], dt: dt,
            moving: moving && canAct(state.enemies[i]),
            walkFrames: 4, walkFps: enemyWalkFps
        )
    }

    // MARK: - Attack update

    private func updateAttackPlayer(_ dt: CGFloat) {
        guard state.player.attackTimer > 0, let kind = state.player.attackKind else { return }
        let total = attackDuration[kind] ?? 0.4
        state.player.attackTimer -= dt
        let t = 1 - state.player.attackTimer / total
        let frames = kind == .special ? max(1, playerSpecialFrames) : 4
        state.player.animFrame = min(frames - 1, Int(floor(t * CGFloat(frames))))

        if grounded(state.player) && kind != .special && kind != .gun {
            state.player.vx *= pow(0.02, dt)
        }
        if kind == .special {
            state.player.vx = 0
            state.player.vy = 0
        }

        let window = attackActive[kind] ?? (0.1, 0.3)
        state.player.attackActive = state.player.attackTimer > 0 && t >= window.0 && t <= window.1

        if kind == .gun {
            if state.player.attackActive && !state.player.attackHit {
                spawnBullet(from: state.player)
                state.player.attackHit = true
            }
        } else if kind == .special && state.player.attackActive {
            handleRiff(t: t, dt: dt, total: total)
        } else if state.player.attackActive && !state.player.attackHit && kind != .special {
            handleMeleeHit(attackerIsPlayer: true, kind: kind, attackerFacing: state.player.facing)
        }

        if state.player.attackTimer <= 0 {
            state.player.attackActive = false
            state.player.attackKind = nil
            state.player.specialHitIds = []
            state.player.anim = grounded(state.player) ? .idle : .jump
            state.player.animTime = 0
            if grounded(state.player) { state.player.vx = 0 }
        }
    }

    private func updateAttackEnemy(_ i: Int, dt: CGFloat) {
        guard state.enemies.indices.contains(i) else { return }
        guard state.enemies[i].attackTimer > 0, let kind = state.enemies[i].attackKind else { return }
        let total = attackDuration[kind] ?? 0.4
        state.enemies[i].attackTimer -= dt
        let t = 1 - state.enemies[i].attackTimer / total
        state.enemies[i].animFrame = min(3, Int(floor(t * 4)))
        if grounded(state.enemies[i]) {
            state.enemies[i].vx *= pow(0.02, dt)
        }
        let window = attackActive[kind] ?? (0.1, 0.3)
        state.enemies[i].attackActive = state.enemies[i].attackTimer > 0 && t >= window.0 && t <= window.1

        if state.enemies[i].attackActive && !state.enemies[i].attackHit && kind != .special {
            handleMeleeHit(attackerIsPlayer: false, kind: kind, attackerFacing: state.enemies[i].facing, enemyIndex: i)
        }

        if state.enemies[i].attackTimer <= 0 {
            state.enemies[i].attackActive = false
            state.enemies[i].attackKind = nil
            state.enemies[i].anim = .idle
            state.enemies[i].animTime = 0
            if grounded(state.enemies[i]) { state.enemies[i].vx = 0 }
        }
    }

    private func handleRiff(t: CGFloat, dt: CGFloat, total: CGFloat) {
        let u = max(0, min(1, (t - 0.15) / 0.7))
        let radius = riffRadiusMin + (riffRadiusMax - riffRadiusMin) * u
        let pulseMarks: [CGFloat] = [0.22, 0.4, 0.58, 0.75]
        for m in pulseMarks {
            if t >= m && t - dt / total < m {
                spawnRiffBurst(x: state.player.x, y: state.player.y, radius: radius)
                state.shake = min(14, state.shake + 6)
            }
        }
        state.riffPulse = radius
        state.riffPulseLife = max(state.riffPulseLife, 0.08)

        for ei in state.enemies.indices {
            if state.enemies[ei].dead { continue }
            if state.player.specialHitIds.contains(state.enemies[ei].id) { continue }
            if !inRiffRange(attacker: state.player, target: state.enemies[ei], radius: radius) { continue }
            if applyHit(attackerIsPlayer: true, victimIsPlayer: false, victimIndex: ei,
                        damage: riffDamage, knock: riffKnock, kind: .special) {
                state.player.specialHitIds.append(state.enemies[ei].id)
            }
        }
    }

    private func inRiffRange(attacker: Fighter, target: Fighter, radius: CGFloat) -> Bool {
        let dx = target.x - attacker.x
        let dy = (target.y - attacker.y) * 1.35
        return hypot(dx, dy) <= radius && abs(attacker.z - target.z) < 80
    }

    private func handleMeleeHit(attackerIsPlayer: Bool, kind: AttackKind, attackerFacing: CGFloat, enemyIndex: Int? = nil) {
        let attacker: Fighter
        if attackerIsPlayer {
            attacker = state.player
        } else {
            guard let ei = enemyIndex, state.enemies.indices.contains(ei) else { return }
            attacker = state.enemies[ei]
        }
        let depthTol: CGFloat = kind == .kick ? 40 : 32
        let airBonus: CGFloat = (!grounded(attacker) && kind == .kick) ? 6 : 0
        let dmg: CGFloat = (kind == .kick ? 18 : 11) + airBonus
        let knock: CGFloat = kind == .kick ? 220 : 140

        // Attack boxes scale with fighter size so sprites and collisions line up.
        let s = max(1, attacker.scale)
        let reach: CGFloat = (kind == .kick ? 52 : 40) * s
        let h: CGFloat = (kind == .kick ? 30 : 28) * s
        let yOff: CGFloat = (kind == .kick ? 36 : 30) * s
        let forward: CGFloat = 8 * s
        let abX = attackerFacing == 1 ? attacker.x + forward : attacker.x - forward - reach
        let abY = attacker.y - yOff - h / 2 - attacker.z

        if attackerIsPlayer {
            for ei in state.enemies.indices {
                if state.enemies[ei].dead { continue }
                if abs(attacker.y - state.enemies[ei].y) > depthTol { continue }
                if abs(attacker.z - state.enemies[ei].z) > 80 { continue }
                let bb = bodyBox(state.enemies[ei])
                if abX < bb.x + bb.w && abX + reach > bb.x && abY < bb.y + bb.h && abY + h > bb.y {
                    if applyHit(attackerIsPlayer: true, victimIsPlayer: false, victimIndex: ei,
                                damage: dmg, knock: knock, kind: kind) {
                        state.player.attackHit = true
                    }
                }
            }
        } else {
            if state.player.dead { return }
            if abs(attacker.y - state.player.y) > depthTol { return }
            if abs(attacker.z - state.player.z) > 80 { return }
            let bb = bodyBox(state.player)
            if abX < bb.x + bb.w && abX + reach > bb.x && abY < bb.y + bb.h && abY + h > bb.y {
                if applyHit(attackerIsPlayer: false, victimIsPlayer: true, victimIndex: enemyIndex,
                            damage: dmg, knock: knock, kind: kind) {
                    if let ei = enemyIndex { state.enemies[ei].attackHit = true }
                }
            }
        }
    }

    /// Hurtbox matched to on-screen sprite size (bodyW/H × scale), slightly tighter than the full draw rect.
    private func bodyBox(_ f: Fighter) -> (x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        let w = f.bodyW * f.scale * 0.72
        let h = f.bodyH * f.scale * 0.88
        return (f.x - w / 2, f.y - h - f.z, w, h)
    }

    @discardableResult
    private func applyHit(
        attackerIsPlayer: Bool,
        victimIsPlayer: Bool,
        victimIndex: Int?,
        damage: CGFloat,
        knock: CGFloat,
        kind: AttackKind
    ) -> Bool {
        if victimIsPlayer {
            guard !state.player.dead, state.player.invulnTimer <= 0 else { return false }
            let attackerFacing: CGFloat
            let attackerX: CGFloat
            let attackerY: CGFloat
            if attackerIsPlayer {
                attackerFacing = state.player.facing
                attackerX = state.player.x
                attackerY = state.player.y
            } else {
                guard let ei = victimIndex, state.enemies.indices.contains(ei) else { return false }
                attackerFacing = state.enemies[ei].facing
                attackerX = state.enemies[ei].x
                attackerY = state.enemies[ei].y
            }
            applyHitTo(&state.player, damage: damage, knock: knock, kind: kind,
                       attackerIsPlayer: attackerIsPlayer, attackerFacing: attackerFacing,
                       attackerX: attackerX, attackerY: attackerY)
            audio.hit(kind, combo: 1)
            audio.hurt()
            if state.player.hp <= 0 {
                state.player.dead = true
                state.player.deathTimer = 0.9
                state.player.anim = .hurt
                audio.playerDown()
            }
            return true
        } else {
            guard let ei = victimIndex, state.enemies.indices.contains(ei) else { return false }
            guard !state.enemies[ei].dead, state.enemies[ei].invulnTimer <= 0 else { return false }
            let attacker = state.player
            applyHitTo(&state.enemies[ei], damage: damage, knock: knock, kind: kind,
                       attackerIsPlayer: true, attackerFacing: attacker.facing,
                       attackerX: attacker.x, attackerY: attacker.y)

            state.player.combo += 1
            state.player.comboTimer = comboWindow
            state.score += Int(damage) * 10 + max(0, state.player.combo - 1) * 15
            if kind != .special {
                state.specialMeter = min(100, state.specialMeter + damage * 1.8)
            }

            let label: String
            let color: String
            if kind == .special {
                label = "RIFF \(Int(damage))"
                color = "#ff2d8a"
            } else if kind == .gun {
                label = "BANG \(Int(damage))"
                color = "#ffe566"
            } else if state.player.combo > 1 {
                label = "\(Int(damage))! x\(state.player.combo)"
                color = state.player.combo > 3 ? "#ffd56a" : "#fff"
            } else {
                label = "\(Int(damage))"
                color = state.player.combo > 3 ? "#ffd56a" : "#fff"
            }
            floatText(x: state.enemies[ei].x,
                      y: state.enemies[ei].y - state.enemies[ei].bodyH - state.enemies[ei].z - 10,
                      text: label,
                      color: color)
            spawnImpact(x: state.enemies[ei].x, y: state.enemies[ei].y - state.enemies[ei].bodyH * 0.5)
            state.shake = min(10, state.shake + (kind == .special ? 2 : (kind == .gun ? 5 : 4)))
            if kind == .gun {
                state.hitStop = max(state.hitStop, 0.04)
            } else if kind != .special {
                state.hitStop = kind == .kick ? 0.06 : 0.045
            }
            // Treat gun hits as heavy for impact SFX
            audio.hit(kind == .gun ? .kick : kind, combo: state.player.combo)

            if state.enemies[ei].hp <= 0 {
                state.enemies[ei].dead = true
                state.enemies[ei].deathTimer = 0.9
                state.enemies[ei].anim = .hurt
                state.score += state.enemies[ei].scoreValue
                state.waveEnemiesLeft = max(0, state.waveEnemiesLeft - 1)
                floatText(x: state.enemies[ei].x,
                          y: state.enemies[ei].y - state.enemies[ei].bodyH - 28,
                          text: "+\(state.enemies[ei].scoreValue)",
                          color: "#2de2e6")
                audio.ko()
                // Last foe of the wave dropped by a gunshot
                if kind == .gun,
                   state.waveEnemiesLeft <= 0,
                   state.spawnQueue <= 0,
                   state.enemies.allSatisfy({ $0.dead || $0.id == state.enemies[ei].id }) {
                    spawnGangViolenceLine()
                }
            }
            return true
        }
    }

    private func applyHitTo(
        _ victim: inout Fighter,
        damage: CGFloat,
        knock: CGFloat,
        kind: AttackKind,
        attackerIsPlayer: Bool,
        attackerFacing: CGFloat,
        attackerX: CGFloat,
        attackerY: CGFloat
    ) {
        victim.hp = max(0, victim.hp - damage)
        victim.hurtTimer = hurtDuration
        victim.invulnTimer = invulnAfterHit
        victim.anim = .hurt
        victim.animTime = 0
        victim.animFrame = 0
        victim.attackTimer = 0
        victim.attackActive = false
        victim.flash = 0.12
        if kind == .special {
            var dirX = victim.x - attackerX
            var dirY = victim.y - attackerY
            let len = hypot(dirX, dirY)
            if len < 0.001 { dirX = attackerFacing; dirY = 0 }
            else { dirX /= len; dirY /= len }
            victim.vx = dirX * knock
            victim.vy = dirY * knock * 0.55
            victim.zVel = max(victim.zVel, 220)
            victim.facing = dirX >= 0 ? -1 : 1
        } else {
            victim.vx = attackerFacing * knock
            victim.facing = attackerFacing == 1 ? -1 : 1
            if !grounded(victim) {
                victim.zVel = max(victim.zVel, 180)
            }
        }
    }

    // MARK: - Anim

    private func updateFighterAnim(_ f: inout Fighter, dt: CGFloat, moving: Bool, walkFrames: Int, walkFps: CGFloat) {
        if f.dead {
            f.anim = .hurt
            f.animFrame = min(3, Int(floor((1 - f.deathTimer / 0.9) * 4)))
            return
        }
        if f.hurtTimer > 0 {
            f.anim = .hurt
            f.animTime += dt
            f.animFrame = min(3, Int(floor((1 - f.hurtTimer / hurtDuration) * 4)))
            return
        }
        if f.attackTimer > 0 { return }
        if !grounded(f) {
            f.anim = .jump
            f.animTime += dt
            if f.zVel > 120 { f.animFrame = 1 }
            else if f.zVel > -80 { f.animFrame = 2 }
            else { f.animFrame = 3 }
            return
        }
        if moving {
            let sprint = f.kind == .player && pressed("sprint")
            f.anim = sprint ? .run : .walk
            f.animTime += dt
            let fps = sprint ? playerRunFps : walkFps
            let frameCount = sprint ? playerRunFrames : walkFrames
            f.animFrame = Int(floor(f.animTime * fps)) % max(1, frameCount)
        } else {
            f.anim = .idle
            f.animTime += dt
            let holds = f.kind == .player ? playerIdleHolds : enemyIdleHolds
            f.animFrame = idleHoldFrame(time: f.animTime, holds: holds)
        }
    }

    /// Phaser-style per-frame idle durations without a second clock.
    private func idleHoldFrame(time: CGFloat, holds: [CGFloat]) -> Int {
        let total = holds.reduce(0, +)
        guard total > 0, !holds.isEmpty else { return 0 }
        var t = time.truncatingRemainder(dividingBy: total)
        if t < 0 { t += total }
        var acc: CGFloat = 0
        for (i, h) in holds.enumerated() {
            acc += h
            if t < acc { return i }
        }
        return holds.count - 1
    }

    // MARK: - Smoke / victory

    private func beginSmokeBreak(_ message: String, duration: CGFloat) {
        state.player.vx = 0
        state.player.vy = 0
        state.player.z = 0
        state.player.zVel = 0
        state.player.attackTimer = 0
        state.player.attackKind = nil
        state.player.attackActive = false
        state.player.anim = playerSmokes ? .smoke : .idle
        state.player.animTime = 0
        state.player.animFrame = 0
        state.player.hurtTimer = 0
        state.message = message
        state.messageTimer = duration
        state.smokePuffTimer = 0.35
        flushInput()
        // Keep the gunshot punchline through the smoke break
        if state.speechBubble?.text != gangViolenceLine {
            state.speechBubble = nil
        }
        if playerSmokes { audio.smokeBreak() }
    }

    private func updateBullets(_ dt: CGFloat) {
        guard !state.bullets.isEmpty else { return }
        for bi in state.bullets.indices {
            state.bullets[bi].life -= dt
            state.bullets[bi].x += state.bullets[bi].vx * dt
            let b = state.bullets[bi]
            for ei in state.enemies.indices {
                let target = state.enemies[ei]
                if target.dead || b.hitIds.contains(target.id) { continue }
                if abs(b.y - target.y) > 38 { continue }
                if abs(b.z - (target.z + target.bodyH * target.scale * 0.4)) > 55 { continue }
                let bb = bodyBox(target)
                if b.x < bb.x - 6 || b.x > bb.x + bb.w + 6 { continue }
                state.bullets[bi].hitIds.append(target.id)
                state.bullets[bi].life = 0
                _ = applyHit(
                    attackerIsPlayer: true,
                    victimIsPlayer: false,
                    victimIndex: ei,
                    damage: b.damage,
                    knock: 260,
                    kind: .gun
                )
                break
            }
        }
        state.bullets = state.bullets.filter {
            $0.life > 0 && $0.x > -40 && $0.x < stageWidth + 40
        }
    }

    private func updateSmokeBreak(_ dt: CGFloat) {
        state.player.vx = 0
        state.player.vy = 0
        state.player.animTime += dt
        guard playerSmokes else {
            // Andrew / Han: plain idle hold cadence, no cig VFX or SFX.
            state.player.anim = .idle
            state.player.animFrame = idleHoldFrame(time: state.player.animTime, holds: playerIdleHolds)
            return
        }
        state.player.anim = .smoke
        state.player.animFrame = Int(floor(state.player.animTime * smokeFrameFps)) % 4
        state.smokePuffTimer -= dt
        if state.smokePuffTimer <= 0 {
            spawnCigSmoke()
            state.smokePuffTimer = state.player.animFrame == 2 ? 0.28 : 0.55
            if state.player.animFrame == 2 { audio.exhale() }
        }
    }

    private func updateVictory(_ dt: CGFloat) {
        if state.messageTimer > 0 && state.messageTimer < 98 {
            state.messageTimer -= dt
        }
        state.player.vx = 0
        state.player.vy = 0
        state.player.anim = .victory
        state.player.animTime += dt
        state.player.animFrame = Int(floor(state.player.animTime * 3)) % 4
        if playerSmokes {
            state.smokePuffTimer -= dt
            if state.smokePuffTimer <= 0 {
                spawnCigSmoke()
                state.smokePuffTimer = 0.7
            }
        }
        updateParticles(dt)
    }

    // MARK: - Spawns / particles

    private func updateSpawns(_ dt: CGFloat) {
        guard state.spawnQueue > 0 else { return }
        state.spawnTimer -= dt
        guard state.spawnTimer <= 0 else { return }
        state.spawnTimer = 0.55 + CGFloat.random(in: 0...0.35)
        state.spawnQueue -= 1
        // Don't spawn left when the stage edge would clamp onto JJ (cam≈0 → x=80 vs player 220).
        let cam = state.cameraX
        let leftX = cam - 80
        let canUseLeft = leftX > 90 && abs(leftX - state.player.x) >= 240
        let side: CGFloat = (canUseLeft && CGFloat.random(in: 0...1) < 0.5) ? -1 : 1
        let x = side < 0
            ? leftX
            : cam + Self.viewW + 80 + CGFloat.random(in: 0...40)
        let y = laneTop + 30 + CGFloat.random(in: 0...(laneBottom - laneTop - 60))
        let spawn: (type: EnemyType, elite: Bool)
        if state.pendingSpawns.isEmpty {
            spawn = (.biz, false)
        } else {
            spawn = state.pendingSpawns.removeFirst()
        }
        let clampedX = max(80, min(stageWidth - 80, x))
        state.enemies.append(
            makeEnemy(x: clampedX, y: y, wave: state.wave, type: spawn.type, elite: spawn.elite)
        )
    }

    private func updateParticles(_ dt: CGFloat) {
        for i in state.particles.indices {
            state.particles[i].life -= dt
            state.particles[i].x += state.particles[i].vx * dt
            state.particles[i].y += state.particles[i].vy * dt
            if state.particles[i].kind == .wave, let r = state.particles[i].radius {
                state.particles[i].radius = r + 280 * dt
            }
            if state.particles[i].kind == .note {
                state.particles[i].vy += 120 * dt
            }
            if state.particles[i].kind == .smoke {
                state.particles[i].vx *= pow(0.9, dt * 60)
                if let r = state.particles[i].radius {
                    state.particles[i].radius = r + 8 * dt
                }
            }
            state.particles[i].frame = min(3, Int(floor((1 - state.particles[i].life / state.particles[i].maxLife) * 4)))
        }
        // Cap particle count to avoid main-thread death spirals during heavy combat
        if state.particles.count > 120 {
            state.particles.removeFirst(state.particles.count - 80)
        }
        state.particles.removeAll { $0.life <= 0 }
        for i in state.floats.indices {
            state.floats[i].life -= dt
            state.floats[i].y -= 40 * dt
        }
        state.floats.removeAll { $0.life <= 0 }
        if state.riffPulseLife > 0 {
            state.riffPulseLife -= dt
            if state.riffPulseLife <= 0 { state.riffPulse = 0 }
        }
        if var b = state.speechBubble {
            b.life -= dt
            state.speechBubble = b.life <= 0 ? nil : b
        }
    }

    private func spawnImpact(x: CGFloat, y: CGFloat) {
        state.particles.append(Particle(x: x, y: y, vx: 0, vy: -20, life: 0.28, maxLife: 0.28, frame: 0, kind: .impact, radius: nil, colorHex: nil))
        for _ in 0..<5 {
            let a = CGFloat.random(in: 0...(CGFloat.pi * 2))
            let s = 80 + CGFloat.random(in: 0...120)
            state.particles.append(Particle(
                x: x, y: y, vx: cos(a) * s, vy: sin(a) * s - 40,
                life: 0.25 + CGFloat.random(in: 0...0.2), maxLife: 0.4,
                frame: 0, kind: .spark, radius: nil, colorHex: nil
            ))
        }
    }

    private func spawnRiffBurst(x: CGFloat, y: CGFloat, radius: CGFloat) {
        state.riffPulse = radius
        state.riffPulseLife = 0.22
        if state.particles.count > 80 {
            state.particles.removeFirst(state.particles.count - 60)
        }
        state.particles.append(Particle(x: x, y: y - 40, vx: 0, vy: 0, life: 0.35, maxLife: 0.35, frame: 0, kind: .wave, radius: radius, colorHex: "#ff2d8a"))
        state.particles.append(Particle(x: x, y: y - 40, vx: 0, vy: 0, life: 0.28, maxLife: 0.28, frame: 0, kind: .wave, radius: radius * 0.65, colorHex: "#2de2e6"))
        for i in 0..<6 {
            let a = (CGFloat.pi * 2 * CGFloat(i)) / 6 + CGFloat.random(in: 0...0.3)
            let s = 120 + CGFloat.random(in: 0...160)
            state.particles.append(Particle(
                x: x, y: y - 50 - CGFloat.random(in: 0...30),
                vx: cos(a) * s, vy: sin(a) * s * 0.55 - 40,
                life: 0.4 + CGFloat.random(in: 0...0.2), maxLife: 0.65,
                frame: i % 4, kind: .note,
                radius: nil, colorHex: i % 2 == 0 ? "#ff2d8a" : "#2de2e6"
            ))
        }
    }

    private func spawnCigSmoke() {
        let f = state.player
        let face = f.facing
        let mouthX = f.x + face * 18
        let mouthY = f.y - f.bodyH * f.scale * 0.72 - f.z
        for _ in 0..<4 {
            state.particles.append(Particle(
                x: mouthX + CGFloat.random(in: -5...5),
                y: mouthY + CGFloat.random(in: -3...3),
                vx: face * (12 + CGFloat.random(in: 0...28)) + CGFloat.random(in: -10...10),
                vy: -25 - CGFloat.random(in: 0...45),
                life: 0.7 + CGFloat.random(in: 0...0.5), maxLife: 1.2,
                frame: 0, kind: .smoke, radius: 4 + CGFloat.random(in: 0...6),
                colorHex: "rgba(180,180,190,0.55)"
            ))
        }
    }

    private func floatText(x: CGFloat, y: CGFloat, text: String, color: String) {
        state.floats.append(FloatingText(x: x, y: y, text: text, life: 0.7, colorHex: color))
    }
}
