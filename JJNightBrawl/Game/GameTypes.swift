import Foundation
import CoreGraphics

enum GamePhase: String, Equatable {
    case title, mainMenu, charSelect, playing, paused, waveClear, stageClear, loading, victory, gameover
}

enum AnimName: String {
    case idle, walk, run, attack, hurt, dead, jump, smoke, victory
    /// Floored by a finisher (hook / roundhouse / air kick / dash) or dying. Sheet: `<who>_knockdown`,
    /// falling back to `hurt`.
    case knockdown
}

enum AttackKind: String {
    case punch, kick, special, gun
}

/// Which procedural swing / impact cue a move plays (see GameAudio).
enum MoveSFX: String, Equatable {
    case jab, cross, hook, kick, roundhouse, airKick, dash, special, gun
}

/// One concrete attack: a chain step (jab → cross → hook), a situational variant (air kick, dash
/// punch) or a one-off (riff, gun). Timings in seconds; `activeLo/Hi` are normalised 0…1 over
/// `duration`. Replaces the per-kind constant tables that used to live in GameEngine.
struct MoveDef: Equatable {
    var kind: AttackKind
    /// Chain step (0-based) or `MoveTable.airVariant` / `MoveTable.dashVariant`.
    var variant: Int
    /// Sheet suffix — resolves to `<fighter>_<sheetKey>` (e.g. `jj_punch2`), falling back to the
    /// fighter's base `attack` / `kick` atlas while art is pending.
    var sheetKey: String
    var duration: CGFloat
    var activeLo: CGFloat
    var activeHi: CGFloat
    var damage: CGFloat
    var knockback: CGFloat
    var hitStop: CGFloat
    /// Forward shove on start (grounded only).
    var lunge: CGFloat
    /// Preferred frame count when the sheet is missing (a loaded sheet's `frameCount` wins).
    var frames: Int
    var reach: CGFloat
    var hitHeight: CGFloat
    var hitYOff: CGFloat
    var depthTol: CGFloat
    var knocksDown: Bool
    var shake: CGFloat
    /// Normalised time after which the next chain input may cancel this move (1 = never).
    var chainWindow: CGFloat
    /// Seconds after the move ends where the chain still continues from the next step.
    var chainGrace: CGFloat
    var sfx: MoveSFX

    var active: (CGFloat, CGFloat) { (activeLo, activeHi) }
}

/// The moveset. Fighters share the table; `move(kind:variant:fighter:)` applies per-fighter feel.
enum MoveTable {
    static let airVariant = 10
    static let dashVariant = 11
    static let enemyTelegraph: CGFloat = 0.18
    static let knockdownDuration: CGFloat = 0.85

    // Punch chain — jab, cross, hook (finisher floors).
    static let jab = MoveDef(
        kind: .punch, variant: 0, sheetKey: "punch1", duration: 0.26, activeLo: 0.10, activeHi: 0.30,
        damage: 9, knockback: 120, hitStop: 0.04, lunge: 130, frames: 4,
        reach: 40, hitHeight: 28, hitYOff: 30, depthTol: 32, knocksDown: false, shake: 3,
        chainWindow: 0.55, chainGrace: 0.28, sfx: .jab
    )
    static let cross = MoveDef(
        kind: .punch, variant: 1, sheetKey: "punch2", duration: 0.30, activeLo: 0.12, activeHi: 0.34,
        damage: 12, knockback: 160, hitStop: 0.05, lunge: 150, frames: 4,
        reach: 44, hitHeight: 28, hitYOff: 30, depthTol: 32, knocksDown: false, shake: 4,
        chainWindow: 0.60, chainGrace: 0.28, sfx: .cross
    )
    static let hook = MoveDef(
        kind: .punch, variant: 2, sheetKey: "punch3", duration: 0.42, activeLo: 0.22, activeHi: 0.44,
        damage: 17, knockback: 280, hitStop: 0.07, lunge: 170, frames: 4,
        reach: 46, hitHeight: 32, hitYOff: 30, depthTol: 34, knocksDown: true, shake: 7,
        chainWindow: 0.78, chainGrace: 0, sfx: .hook
    )
    static let punchChain: [MoveDef] = [jab, cross, hook]

    // Kick chain — kick, roundhouse (finisher floors).
    static let kick = MoveDef(
        kind: .kick, variant: 0, sheetKey: "kick1", duration: 0.44, activeLo: 0.14, activeHi: 0.36,
        damage: 18, knockback: 220, hitStop: 0.06, lunge: 220, frames: 4,
        reach: 52, hitHeight: 30, hitYOff: 36, depthTol: 40, knocksDown: false, shake: 4,
        chainWindow: 0.62, chainGrace: 0.28, sfx: .kick
    )
    static let roundhouse = MoveDef(
        kind: .kick, variant: 1, sheetKey: "kick2", duration: 0.56, activeLo: 0.28, activeHi: 0.52,
        damage: 24, knockback: 320, hitStop: 0.08, lunge: 200, frames: 4,
        reach: 60, hitHeight: 34, hitYOff: 36, depthTol: 40, knocksDown: true, shake: 8,
        chainWindow: 0.80, chainGrace: 0, sfx: .roundhouse
    )
    static let kickChain: [MoveDef] = [kick, roundhouse]

    // Situational.
    static let airPunch = MoveDef(
        kind: .punch, variant: airVariant, sheetKey: "punch1", duration: 0.28, activeLo: 0.10, activeHi: 0.40,
        damage: 10, knockback: 150, hitStop: 0.04, lunge: 0, frames: 4,
        reach: 40, hitHeight: 30, hitYOff: 30, depthTol: 34, knocksDown: false, shake: 3,
        chainWindow: 1, chainGrace: 0, sfx: .jab
    )
    static let airKick = MoveDef(
        kind: .kick, variant: airVariant, sheetKey: "airkick", duration: 0.40, activeLo: 0.12, activeHi: 0.55,
        damage: 20, knockback: 240, hitStop: 0.06, lunge: 0, frames: 4,
        reach: 52, hitHeight: 34, hitYOff: 30, depthTol: 40, knocksDown: true, shake: 5,
        chainWindow: 1, chainGrace: 0, sfx: .airKick
    )
    static let dash = MoveDef(
        kind: .punch, variant: dashVariant, sheetKey: "dash", duration: 0.38, activeLo: 0.10, activeHi: 0.48,
        damage: 16, knockback: 300, hitStop: 0.06, lunge: 380, frames: 4,
        reach: 46, hitHeight: 30, hitYOff: 30, depthTol: 36, knocksDown: true, shake: 6,
        chainWindow: 1, chainGrace: 0, sfx: .dash
    )
    static let special = MoveDef(
        kind: .special, variant: 0, sheetKey: "special", duration: 0.95, activeLo: 0.18, activeHi: 0.82,
        damage: 22, knockback: 340, hitStop: 0, lunge: 0, frames: 4,
        reach: 0, hitHeight: 0, hitYOff: 0, depthTol: 0, knocksDown: false, shake: 2,
        chainWindow: 1, chainGrace: 0, sfx: .special
    )
    static let gun = MoveDef(
        kind: .gun, variant: 0, sheetKey: "attack", duration: 0.42, activeLo: 0.08, activeHi: 0.22,
        damage: 28, knockback: 260, hitStop: 0.04, lunge: 0, frames: 4,
        reach: 0, hitHeight: 0, hitYOff: 0, depthTol: 0, knocksDown: false, shake: 5,
        chainWindow: 1, chainGrace: 0, sfx: .gun
    )

    // Enemies: single-step punch / kick with the classic timings; they never chain.
    static let enemyPunch = MoveDef(
        kind: .punch, variant: 0, sheetKey: "attack", duration: 0.30, activeLo: 0.08, activeHi: 0.26,
        damage: 11, knockback: 140, hitStop: 0.045, lunge: 140, frames: 4,
        reach: 40, hitHeight: 28, hitYOff: 30, depthTol: 32, knocksDown: false, shake: 4,
        chainWindow: 1, chainGrace: 0, sfx: .jab
    )
    static let enemyKick = MoveDef(
        kind: .kick, variant: 0, sheetKey: "attack", duration: 0.44, activeLo: 0.14, activeHi: 0.36,
        damage: 18, knockback: 220, hitStop: 0.06, lunge: 220, frames: 4,
        reach: 52, hitHeight: 30, hitYOff: 36, depthTol: 40, knocksDown: false, shake: 4,
        chainWindow: 1, chainGrace: 0, sfx: .kick
    )

    /// Suit (biz) follow-up jab — shorter, lighter, near-zero wind-up.
    static let enemyPunch2 = MoveDef(
        kind: .punch, variant: 1, sheetKey: "attack", duration: 0.26, activeLo: 0.10, activeHi: 0.30,
        damage: 8, knockback: 150, hitStop: 0.045, lunge: 120, frames: 4,
        reach: 42, hitHeight: 28, hitYOff: 30, depthTol: 32, knocksDown: false, shake: 4,
        chainWindow: 1, chainGrace: 0, sfx: .cross
    )

    static func enemyMove(_ kind: AttackKind, variant: Int = 0) -> MoveDef {
        if kind == .kick { return enemyKick }
        return variant > 0 ? enemyPunch2 : enemyPunch
    }

    /// Base move for a kind + variant. Unknown variants fall back to step 0.
    static func base(kind: AttackKind, variant: Int) -> MoveDef {
        switch kind {
        case .punch:
            if variant == airVariant { return airPunch }
            if variant == dashVariant { return dash }
            return punchChain[min(max(0, variant), punchChain.count - 1)]
        case .kick:
            if variant == airVariant { return airKick }
            return kickChain[min(max(0, variant), kickChain.count - 1)]
        case .special: return special
        case .gun: return gun
        }
    }

    /// Next chain step after `move`, or nil when the chain is finished / not chainable.
    static func nextInChain(after move: MoveDef) -> MoveDef? {
        guard move.variant < airVariant else { return nil }
        switch move.kind {
        case .punch: return move.variant + 1 < punchChain.count ? punchChain[move.variant + 1] : nil
        case .kick: return move.variant + 1 < kickChain.count ? kickChain[move.variant + 1] : nil
        default: return nil
        }
    }

    /// Per-fighter feel: Han is quick and light, Andrew slow and heavy, JJ is the baseline.
    static func move(kind: AttackKind, variant: Int, fighter: String?) -> MoveDef {
        var m = base(kind: kind, variant: variant)
        guard let fighter, kind == .punch || kind == .kick else { return m }
        switch fighter.lowercased() {
        case "han":
            m.duration *= 0.88
            m.damage = (m.damage * 0.9).rounded()
            m.lunge *= 1.08
        case "andrew":
            m.duration *= 1.08
            m.damage = (m.damage * 1.15).rounded()
            m.knockback *= 1.1
        default:
            break
        }
        return m
    }
}

enum EnemyType: String, CaseIterable {
    case biz, maga, gothm, gothf
}

enum ParticleKind {
    case impact, spark, wave, note, smoke, muzzle
}

/// Named unlocks — never “global wave == 3”.
enum UnlockFlag: String, Equatable {
    case hasGun
    case riffTier2
}

/// Story = Act I campaign (no char wall). Endless = char select then brawl.
enum PlayMode: String, Equatable {
    case story, endless
}

struct WaveSpawn: Equatable {
    var type: EnemyType
    var count: Int
    /// Last N of this entry are elites (fat HP + telegraph).
    var eliteCount: Int = 0
}

struct WaveDef: Equatable {
    var spawns: [WaveSpawn]
    var hpScale: CGFloat
    var telegraphMul: CGFloat
    var banner: String
    var subtitle: String

    var totalCount: Int { spawns.reduce(0) { $0 + $1.count } }

    /// Flatten into ordered spawn types; elites always last in the wave.
    func spawnList() -> [(type: EnemyType, elite: Bool)] {
        var normals: [(EnemyType, Bool)] = []
        var elites: [(EnemyType, Bool)] = []
        for s in spawns {
            let normal = max(0, s.count - s.eliteCount)
            for _ in 0..<normal { normals.append((s.type, false)) }
            for _ in 0..<s.eliteCount { elites.append((s.type, true)) }
        }
        return normals + elites
    }
}

struct StageDef: Equatable {
    var id: String
    var act: Int
    var name: String
    var waves: [WaveDef]
    /// Applied when this stage is cleared (before continue).
    var unlocksOnClear: [UnlockFlag]
    var zineLines: [String]
    var isFinale: Bool
    /// Location card shown on the loading screen / stage banner (from assets/Background/stages.json).
    var title: String = ""
    var subtitle: String = ""
    /// Walkable width in world units — a tight rooftop plays differently from a boulevard.
    var width: CGFloat = 2800

    var displayTitle: String { title.isEmpty ? name : title }
}

enum CampaignData {
    /// P0 feel slice: Stage 1 is a single 2-foe wave so punch/kick/jump is readable.
    /// Flip false to restore the full 4-wave Alley Warmup.
    static let p0OneTightWave = false

    /// Act I: Stages 1–4 dense (gun unlock on Stage 3 clear), Stage 5 finale on the water tower.
    static let stages: [StageDef] = [
        StageDef(
            id: "i-1-alley",
            act: 1,
            name: "Alley Warmup",
            waves: p0OneTightWave ? [
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .biz, count: 2)
                    ],
                    hpScale: 1.0,
                    telegraphMul: 1.2,
                    banner: "FIST CHECK",
                    subtitle: "Punch, kick, jump."
                )
            ] : [
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .biz, count: 2),
                        WaveSpawn(type: .gothm, count: 1)
                    ],
                    hpScale: 1.0,
                    telegraphMul: 1.0,
                    banner: "ALLEY WARMUP",
                    subtitle: "Warm up the fists."
                ),
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .biz, count: 2),
                        WaveSpawn(type: .gothm, count: 1),
                        WaveSpawn(type: .gothf, count: 1)
                    ],
                    hpScale: 1.1,
                    telegraphMul: 1.0,
                    banner: "MORE SCOUTS",
                    subtitle: "They're buying the door."
                ),
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .biz, count: 3),
                        WaveSpawn(type: .gothm, count: 1),
                        WaveSpawn(type: .maga, count: 1)
                    ],
                    hpScale: 1.2,
                    telegraphMul: 1.05,
                    banner: "BADGE + PIN",
                    subtitle: "First taste of the parade."
                ),
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .biz, count: 3, eliteCount: 1),
                        WaveSpawn(type: .maga, count: 2),
                        WaveSpawn(type: .gothf, count: 1)
                    ],
                    hpScale: 1.35,
                    telegraphMul: 1.15,
                    banner: "LAST CALL",
                    subtitle: "Peak Stage 1 — elite scout inbound."
                )
            ],
            unlocksOnClear: [],
            zineLines: [
                "Corp scouts buy the door.",
                "JJ doesn't sell."
            ],
            isFinale: false,
            title: "Downtown Junction City",
            subtitle: "Washington Street after midnight",
            width: 2800
        ),
        StageDef(
            id: "i-2-dock",
            act: 1,
            name: "Loading Dock",
            waves: [
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .biz, count: 2),
                        WaveSpawn(type: .maga, count: 1),
                        WaveSpawn(type: .gothm, count: 1)
                    ],
                    hpScale: 1.15,
                    telegraphMul: 1.05,
                    banner: "LOADING DOCK",
                    subtitle: "Red hats showed up to help."
                ),
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .biz, count: 2),
                        WaveSpawn(type: .maga, count: 2),
                        WaveSpawn(type: .gothf, count: 1)
                    ],
                    hpScale: 1.25,
                    telegraphMul: 1.1,
                    banner: "DOCK CREW",
                    subtitle: "Keep the bite."
                ),
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .biz, count: 2),
                        WaveSpawn(type: .maga, count: 3),
                        WaveSpawn(type: .gothm, count: 1)
                    ],
                    hpScale: 1.35,
                    telegraphMul: 1.15,
                    banner: "FLYER CREW",
                    subtitle: "Smile for the camera."
                ),
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .biz, count: 2),
                        WaveSpawn(type: .maga, count: 4, eliteCount: 1),
                        WaveSpawn(type: .gothf, count: 1)
                    ],
                    hpScale: 1.45,
                    telegraphMul: 1.25,
                    banner: "SHIFT END",
                    subtitle: "Peak dock — elite parade inbound."
                )
            ],
            unlocksOnClear: [],
            zineLines: [
                "Red hats show up \"to help the kids.\"",
                "Smile for the flyer. Break the jaw."
            ],
            isFinale: false,
            title: "Yard & Overpass",
            subtitle: "I-70 · freight siding",
            width: 3000
        ),
        StageDef(
            id: "i-3-club",
            act: 1,
            name: "Club Floor",
            waves: [
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .biz, count: 2),
                        WaveSpawn(type: .maga, count: 2),
                        WaveSpawn(type: .gothm, count: 1)
                    ],
                    hpScale: 1.3,
                    telegraphMul: 1.1,
                    banner: "CLUB FLOOR",
                    subtitle: "Badges and pins. Same goons."
                ),
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .biz, count: 2),
                        WaveSpawn(type: .maga, count: 2),
                        WaveSpawn(type: .gothm, count: 1),
                        WaveSpawn(type: .gothf, count: 1)
                    ],
                    hpScale: 1.4,
                    telegraphMul: 1.15,
                    banner: "PIN CHECK",
                    subtitle: "Same jackets. Worse bosses."
                ),
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .biz, count: 3),
                        WaveSpawn(type: .maga, count: 2),
                        WaveSpawn(type: .gothf, count: 1)
                    ],
                    hpScale: 1.5,
                    telegraphMul: 1.2,
                    banner: "SECURITY",
                    subtitle: "Badges don't stop kicks."
                ),
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .biz, count: 3, eliteCount: 1),
                        WaveSpawn(type: .maga, count: 3),
                        WaveSpawn(type: .gothm, count: 1)
                    ],
                    hpScale: 1.6,
                    telegraphMul: 1.35,
                    banner: "LAST SONG",
                    subtitle: "Clear the floor — heat comes after."
                )
            ],
            // Gun on Stage 3→4 continue (stageClear), not mid-wave.
            unlocksOnClear: [.hasGun],
            zineLines: [
                "Security badges + campaign pins.",
                "Same goons. Now you're packin' heat."
            ],
            isFinale: false,
            title: "Hoover Opera Alley",
            subtitle: "C.L. Hoover Opera House · 7th Street",
            width: 2600
        ),
        StageDef(
            id: "i-4-midtown",
            act: 1,
            name: "Midtown March",
            waves: [
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .maga, count: 2),
                        WaveSpawn(type: .biz, count: 2),
                        WaveSpawn(type: .gothm, count: 1)
                    ],
                    hpScale: 1.45,
                    telegraphMul: 1.2,
                    banner: "MIDTOWN",
                    subtitle: "They stole the leather look."
                ),
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .maga, count: 3),
                        WaveSpawn(type: .biz, count: 2),
                        WaveSpawn(type: .gothf, count: 1)
                    ],
                    hpScale: 1.55,
                    telegraphMul: 1.25,
                    banner: "MARCH",
                    subtitle: "Keep the bite."
                ),
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .maga, count: 3),
                        WaveSpawn(type: .biz, count: 2),
                        WaveSpawn(type: .gothm, count: 1)
                    ],
                    hpScale: 1.65,
                    telegraphMul: 1.3,
                    banner: "BULLHORN",
                    subtitle: "Louder jackets. Same script."
                ),
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .maga, count: 4, eliteCount: 1),
                        WaveSpawn(type: .biz, count: 2),
                        WaveSpawn(type: .gothf, count: 1)
                    ],
                    hpScale: 1.75,
                    telegraphMul: 1.4,
                    banner: "BLOCKADE",
                    subtitle: "Peak Act I — elite parade last."
                )
            ],
            unlocksOnClear: [],
            zineLines: [
                "They stole the leather look.",
                "Keep the bite."
            ],
            isFinale: false,
            title: "Geary Blvd Strip",
            subtitle: "Sodium lights · empty lot",
            width: 3200
        ),
        // Act I finale — a tight tar roof, every faction's elites, the whole town watching.
        StageDef(
            id: "i-5-tower",
            act: 1,
            name: "Water Tower Roof",
            waves: [
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .gothm, count: 2),
                        WaveSpawn(type: .gothf, count: 2),
                        WaveSpawn(type: .biz, count: 1)
                    ],
                    hpScale: 1.7,
                    telegraphMul: 1.3,
                    banner: "ROOFTOP",
                    subtitle: "Nowhere left to run. Good."
                ),
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .maga, count: 3, eliteCount: 1),
                        WaveSpawn(type: .biz, count: 2, eliteCount: 1),
                        WaveSpawn(type: .gothm, count: 1)
                    ],
                    hpScale: 1.85,
                    telegraphMul: 1.4,
                    banner: "STEEL LEGS",
                    subtitle: "Two elites. Mind the edge."
                ),
                WaveDef(
                    spawns: [
                        WaveSpawn(type: .biz, count: 2, eliteCount: 2),
                        WaveSpawn(type: .maga, count: 2, eliteCount: 1),
                        WaveSpawn(type: .gothf, count: 2, eliteCount: 1)
                    ],
                    hpScale: 2.2,
                    telegraphMul: 1.5,
                    banner: "THE BOARD",
                    subtitle: "Boss wave — every suit that signed the check."
                )
            ],
            unlocksOnClear: [],
            zineLines: [
                "Tar roof, steel legs, and the whole town watching from below.",
                "Act I closed. The town is yours tonight."
            ],
            isFinale: true,
            title: "Water Tower Roof",
            subtitle: "Above the prairie town",
            width: 2200
        )
    ]

    static func stage(at index: Int) -> StageDef? {
        guard stages.indices.contains(index) else { return nil }
        return stages[index]
    }
}

struct Fighter {
    var id: Int
    var kind: Kind
    var enemyType: EnemyType?
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat
    var zVel: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var facing: CGFloat // 1 or -1
    var hp: CGFloat
    var maxHp: CGFloat
    var anim: AnimName
    var animTime: CGFloat
    var animFrame: Int
    var attackTimer: CGFloat
    var attackActive: Bool
    var attackHit: Bool
    var attackKind: AttackKind?
    var specialHitIds: [Int]
    var hurtTimer: CGFloat
    var invulnTimer: CGFloat
    var combo: Int
    var comboTimer: CGFloat
    var dead: Bool
    var deathTimer: CGFloat
    var aiCooldown: CGFloat
    var flash: CGFloat
    var scoreValue: Int
    var scale: CGFloat
    var bodyW: CGFloat
    var bodyH: CGFloat
    /// Elite: longer telegraph, fatter HP (existing art).
    var isElite: Bool = false
    var telegraphMul: CGFloat = 1.0
    /// Moveset — which step / situational variant of `attackKind` is running (see MoveTable).
    var attackVariant: Int = 0
    /// Grace left to continue the chain after a move ended; `chainKind` is the chain it belongs to.
    var chainTimer: CGFloat = 0
    var chainKind: AttackKind?
    /// Enemy wind-up hold before the swing (frame 0, no hitbox).
    var telegraphTimer: CGFloat = 0
    /// Floored by a finisher — long stagger, fall anim, no juggling.
    var knockedDown: Bool = false
    /// Last frame that played a footstep, so a held frame never re-triggers.
    var lastStepFrame: Int = -1

    enum Kind { case player, enemy }
}

struct Particle {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    var maxLife: CGFloat
    var frame: Int
    var kind: ParticleKind
    var radius: CGFloat?
    var colorHex: String?
}

struct FloatingText {
    var x: CGFloat
    var y: CGFloat
    var text: String
    var life: CGFloat
    var colorHex: String
}

struct SpeechBubble {
    var text: String
    var life: CGFloat
    var maxLife: CGFloat
}

struct Bullet {
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat
    var vx: CGFloat
    var facing: CGFloat
    var life: CGFloat
    var damage: CGFloat
    var hitIds: [Int]
}

struct TouchState {
    var left = false
    var right = false
    var up = false
    var down = false
    /// Analog stick axes in -1...1 (0 when idle).
    var axisX: CGFloat = 0
    var axisY: CGFloat = 0
}

final class GameState {
    var phase: GamePhase = .title
    var player: Fighter
    var enemies: [Fighter] = []
    var particles: [Particle] = []
    var floats: [FloatingText] = []
    var speechBubble: SpeechBubble?
    var bullets: [Bullet] = []
    var cameraX: CGFloat = 0
    var score: Int = 0
    /// Wave index within current stage (1-based for banners).
    var wave: Int = 0
    /// Waves in current stage (replaces global maxWaves=5 demo).
    var maxWaves: Int = 4
    var waveEnemiesLeft: Int = 0
    var spawnQueue: Int = 0
    var spawnTimer: CGFloat = 0
    /// Ordered spawn plan for current wave (popped by updateSpawns).
    var pendingSpawns: [(type: EnemyType, elite: Bool)] = []
    var shake: CGFloat = 0
    var hitStop: CGFloat = 0
    var message: String = ""
    var messageTimer: CGFloat = 0
    var messageSubtitle: String = ""
    var specialMeter: CGFloat = 0
    /// Unlocked via StageDef.unlocksOnClear (.hasGun), not wave count.
    var hasGun: Bool = false
    var unlockFlags: Set<UnlockFlag> = []
    var actIndex: Int = 1
    var stageIndex: Int = 0
    var stageName: String = ""
    /// Menu pick: "jj" | "andrew" | "han" (combat sheets still JJ until atlases exist)
    var selectedFighter: String = "jj"
    var playMode: PlayMode = .story
    var zineText: String = ""
    var keys: Set<String> = []
    var touch = TouchState()
    var actionQueue: [AttackKind] = []
    var jumpQueued = false
    /// Early-press jump window (seconds). Bradford: 0.14s feel buffer.
    var jumpBufferTimer: CGFloat = 0
    var elapsed: CGFloat = 0
    var stageWidth: CGFloat = 2800
    var riffPulse: CGFloat = 0
    var riffPulseLife: CGFloat = 0
    var smokePuffTimer: CGFloat = 0
    /// Between-stage loading hold (seconds remaining). Phase stays `.loading` until 0.
    var loadingTimer: CGFloat = 0
    /// Stage index to enter when loading finishes (nil = none scheduled).
    var pendingStageIndex: Int?
    /// Current wave telegraph multiplier (copied into enemies).
    var waveTelegraphMul: CGFloat = 1.0
    var waveHpScale: CGFloat = 1.0
    /// Endless: how many times the campaign has wrapped (0 = first pass). Drives the difficulty
    /// ramp and score multiplier; always 0 in Story.
    var endlessLoop: Int = 0
    /// Endless: shuffled stage order for the current loop (indices into CampaignData.stages).
    var endlessOrder: [Int] = []
    /// Position inside `endlessOrder`.
    var endlessCursor: Int = 0
    /// Score multiplier — +25% per Endless loop, 1 in Story.
    var endlessScoreMultiplier: CGFloat {
        playMode == .endless ? 1 + 0.25 * CGFloat(endlessLoop) : 1
    }

    init(player: Fighter) {
        self.player = player
    }
}
