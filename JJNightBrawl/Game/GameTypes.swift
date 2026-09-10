import Foundation
import CoreGraphics

enum GamePhase: String, Equatable {
    case title, mainMenu, charSelect, playing, paused, waveClear, stageClear, loading, victory, gameover
}

enum AnimName: String {
    case idle, walk, run, attack, hurt, dead, jump, smoke, victory
}

enum AttackKind: String {
    case punch, kick, special, gun
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
}

enum CampaignData {
    /// P0 feel slice: Stage 1 is a single 2-foe wave so punch/kick/jump is readable.
    /// Flip false to restore the full 4-wave Alley Warmup.
    static let p0OneTightWave = true

    /// Act I Stages 1–4 dense (gun unlock on Stage 3 clear). Act II not stubbed yet.
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
            isFinale: false
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
            isFinale: false
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
            isFinale: false
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
            isFinale: false
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

    init(player: Fighter) {
        self.player = player
    }
}
