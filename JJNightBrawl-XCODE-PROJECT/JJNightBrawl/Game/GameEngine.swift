import Foundation
import CoreGraphics

/// Core beat-em-up simulation — ported from the web engine.
final class GameEngine {
    static let viewW: CGFloat = 960
    static let viewH: CGFloat = 540

    private let laneTop: CGFloat = 310
    private let laneBottom: CGFloat = 500
    private let stageWidth: CGFloat = 2800

    private let playerSpeed: CGFloat = 190
    private let playerDepthSpeed: CGFloat = 120
    private let enemySpeed: CGFloat = 95
    private let enemyDepthSpeed: CGFloat = 70

    private let jumpVel: CGFloat = 520
    private let gravity: CGFloat = 1450
    private let airControl: CGFloat = 0.72

    private let playerWalkFps: CGFloat = 12
    private let enemyWalkFps: CGFloat = 8

    private let attackDuration: [AttackKind: CGFloat] = [
        .punch: 0.36, .kick: 0.48, .special: 0.95, .gun: 0.42
    ]
    private let attackActive: [AttackKind: (CGFloat, CGFloat)] = [
        .punch: (0.12, 0.28), .kick: (0.16, 0.38), .special: (0.18, 0.82), .gun: (0.08, 0.22)
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
    private let invulnAfterHit: CGFloat = 0.55
    private let comboWindow: CGFloat = 1.1
    private let speechBubbleLife: CGFloat = 1.15
    private let waveClearDuration: CGFloat = 3.2
    private let smokeFrameFps: CGFloat = 2.2

    private let punkSlogans = [
        "FUCK YEAH!", "EAT SHIT BOOTLICKERS!", "NOT MY PRESIDENT!",
        "EAT THE RICH!", "NO GODS NO MASTERS!", "SMASH THE STATE!",
        "DIE YUPPIE SCUM!", "THIS MACHINE KILLS FASCISTS!", "PUNKS NOT DEAD!",
        "BURN IT DOWN!", "ACAB!", "CLASS WAR NOW!", "NO FUTURE? MAKE ONE!",
        "SCREW YOUR SUIT!", "RIFF OR DIE!"
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
    }

    func startGame() {
        nextId = 1
        state = GameState(player: makePlayer())
        state.phase = .playing
        state.stageWidth = stageWidth
        audio.uiConfirm()
        beginWave(1)
    }

    func togglePause() {
        if state.phase == .playing {
            state.phase = .paused
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
    }

    // MARK: - Update

    func update(dt rawDt: CGFloat) {
        let dt = min(rawDt, 0.05)
        state.elapsed += dt

        if state.phase == .title || state.phase == .paused || state.phase == .gameover {
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

        if state.phase == .waveClear {
            updateSmokeBreak(dt)
            state.enemies = state.enemies.filter { !($0.dead && $0.deathTimer <= 0) }
            for i in state.enemies.indices where state.enemies[i].dead {
                state.enemies[i].deathTimer -= dt
            }
            updateParticles(dt)
            followCamera(dt, lag: 4)
        } else {
            updatePlayer(dt)
            for i in state.enemies.indices {
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
                state.phase = .victory
                beginSmokeBreak("STREET CLEARED", duration: 99)
                state.player.anim = .victory
                state.player.animTime = 0
                state.player.animFrame = 0
                audio.victory()
            } else {
                state.phase = .waveClear
                beginSmokeBreak("WAVE CLEAR — SMOKE BREAK", duration: waveClearDuration)
                audio.waveClear()
            }
        }

        if state.phase == .waveClear && state.messageTimer <= 0 {
            // After wave 3 smoke break → unlock pistol
            if state.wave == 3 && !state.hasGun {
                state.hasGun = true
                state.message = "GUN UNLOCKED — PRESS F TO FIRE"
                state.messageTimer = 2.0
                state.player.anim = .idle
                state.player.animTime = 0
                state.player.animFrame = 0
                audio.uiConfirm()
                return
            }
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
            scale: 1.7, bodyW: 42, bodyH: 88
        )
    }

    private func makePlayer() -> Fighter {
        var p = GameEngine.makeBlankPlayer(id: nextId)
        nextId += 1
        return p
    }

    private func makeEnemy(x: CGFloat, y: CGFloat, wave: Int, type: EnemyType) -> Fighter {
        let hpMul: CGFloat = type == .biz ? 1.1 : type == .maga ? 1.05 : 0.95
        let hp = round((28 + CGFloat(wave) * 8) * hpMul)
        let scale: CGFloat = type == .gothf ? 1.4 : type == .biz ? 1.5 : 1.48
        let f = Fighter(
            id: nextId, kind: .enemy, enemyType: type,
            x: x, y: y, z: 0, zVel: 0, vx: 0, vy: 0, facing: -1,
            hp: hp, maxHp: hp, anim: .idle, animTime: 0, animFrame: 0,
            attackTimer: 0, attackActive: false, attackHit: false, attackKind: nil,
            specialHitIds: [], hurtTimer: 0, invulnTimer: 0, combo: 0, comboTimer: 0,
            dead: false, deathTimer: 0, aiCooldown: 0.4 + CGFloat.random(in: 0...0.6),
            flash: 0, scoreValue: 100 + wave * 40 + (type == .biz ? 20 : 0),
            scale: scale, bodyW: 48, bodyH: 90
        )
        nextId += 1
        return f
    }

    private func beginWave(_ wave: Int) {
        state.wave = wave
        state.enemies = []
        state.bullets = []
        let count = 2 + wave
        state.waveEnemiesLeft = count
        state.spawnQueue = count
        state.spawnTimer = 0.35
        if wave == state.maxWaves {
            state.message = "FINAL WAVE"
        } else if state.hasGun && wave == 4 {
            state.message = "WAVE 4 — PACKIN' HEAT"
        } else {
            state.message = "WAVE \(wave)"
        }
        state.messageTimer = 1.6
        audio.waveStart(wave)
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
        var mx: CGFloat = 0
        var my: CGFloat = 0
        if pressed("left") || state.touch.left { mx -= 1 }
        if pressed("right") || state.touch.right { mx += 1 }
        if pressed("up") || state.touch.up { my -= 1 }
        if pressed("down") || state.touch.down { my += 1 }
        if mx != 0 && my != 0 {
            let inv = 1 / sqrt(2.0 as CGFloat)
            mx *= inv; my *= inv
        }
        return (mx, my)
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
        let slogan = punkSlogans.randomElement() ?? "FUCK YEAH!"
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

        if state.jumpQueued {
            state.jumpQueued = false
            _ = tryJump(&state.player)
        } else if grounded(state.player) && pressed("jump") {
            if tryJump(&state.player) {
                state.keys.remove("jump")
            }
        }

        var moving = false
        let air = !grounded(state.player)
        let (mx, my) = moveAxis()

        if canAct(state.player) || (air && state.player.attackTimer <= 0 && state.player.hurtTimer <= 0) {
            let speedMul: CGFloat = air ? airControl : 1
            if state.player.attackTimer <= 0 {
                state.player.vx = mx * playerSpeed * speedMul
                state.player.vy = air ? 0 : my * playerDepthSpeed
                if mx != 0 { state.player.facing = mx > 0 ? 1 : -1 }
                moving = !air && (mx != 0 || my != 0)
            }
            consumePlayerAction()
        } else if state.player.attackTimer <= 0 && grounded(state.player) {
            state.player.vx *= pow(0.05, dt)
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
                    state.enemies[i].aiCooldown = 0.7 + CGFloat.random(in: 0...0.9)
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
        state.player.animFrame = min(3, Int(floor(t * 4)))

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
        if !state.player.specialHitIds.isEmpty {
            state.hitStop = min(state.hitStop, 0.03)
        }
    }

    private func inRiffRange(attacker: Fighter, target: Fighter, radius: CGFloat) -> Bool {
        let dx = target.x - attacker.x
        let dy = (target.y - attacker.y) * 1.35
        return hypot(dx, dy) <= radius && abs(attacker.z - target.z) < 80
    }

    private func handleMeleeHit(attackerIsPlayer: Bool, kind: AttackKind, attackerFacing: CGFloat, enemyIndex: Int? = nil) {
        let attacker: Fighter = attackerIsPlayer ? state.player : state.enemies[enemyIndex!]
        let depthTol: CGFloat = kind == .kick ? 36 : 28
        let airBonus: CGFloat = (!grounded(attacker) && kind == .kick) ? 4 : 0
        let dmg: CGFloat = (kind == .kick ? 18 : 11) + airBonus
        let knock: CGFloat = kind == .kick ? 220 : 120

        let reach: CGFloat = kind == .kick ? 78 : 54
        let h: CGFloat = kind == .kick ? 42 : 40
        let yOff: CGFloat = kind == .kick ? 52 : 44
        let abX = attackerFacing == 1 ? attacker.x + 10 : attacker.x - 10 - reach
        let abY = attacker.y - yOff - h / 2 - attacker.z

        if attackerIsPlayer {
            for ei in state.enemies.indices {
                if state.enemies[ei].dead { continue }
                if abs(attacker.y - state.enemies[ei].y) > depthTol { continue }
                if abs(attacker.z - state.enemies[ei].z) > 70 { continue }
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
            if abs(attacker.z - state.player.z) > 70 { return }
            let bb = bodyBox(state.player)
            if abX < bb.x + bb.w && abX + reach > bb.x && abY < bb.y + bb.h && abY + h > bb.y {
                if applyHit(attackerIsPlayer: false, victimIsPlayer: true, victimIndex: enemyIndex,
                            damage: dmg, knock: knock, kind: kind) {
                    if let ei = enemyIndex { state.enemies[ei].attackHit = true }
                }
            }
        }
    }

    private func bodyBox(_ f: Fighter) -> (x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        (f.x - f.bodyW / 2, f.y - f.bodyH - f.z, f.bodyW, f.bodyH)
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
            applyHitTo(&state.player, damage: damage, knock: knock, kind: kind,
                       attackerIsPlayer: attackerIsPlayer, attackerFacing: attackerIsPlayer ? state.player.facing : (victimIndex.map { state.enemies[$0].facing } ?? -1),
                       attackerX: attackerIsPlayer ? state.player.x : state.enemies[victimIndex!].x,
                       attackerY: attackerIsPlayer ? state.player.y : state.enemies[victimIndex!].y)
            if attackerIsPlayer {
                // shouldn't happen
            } else {
                // enemy hit player — no score
            }
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
            if kind == .special {
                state.hitStop = max(state.hitStop, 0.02)
            } else if kind == .gun {
                state.hitStop = max(state.hitStop, 0.04)
            } else {
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
            f.anim = .walk
            f.animTime += dt
            f.animFrame = Int(floor(f.animTime * walkFps)) % walkFrames
        } else {
            f.anim = .idle
            f.animTime += dt
            f.animFrame = Int(floor(f.animTime * 2.5)) % 4
        }
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
        state.player.anim = .smoke
        state.player.animTime = 0
        state.player.animFrame = 0
        state.player.hurtTimer = 0
        state.message = message
        state.messageTimer = duration
        state.smokePuffTimer = 0.35
        state.actionQueue = []
        state.jumpQueued = false
        state.keys.removeAll()
        state.touch = TouchState()
        // Keep the gunshot punchline through the smoke break
        if state.speechBubble?.text != gangViolenceLine {
            state.speechBubble = nil
        }
        audio.smokeBreak()
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
                if abs(b.y - target.y) > 34 { continue }
                if abs(b.z - (target.z + target.bodyH * 0.4)) > 50 { continue }
                let bb = bodyBox(target)
                if b.x < bb.x - 4 || b.x > bb.x + bb.w + 4 { continue }
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
        state.player.anim = .smoke
        state.player.animTime += dt
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
        state.smokePuffTimer -= dt
        if state.smokePuffTimer <= 0 {
            spawnCigSmoke()
            state.smokePuffTimer = 0.7
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
        let side: CGFloat = CGFloat.random(in: 0...1) < 0.5 ? -1 : 1
        let cam = state.cameraX
        let x = side < 0
            ? cam - 40 + CGFloat.random(in: 0...30)
            : cam + Self.viewW + 20 + CGFloat.random(in: 0...40)
        let y = laneTop + 30 + CGFloat.random(in: 0...(laneBottom - laneTop - 60))
        let types = EnemyType.allCases
        let typeIndex = (state.waveEnemiesLeft + state.spawnQueue + state.wave) % types.count
        let type = types[typeIndex]
        let clampedX = max(80, min(stageWidth - 80, x))
        state.enemies.append(makeEnemy(x: clampedX, y: y, wave: state.wave, type: type))
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
