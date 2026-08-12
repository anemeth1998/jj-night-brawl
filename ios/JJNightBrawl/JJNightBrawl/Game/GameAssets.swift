import UIKit
import CoreGraphics

struct SpriteSheet {
    let image: UIImage
    let cols: Int
    let rows: Int
    var frameW: CGFloat { image.size.width / CGFloat(cols) }
    var frameH: CGFloat { image.size.height / CGFloat(rows) }
    var frameCount: Int { cols * rows }

    func draw(in ctx: CGContext, frame: Int, dest: CGRect, flipX: Bool) {
        let total = max(1, frameCount)
        let f = ((frame % total) + total) % total
        let col = f % cols
        let row = f / cols
        guard let cg = image.cgImage else { return }
        let scale = image.scale
        let crop = CGRect(
            x: CGFloat(col) * frameW * scale,
            y: CGFloat(row) * frameH * scale,
            width: frameW * scale,
            height: frameH * scale
        )
        guard let piece = cg.cropping(to: crop) else { return }
        ctx.saveGState()
        if flipX {
            ctx.translateBy(x: dest.midX, y: dest.midY)
            ctx.scaleBy(x: -1, y: 1)
            ctx.translateBy(x: -dest.midX, y: -dest.midY)
        }
        UIGraphicsPushContext(ctx)
        UIImage(cgImage: piece, scale: scale, orientation: .up).draw(in: dest)
        UIGraphicsPopContext()
        ctx.restoreGState()
    }
}

final class GameAssets {
    private(set) var jjIdle: SpriteSheet!
    private(set) var jjWalk: SpriteSheet!
    private(set) var jjAttack: SpriteSheet!
    private(set) var jjKick: SpriteSheet!
    private(set) var jjHurt: SpriteSheet!
    private(set) var jjJump: SpriteSheet!
    private(set) var jjSpecial: SpriteSheet!
    private(set) var jjSmoke: SpriteSheet!
    private(set) var jjVictory: SpriteSheet!
    private(set) var jjPortrait: UIImage?

    private var enemySheets: [String: SpriteSheet] = [:]
    private(set) var sky: UIImage?
    private(set) var farBg: UIImage?
    private(set) var midBg: UIImage?
    private(set) var impact: SpriteSheet?
    private(set) var ready = false

    func load() {
        jjIdle = must("jj_idle", 2, 2)
        jjWalk = must("jj_walk", 4, 2)
        jjAttack = must("jj_attack", 2, 2)
        jjKick = must("jj_kick", 2, 2)
        jjHurt = must("jj_hurt", 2, 2)
        jjJump = must("jj_jump", 2, 2)
        jjSpecial = must("jj_special", 2, 2)
        jjSmoke = must("jj_smoke", 2, 2)
        jjVictory = must("jj_victory", 2, 2)
        jjPortrait = UIImage(named: "jj_portrait")

        for t in ["biz", "maga", "gothm", "gothf"] {
            for a in ["idle", "walk", "attack"] {
                if let s = opt("en_\(t)_\(a)", 2, 2) {
                    enemySheets["\(t)_\(a)"] = s
                }
            }
        }
        impact = opt("fx_impact", 2, 2)
        sky = UIImage(named: "map_sky")
        farBg = UIImage(named: "map_far")
        midBg = UIImage(named: "map_mid")
        ready = jjIdle != nil && jjWalk != nil
    }

    func sheetForPlayer(anim: AnimName, attackKind: AttackKind?) -> SpriteSheet {
        switch anim {
        case .attack:
            if attackKind == .special { return jjSpecial ?? jjAttack }
            if attackKind == .kick { return jjKick ?? jjAttack }
            // Gun reuses punch pose + drawn pistol overlay
            return jjAttack
        case .hurt, .dead: return jjHurt ?? jjIdle
        case .jump: return jjJump ?? jjIdle
        case .smoke: return jjSmoke ?? jjIdle
        case .victory: return jjVictory ?? jjIdle
        case .walk: return jjWalk
        case .idle: return jjIdle
        }
    }

    func sheetForEnemy(type: EnemyType?, anim: AnimName) -> SpriteSheet {
        let t = type?.rawValue ?? "biz"
        let key: String
        switch anim {
        case .walk: key = "\(t)_walk"
        case .attack: key = "\(t)_attack"
        default: key = "\(t)_idle"
        }
        return enemySheets[key] ?? enemySheets["\(t)_idle"] ?? jjIdle
    }

    private func must(_ name: String, _ c: Int, _ r: Int) -> SpriteSheet? {
        guard let img = UIImage(named: name) else {
            print("[JJ] missing \(name) in Assets.xcassets")
            return nil
        }
        return SpriteSheet(image: img, cols: c, rows: r)
    }

    private func opt(_ name: String, _ c: Int, _ r: Int) -> SpriteSheet? {
        guard let img = UIImage(named: name) else { return nil }
        return SpriteSheet(image: img, cols: c, rows: r)
    }
}
