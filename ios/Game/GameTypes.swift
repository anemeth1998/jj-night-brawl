import Foundation
import CoreGraphics

enum GamePhase: String, Equatable {
    case title, playing, paused, waveClear, victory, gameover
}

enum AnimName: String {
    case idle, walk, attack, hurt, dead, jump, smoke, victory
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
    var wave: Int = 0
    var maxWaves: Int = 5
    var waveEnemiesLeft: Int = 0
    var spawnQueue: Int = 0
    var spawnTimer: CGFloat = 0
    var shake: CGFloat = 0
    var hitStop: CGFloat = 0
    var message: String = ""
    var messageTimer: CGFloat = 0
    var specialMeter: CGFloat = 0
    /// Unlocked after clearing wave 3
    var hasGun: Bool = false
    var keys: Set<String> = []
    var touch = TouchState()
    var actionQueue: [AttackKind] = []
    var jumpQueued = false
    var elapsed: CGFloat = 0
    var stageWidth: CGFloat = 2800
    var riffPulse: CGFloat = 0
    var riffPulseLife: CGFloat = 0
    var smokePuffTimer: CGFloat = 0

    init(player: Fighter) {
        self.player = player
    }
}
