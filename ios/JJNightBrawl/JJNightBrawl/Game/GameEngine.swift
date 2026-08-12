import Foundation
import CoreGraphics
import UIKit

/// Core simulation for JJ: Night Brawl.
/// Movement uses true analog axes + accel/decel (not digital on/off + snap velocity).
final class GameEngine {
    let state: GameState

    // MARK: - Movement tuning
    var playerSpeed: CGFloat = 210
    var playerDepthSpeed: CGFloat = 135
    var airControl: CGFloat = 0.78
    var playerAccel: CGFloat = 2200
    var playerDecel: CGFloat = 2800
    var playerAirAccel: CGFloat = 1400

    private let gravity: CGFloat = 2200
    private let jumpVel: CGFloat = 720
    private let groundY: CGFloat = 0
    private let laneMin: CGFloat = -90
    private let laneMax: CGFloat = 90
    private let stickDeadzone: CGFloat = 0.08
    private let facingThreshold: CGFloat = 0.2
    private let moveAnimSpeed: CGFloat = 30

    private var nextId = 1
    var onSfx: ((String) -> Void)?

    init() {
        let p = Fighter(
            id: 0,
            kind: .player,
            enemyType: nil,
            x: 220,
            y: 0,
            z: 0,
            zVel: 0,
            vx: 0,
            vy: 0,
            facing: 1,
            hp: 100,
            maxHp: 100,
            anim: .idle,
            animTime: 0,
            animFrame: 0,
            attackTimer: 0,
            attackActive: false,
            attackHit: false,
            attackKind: nil,
            specialHitIds: [],
            hurtTimer: 0,
            invulnTimer: 0,
            combo: 0,
            comboTimer: 0,
            dead: false,
            deathTimer: 0,
            aiCooldown: 0,
            flash: 0,
            scoreValue: 0,
            scale: 1,
            bodyW: 48,
            bodyH: 96
        )
        state = GameState(player: p)
    }

    // MARK: - Input

    func setTouch(left: Bool? = nil, right: Bool? = nil, up: Bool? = nil, down: Bool? = nil) {
        if let left { state.touch.left = left }
        if let right { state.touch.right = right }
        if let up { state.touch.up = up }
        if let down { state.touch.down = down }
    }

    /// Analog move from virtual stick. Values clamped to -1...1.
    /// Coarse bools mirrored at ±0.25 for any code still reading digital touch flags.
    func setMoveAxis(x: CGFloat, y: CGFloat) {
        let ax = max(-1, min(1, x))
        let ay = max(-1, min(1, y))
        state.touch.axisX = ax
        state.touch.axisY = ay
        state.touch.left = ax < -0.25
        state.touch.right = ax > 0.25
        state.touch.up = ay < -0.25
        state.touch.down = ay > 0.25
    }

    func clearTouch() {
        state.touch = TouchState()
    }

    func setKey(_ key: String, down: Bool) {
        let k = key.lowercased()
        if down {
            state.keys.insert(k)
        } else {
            state.keys.remove(k)
        }
    }

    func queueAttack(_ kind: AttackKind) {
        guard state.phase == .playing else { return }
        state.actionQueue.append(kind)
    }

    func queueJump() {
        guard state.phase == .playing else { return }
        state.jumpQueued = true
    }

    func startGame() {
        state.phase = .playing
        state.wave = 1
        state.score = 0
        state.specialMeter = 0
        state.hasGun = false
        state.enemies.removeAll()
        state.particles.removeAll()
        state.bullets.removeAll()
        state.floats.removeAll()
        state.speechBubble = nil
        state.player.hp = state.player.maxHp
        state.player.dead = false
        state.player.x = 220
        state.player.y = 0
        state.player.z = 0
        state.player.vx = 0
        state.player.vy = 0
        state.player.anim = .idle
        state.message = "WAVE 1"
        state.messageTimer = 2
        state.waveEnemiesLeft = 4
        state.spawnQueue = 4
        state.spawnTimer = 0.4
    }

    func togglePause() {
        if state.phase == .playing {
            state.phase = .paused
        } else if state.phase == .paused {
            state.phase = .playing
        }
    }

    // MARK: - Axis helpers

    /// Keyboard wins when any arrow/WASD is held; otherwise analog stick with deadzone + smoothstep gain.
    func moveAxis() -> (CGFloat, CGFloat) {
        let keys = state.keys
        let left = keys.contains("left") || keys.contains("a") || keys.contains("arrowleft")
        let right = keys.contains("right") || keys.contains("d") || keys.contains("arrowright")
        let up = keys.contains("up") || keys.contains("w") || keys.contains("arrowup")
        let down = keys.contains("down") || keys.contains("s") || keys.contains("arrowdown")

        if left || right || up || down {
            var mx: CGFloat = (right ? 1 : 0) - (left ? 1 : 0)
            var my: CGFloat = (down ? 1 : 0) - (up ? 1 : 0)
            let mag = hypot(mx, my)
            if mag > 1 {
                mx /= mag
                my /= mag
            }
            return (mx, my)
        }

        var ax = state.touch.axisX
        var ay = state.touch.axisY
        let r = hypot(ax, ay)
        if r < stickDeadzone {
            return (0, 0)
        }
        // Smoothstep gain on radius beyond deadzone → full throw.
        let t = min(1, (r - stickDeadzone) / (1 - stickDeadzone))
        let gain = t * t * (3 - 2 * t)
        let scale = gain / r
        ax *= scale
        ay *= scale
        return (max(-1, min(1, ax)), max(-1, min(1, ay)))
    }

    func approach(_ current: CGFloat, _ target: CGFloat, rate: CGFloat, dt: CGFloat) -> CGFloat {
        if current < target {
            return min(current + rate * dt, target)
        } else if current > target {
            return max(current - rate * dt, target)
        }
        return current
    }

    // MARK: - Tick

    func update(dt rawDt: CGFloat) {
        let dt = min(max(rawDt, 0), 1.0 / 20.0)
        guard state.phase == .playing || state.phase == .waveClear else {
            if state.phase == .title || state.phase == .victory || state.phase == .gameover {
                state.elapsed += dt
            }
            return
        }

        if state.hitStop > 0 {
            state.hitStop -= dt
            return
        }

        state.elapsed += dt
        if state.messageTimer > 0 { state.messageTimer -= dt }
        if state.shake > 0 { state.shake = max(0, state.shake - dt * 8) }
        if state.riffPulseLife > 0 {
            state.riffPulseLife -= dt
            state.riffPulse = max(0, state.riffPulseLife / 0.35)
        }

        updatePlayer(dt: dt)
        updateEnemies(dt: dt)
        updateBullets(dt: dt)
        updateParticles(dt: dt)
        updateCamera(dt: dt)
        updateWave(dt: dt)

        if state.particles.count > 120 {
            state.particles.removeFirst(state.particles.count - 120)
        }
    }

    // MARK: - Player movement

    private var playerCanAct: Bool {
        let p = state.player
        return !p.dead && p.hurtTimer <= 0 && !p.attackActive && p.attackTimer <= 0
    }

    private var playerGrounded: Bool {
        state.player.z <= groundY + 0.5 && state.player.zVel <= 0
    }

    private func updatePlayer(dt: CGFloat) {
        var p = state.player
        if p.dead {
            p.deathTimer += dt
            p.anim = .dead
            state.player = p
            return
        }

        if p.hurtTimer > 0 { p.hurtTimer -= dt }
        if p.invulnTimer > 0 { p.invulnTimer -= dt }
        if p.comboTimer > 0 {
            p.comboTimer -= dt
            if p.comboTimer <= 0 { p.combo = 0 }
        }
        if p.flash > 0 { p.flash -= dt }

        // Jump
        if state.jumpQueued {
            state.jumpQueued = false
            if playerGrounded && playerCanAct {
                p.zVel = jumpVel
                p.anim = .jump
                p.animTime = 0
            }
        }

        // Gravity / ground
        if p.z > groundY || p.zVel > 0 {
            p.zVel -= gravity * dt
            p.z += p.zVel * dt
            if p.z <= groundY {
                p.z = groundY
                p.zVel = 0
            }
        }

        let grounded = p.z <= groundY + 0.5 && p.zVel <= 0
        let (mx, my) = moveAxis()
        let movable = playerCanAct || (p.hurtTimer <= 0 && !p.dead)

        if movable && !p.attackActive {
            let control = grounded ? 1 : airControl
            let targetVX = mx * playerSpeed * control
            let targetVY = my * playerDepthSpeed * control
            let accelBase = grounded ? playerAccel : playerAirAccel

            // Faster brake when reversing direction.
            let reverseX = (p.vx > 0 && targetVX < 0) || (p.vx < 0 && targetVX > 0) || (abs(targetVX) < 1 && abs(p.vx) > 1)
            let reverseY = (p.vy > 0 && targetVY < 0) || (p.vy < 0 && targetVY > 0) || (abs(targetVY) < 1 && abs(p.vy) > 1)
            let rateX = reverseX ? playerDecel : accelBase
            let rateY = reverseY ? playerDecel : accelBase

            p.vx = approach(p.vx, targetVX, rate: rateX, dt: dt)
            p.vy = approach(p.vy, targetVY, rate: rateY, dt: dt)

            // Facing flips only past stick threshold (avoids jitter near center).
            if mx > facingThreshold {
                p.facing = 1
            } else if mx < -facingThreshold {
                p.facing = -1
            }

            let speed = hypot(p.vx, p.vy)
            if grounded && !p.attackActive && p.hurtTimer <= 0 {
                if speed > moveAnimSpeed {
                    if p.anim != .walk {
                        p.anim = .walk
                        p.animTime = 0
                    }
                } else if p.anim == .walk || p.anim == .jump {
                    p.anim = .idle
                    p.animTime = 0
                }
            }
        } else if grounded {
            // Can't act (attack/hurt recovery): decelerate with playerDecel, not pow friction.
            p.vx = approach(p.vx, 0, rate: playerDecel, dt: dt)
            p.vy = approach(p.vy, 0, rate: playerDecel, dt: dt)
        }

        p.x += p.vx * dt
        p.y += p.vy * dt
        p.y = max(laneMin, min(laneMax, p.y))
        p.x = max(40, min(state.stageWidth - 40, p.x))

        // Drain attack / consume queue (combat numbers unchanged placeholders).
        if p.attackTimer > 0 {
            p.attackTimer -= dt
            if p.attackTimer <= 0 {
                p.attackActive = false
                p.attackHit = false
                p.attackKind = nil
                p.specialHitIds = []
                if grounded { p.anim = .idle }
            }
        } else if playerCanAct, let action = state.actionQueue.first {
            state.actionQueue.removeFirst()
            beginAttack(&p, kind: action)
        }

        p.animTime += dt
        advanceAnimFrame(&p)

        state.player = p
    }

    private func beginAttack(_ p: inout Fighter, kind: AttackKind) {
        if kind == .special && state.specialMeter < 100 { return }
        if kind == .gun && !state.hasGun { return }
        p.attackKind = kind
        p.attackActive = true
        p.attackHit = false
        p.attackTimer = kind == .kick ? 0.42 : (kind == .special ? 0.55 : 0.28)
        p.anim = .attack
        p.animTime = 0
        p.animFrame = 0
        if kind == .special {
            state.specialMeter = 0
            state.riffPulse = 1
            state.riffPulseLife = 0.35
            state.speechBubble = SpeechBubble(text: sloganLine(), life: 1.4, maxLife: 1.4)
            onSfx?("special")
        } else if kind == .gun {
            fireGun(from: p)
            onSfx?("gun")
        } else {
            onSfx?(kind == .kick ? "kick" : "punch")
        }
    }

    private func sloganLine() -> String {
        let lines = ["NIGHT SHIFT'S OVER", "RIFF THIS", "EAT CONCRETE", "NO REFUNDS"]
        return lines[Int(state.elapsed * 3) % lines.count]
    }

    private func fireGun(from p: Fighter) {
        state.bullets.append(Bullet(
            x: p.x + p.facing * 40,
            y: p.y,
            z: p.z + 40,
            vx: p.facing * 900,
            facing: p.facing,
            life: 0.8,
            damage: 28,
            hitIds: []
        ))
    }

    private func advanceAnimFrame(_ p: inout Fighter) {
        let fps: CGFloat
        switch p.anim {
        case .walk: fps = 8
        case .attack: fps = 12
        case .idle: fps = 4
        default: fps = 6
        }
        p.animFrame = Int(p.animTime * fps) % 4
    }

    // MARK: - Enemies / world (scaffold; combat numbers not part of this movement PR)

    private func updateEnemies(dt: CGFloat) {
        guard !state.enemies.isEmpty else { return }
        for i in state.enemies.indices {
            var e = state.enemies[i]
            if e.dead {
                e.deathTimer += dt
                state.enemies[i] = e
                continue
            }
            if e.hurtTimer > 0 { e.hurtTimer -= dt }
            if e.invulnTimer > 0 { e.invulnTimer -= dt }
            if e.flash > 0 { e.flash -= dt }

            if e.z > groundY || e.zVel > 0 {
                e.zVel -= gravity * dt
                e.z += e.zVel * dt
                if e.z < groundY {
                    e.z = groundY
                    e.zVel = 0
                }
            }

            e.aiCooldown -= dt
            let p = state.player
            let dx = p.x - e.x
            let dy = p.y - e.y
            if e.hurtTimer <= 0 && e.attackTimer <= 0 {
                let dist = hypot(dx, dy)
                if dist > 70 {
                    let nx = dx / max(dist, 1)
                    let ny = dy / max(dist, 1)
                    e.vx = nx * 90
                    e.vy = ny * 55
                    e.facing = dx >= 0 ? 1 : -1
                    e.anim = .walk
                } else {
                    e.vx = approach(e.vx, 0, rate: 800, dt: dt)
                    e.vy = approach(e.vy, 0, rate: 800, dt: dt)
                    e.anim = .idle
                    if e.aiCooldown <= 0 {
                        e.attackActive = true
                        e.attackTimer = 0.4
                        e.attackHit = false
                        e.attackKind = .punch
                        e.anim = .attack
                        e.animTime = 0
                        e.aiCooldown = 1.1
                    }
                }
            }

            if e.attackTimer > 0 {
                e.attackTimer -= dt
                if e.attackTimer < 0.25 && e.attackActive && !e.attackHit {
                    tryHitPlayer(from: e)
                    e.attackHit = true
                }
                if e.attackTimer <= 0 {
                    e.attackActive = false
                    e.attackKind = nil
                }
            }

            e.x += e.vx * dt
            e.y += e.vy * dt
            e.y = max(laneMin, min(laneMax, e.y))
            e.animTime += dt
            advanceAnimFrame(&e)
            state.enemies[i] = e
        }

        applyPlayerHits()
        state.enemies.removeAll { $0.dead && $0.deathTimer > 1.2 }
    }

    private func tryHitPlayer(from e: Fighter) {
        let p = state.player
        guard !p.dead, p.invulnTimer <= 0 else { return }
        if abs(e.x - p.x) < 70 && abs(e.y - p.y) < 36 && abs(e.z - p.z) < 50 {
            applyHitToPlayer(damage: 8, fromX: e.x)
        }
    }

    private func applyHitToPlayer(damage: CGFloat, fromX: CGFloat) {
        var p = state.player
        p.hp -= damage
        p.hurtTimer = 0.35
        p.invulnTimer = 0.55
        p.flash = 0.2
        p.vx = (p.x >= fromX ? 1 : -1) * 180
        p.anim = .hurt
        p.animTime = 0
        state.shake = max(state.shake, 0.25)
        state.hitStop = 0.05
        onSfx?("hurt")
        if p.hp <= 0 {
            p.hp = 0
            p.dead = true
            p.anim = .dead
            state.phase = .gameover
            state.message = "GAME OVER"
            state.messageTimer = 99
            onSfx?("ko")
        }
        state.player = p
        spawnImpact(x: p.x, y: p.y - p.z)
    }

    private func applyPlayerHits() {
        var p = state.player
        guard p.attackActive, !p.attackHit || p.attackKind == .special else { return }
        let kind = p.attackKind ?? .punch
        let range: CGFloat = kind == .special ? 140 : (kind == .kick ? 78 : 58)
        let damage: CGFloat = kind == .special ? 34 : (kind == .kick ? 16 : 10)

        for i in state.enemies.indices {
            var e = state.enemies[i]
            if e.dead || e.invulnTimer > 0 { continue }
            if kind == .special, p.specialHitIds.contains(e.id) { continue }
            let ahead = (e.x - p.x) * p.facing
            if ahead > -10 && ahead < range && abs(e.y - p.y) < 40 && abs(e.z - p.z) < 60 {
                e.hp -= damage
                e.hurtTimer = 0.3
                e.invulnTimer = 0.2
                e.flash = 0.15
                e.vx = p.facing * (kind == .kick ? 260 : 160)
                e.facing = -p.facing
                e.anim = .hurt
                e.animTime = 0
                if kind == .special {
                    p.specialHitIds.append(e.id)
                } else {
                    p.attackHit = true
                }
                p.combo += 1
                p.comboTimer = 1.2
                state.specialMeter = min(100, state.specialMeter + (kind == .special ? 0 : 12))
                state.score += e.scoreValue / 10
                state.shake = max(state.shake, 0.2)
                state.hitStop = kind == .special ? 0.08 : 0.04
                spawnImpact(x: e.x, y: e.y - e.z)
                onSfx?("hurt")
                if e.hp <= 0 {
                    e.hp = 0
                    e.dead = true
                    e.anim = .dead
                    state.score += e.scoreValue
                    state.waveEnemiesLeft = max(0, state.waveEnemiesLeft - 1)
                    onSfx?("ko")
                }
                state.enemies[i] = e
            }
        }
        state.player = p
    }

    private func spawnImpact(x: CGFloat, y: CGFloat) {
        state.particles.append(Particle(
            x: x, y: y, vx: 0, vy: -20,
            life: 0.25, maxLife: 0.25, frame: 0, kind: .impact
        ))
    }

    private func updateBullets(dt: CGFloat) {
        guard !state.bullets.isEmpty else { return }
        for i in state.bullets.indices {
            state.bullets[i].x += state.bullets[i].vx * dt
            state.bullets[i].life -= dt
        }
        for bi in state.bullets.indices {
            var b = state.bullets[bi]
            for ei in state.enemies.indices {
                var e = state.enemies[ei]
                if e.dead || b.hitIds.contains(e.id) { continue }
                if abs(e.x - b.x) < 40 && abs(e.y - b.y) < 36 {
                    e.hp -= b.damage
                    e.hurtTimer = 0.25
                    e.flash = 0.12
                    b.hitIds.append(e.id)
                    onSfx?("hurt")
                    if e.hp <= 0 {
                        e.dead = true
                        e.anim = .dead
                        state.score += e.scoreValue
                        state.waveEnemiesLeft = max(0, state.waveEnemiesLeft - 1)
                        onSfx?("ko")
                        if state.hasGun {
                            state.speechBubble = SpeechBubble(
                                text: "Counting or not counting gang violence?",
                                life: 2.0,
                                maxLife: 2.0
                            )
                        }
                    }
                    state.enemies[ei] = e
                    spawnImpact(x: e.x, y: e.y - e.z)
                }
            }
            state.bullets[bi] = b
        }
        state.bullets.removeAll { $0.life <= 0 }
    }

    private func updateParticles(dt: CGFloat) {
        for i in state.particles.indices {
            state.particles[i].life -= dt
            state.particles[i].x += state.particles[i].vx * dt
            state.particles[i].y += state.particles[i].vy * dt
        }
        state.particles.removeAll { $0.life <= 0 }
        if var bubble = state.speechBubble {
            bubble.life -= dt
            state.speechBubble = bubble.life > 0 ? bubble : nil
        }
        for i in state.floats.indices {
            state.floats[i].life -= dt
            state.floats[i].y -= 30 * dt
        }
        state.floats.removeAll { $0.life <= 0 }
    }

    private func updateCamera(dt: CGFloat) {
        let target = state.player.x - 280
        state.cameraX += (target - state.cameraX) * min(1, dt * 6)
        state.cameraX = max(0, min(state.stageWidth - 800, state.cameraX))
    }

    private func updateWave(dt: CGFloat) {
        if state.spawnQueue > 0 {
            state.spawnTimer -= dt
            if state.spawnTimer <= 0 {
                spawnEnemy()
                state.spawnQueue -= 1
                state.spawnTimer = 0.55
            }
        }

        if state.phase == .playing,
           state.spawnQueue == 0,
           state.enemies.allSatisfy(\.dead) || state.enemies.isEmpty,
           state.waveEnemiesLeft <= 0 {
            if state.wave >= state.maxWaves {
                state.phase = .victory
                state.player.anim = .victory
                state.message = "NIGHT CLEARED"
                state.messageTimer = 99
                onSfx?("victory")
            } else {
                state.phase = .waveClear
                state.message = "WAVE CLEAR"
                state.messageTimer = 1.6
                state.smokePuffTimer = 1.6
                onSfx?("waveClear")
                onSfx?("smoke")
            }
        }

        if state.phase == .waveClear {
            state.smokePuffTimer -= dt
            if state.smokePuffTimer <= 0 {
                state.wave += 1
                if state.wave > 3 { state.hasGun = true }
                state.phase = .playing
                let count = 3 + state.wave
                state.waveEnemiesLeft = count
                state.spawnQueue = count
                state.spawnTimer = 0.3
                state.message = state.hasGun && state.wave == 4 ? "GUN UNLOCKED — WAVE \(state.wave)" : "WAVE \(state.wave)"
                state.messageTimer = 2
            }
        }
    }

    private func spawnEnemy() {
        let types = EnemyType.allCases
        let t = types[state.waveEnemiesLeft % types.count]
        let id = nextId
        nextId += 1
        let side: CGFloat = Bool.random() ? 1 : -1
        let x = state.player.x + side * CGFloat.random(in: 320...480)
        let hp: CGFloat = t == .maga ? 70 : (t == .biz ? 40 : 50)
        state.enemies.append(Fighter(
            id: id,
            kind: .enemy,
            enemyType: t,
            x: max(80, min(state.stageWidth - 80, x)),
            y: CGFloat.random(in: laneMin...laneMax),
            z: 0,
            zVel: 0,
            vx: 0,
            vy: 0,
            facing: side < 0 ? 1 : -1,
            hp: hp,
            maxHp: hp,
            anim: .idle,
            animTime: 0,
            animFrame: 0,
            attackTimer: 0,
            attackActive: false,
            attackHit: false,
            attackKind: nil,
            specialHitIds: [],
            hurtTimer: 0,
            invulnTimer: 0.2,
            combo: 0,
            comboTimer: 0,
            dead: false,
            deathTimer: 0,
            aiCooldown: CGFloat.random(in: 0.2...0.8),
            flash: 0,
            scoreValue: t == .maga ? 300 : 150,
            scale: t == .maga ? 1.1 : 1,
            bodyW: 48,
            bodyH: 96
        ))
    }
}
