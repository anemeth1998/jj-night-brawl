import UIKit
import CoreGraphics

/// Draws one frame of the beat-em-up into a CGContext (960×540 logical).
enum GameRenderer {
    static let viewW: CGFloat = 960
    static let viewH: CGFloat = 540
    private static let laneTop: CGFloat = 310
    private static let laneBottom: CGFloat = 500

    static func render(ctx: CGContext, state: GameState, assets: GameAssets) {
        let shakeX = state.shake > 0 ? CGFloat.random(in: -1...1) * state.shake : 0
        let shakeY = state.shake > 0 ? CGFloat.random(in: -1...1) * state.shake : 0
        ctx.saveGState()
        ctx.translateBy(x: shakeX, y: shakeY)
        ctx.interpolationQuality = .none

        drawParallax(ctx: ctx, assets: assets, camX: state.cameraX)

        var fighters: [Fighter] = [state.player] + state.enemies
        fighters.sort { a, b in
            if a.y != b.y { return a.y < b.y }
            return a.z < b.z
        }
        for f in fighters {
            drawFighter(ctx: ctx, f: f, assets: assets, camX: state.cameraX)
        }
        if state.hasGun && !state.player.dead {
            drawPlayerGun(
                ctx: ctx,
                f: state.player,
                camX: state.cameraX,
                aiming: state.player.attackKind == .gun && state.player.attackTimer > 0
            )
        }

        drawSpeechBubble(ctx: ctx, state: state, camX: state.cameraX)
        drawParticles(ctx: ctx, state: state, assets: assets)
        drawBullets(ctx: ctx, state: state)
        drawFloats(ctx: ctx, state: state)

        ctx.restoreGState()

        if state.phase != .title {
            drawHud(ctx: ctx, state: state)
        }
    }

    // MARK: - Gun overlay

    private static func drawPlayerGun(ctx: CGContext, f: Fighter, camX: CGFloat, aiming: Bool) {
        let face = f.facing
        let hipX = f.x - camX + face * (aiming ? 22 : 10)
        let hipY = f.y - f.bodyH * f.scale * (aiming ? 0.52 : 0.42) - f.z
        ctx.saveGState()
        ctx.translateBy(x: hipX, y: hipY)
        ctx.scaleBy(x: face, y: 1)
        // grip
        ctx.setFillColor(UIColor(red: 0.1, green: 0.07, blue: 0.06, alpha: 1).cgColor)
        ctx.fill(CGRect(x: -4, y: 0, width: 7, height: 12))
        // slide / barrel
        ctx.setFillColor(UIColor(white: aiming ? 0.16 : 0.23, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: -4, width: aiming ? 28 : 18, height: 7))
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(CGRect(x: aiming ? 22 : 14, y: -2, width: aiming ? 8 : 5, height: 3))
        // accent
        ctx.setFillColor(UIColor(red: 1, green: 0.18, blue: 0.54, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 2, y: -4, width: 3, height: 7))
        ctx.restoreGState()
    }

    private static func drawBullets(ctx: CGContext, state: GameState) {
        for b in state.bullets {
            let bx = b.x - state.cameraX
            let by = b.y - b.z - 8
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 8, color: UIColor.orange.cgColor)
            ctx.setFillColor(UIColor(red: 1, green: 0.96, blue: 0.66, alpha: 1).cgColor)
            ctx.fill(CGRect(x: bx - 6, y: by - 2, width: 12, height: 4))
            ctx.setFillColor(UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1).cgColor)
            let trailX = b.facing > 0 ? bx - 10 : bx - 2
            ctx.fill(CGRect(x: trailX, y: by - 1, width: 8, height: 2))
            ctx.restoreGState()
        }
    }

    // MARK: - Parallax

    private static func drawParallax(ctx: CGContext, assets: GameAssets, camX: CGFloat) {
        if let sky = assets.sky {
            sky.draw(in: CGRect(x: 0, y: 0, width: viewW, height: viewH))
        } else {
            ctx.setFillColor(UIColor(red: 0.05, green: 0.03, blue: 0.1, alpha: 1).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: viewW, height: viewH))
        }

        if let far = assets.farBg {
            let farOff = (camX * 0.12).truncatingRemainder(dividingBy: viewW)
            for i in -1...1 {
                far.draw(in: CGRect(x: -farOff + CGFloat(i) * viewW, y: 40, width: viewW, height: viewH * 0.72))
            }
        }

        if let mid = assets.midBg {
            let midOff = (camX * 0.4).truncatingRemainder(dividingBy: viewW)
            let dstH = laneTop + 10
            for i in -1...1 {
                mid.draw(in: CGRect(x: -midOff + CGFloat(i) * viewW, y: 0, width: viewW, height: dstH))
            }
        }

        // Ground belt
        let beltTop = laneTop - 8
        let colors = [
            UIColor(red: 0.09, green: 0.06, blue: 0.14, alpha: 0.35).cgColor,
            UIColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 0.92).cgColor,
            UIColor(red: 0.03, green: 0.02, blue: 0.05, alpha: 1).cgColor
        ]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.2, 1]) {
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: beltTop),
                                   end: CGPoint(x: 0, y: viewH),
                                   options: [])
        }

        ctx.setStrokeColor(UIColor(red: 1, green: 0.18, blue: 0.54, alpha: 0.22).cgColor)
        ctx.setLineWidth(2)
        ctx.setLineDash(phase: 0, lengths: [16, 20])
        let lineY = (laneTop + laneBottom) / 2 + 18
        let lineOff = (camX * 0.85).truncatingRemainder(dividingBy: 36)
        ctx.move(to: CGPoint(x: -lineOff, y: lineY))
        ctx.addLine(to: CGPoint(x: viewW + 40, y: lineY))
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])
    }

    // MARK: - Fighters

    private static func drawFighter(ctx: CGContext, f: Fighter, assets: GameAssets, camX: CGFloat) {
        let sheet: SpriteSheet
        if f.kind == .player {
            sheet = assets.sheetForPlayer(anim: f.anim, attackKind: f.attackKind)
        } else {
            sheet = assets.sheetForEnemy(type: f.enemyType, anim: f.anim)
        }
        let scaleBoost: CGFloat = (f.kind == .player && f.attackKind == .special) ? 1.15 : 1
        let drawH = f.bodyH * f.scale * 0.95 * scaleBoost
        let aspect = sheet.frameW / max(1, sheet.frameH)
        let drawW = drawH * aspect
        let bob = walkBob(f)
        let dx = f.x - camX - drawW / 2
        let dy = f.y - drawH - f.z + bob

        // Shadow
        let shadowScale = max(0.35, 1 - f.z / 220)
        ctx.saveGState()
        ctx.setFillColor(UIColor(white: 0, alpha: 0.35 * shadowScale).cgColor)
        ctx.addEllipse(in: CGRect(x: f.x - camX - drawW * 0.28 * shadowScale,
                                  y: f.y - 12,
                                  width: drawW * 0.56 * shadowScale,
                                  height: 16 * shadowScale))
        ctx.fillPath()
        ctx.restoreGState()

        // Riff glow + bright silhouette rim for dark-street readability
        if f.kind == .player && f.attackKind == .special {
            ctx.saveGState()
            ctx.setFillColor(UIColor(red: 1, green: 0.18, blue: 0.54, alpha: 0.35).cgColor)
            ctx.addEllipse(in: CGRect(x: f.x - camX - drawW * 0.55,
                                      y: dy + drawH * 0.1,
                                      width: drawW * 1.1,
                                      height: drawH * 0.9))
            ctx.fillPath()
            ctx.restoreGState()
            // 4-dir bright rim (cheap outline) behind the sprite
            let rim = CGRect(x: dx, y: dy, width: drawW, height: drawH)
            for (ox, oy) in [(-2.0, 0.0), (2.0, 0.0), (0.0, -2.0), (0.0, 2.0)] {
                sheet.draw(in: ctx, frame: f.animFrame,
                           dest: rim.offsetBy(dx: CGFloat(ox), dy: CGFloat(oy)),
                           flipX: f.facing < 0)
            }
            ctx.saveGState()
            ctx.setBlendMode(.sourceAtop)
            ctx.setFillColor(UIColor(red: 1, green: 0.85, blue: 0.95, alpha: 0.85).cgColor)
            let rimPad = rim.insetBy(dx: -2, dy: -2)
            ctx.fill(rimPad)
            ctx.restoreGState()
        }

        if f.dead {
            ctx.setAlpha(max(0, f.deathTimer / 0.9))
        } else if f.invulnTimer > 0 && Int(f.invulnTimer * 20) % 2 == 0 && f.kind == .player && f.attackKind != .special {
            ctx.setAlpha(0.55)
        }

        let flip = f.facing < 0
        let dest = CGRect(x: dx, y: dy, width: drawW, height: drawH)
        sheet.draw(in: ctx, frame: f.animFrame, dest: dest, flipX: flip)
        // Hit flash: tint only sprite coverage (sourceAtop), never a solid white box.
        if f.flash > 0 {
            ctx.saveGState()
            let a = min(1, f.flash / 0.12) * 0.7
            ctx.setBlendMode(.sourceAtop)
            ctx.setFillColor(UIColor.white.withAlphaComponent(a).cgColor)
            ctx.fill(dest)
            ctx.restoreGState()
        }
        ctx.setAlpha(1)

        // Enemy overhead health bar (always visible while alive)
        if f.kind == .enemy && !f.dead {
            drawEnemyHealthBar(ctx: ctx, f: f, camX: camX, spriteTop: dy)
        }
    }

    private static func drawEnemyHealthBar(ctx: CGContext, f: Fighter, camX: CGFloat, spriteTop: CGFloat) {
        let bw: CGFloat = 48
        let bh: CGFloat = 6
        let bx = f.x - camX - bw / 2
        let by = spriteTop - 14
        let pct = max(0, min(1, f.hp / max(1, f.maxHp)))

        // Backdrop
        roundRect(ctx, CGRect(x: bx - 1.5, y: by - 1.5, width: bw + 3, height: bh + 3), r: 3,
                  fill: UIColor(white: 0, alpha: 0.65), stroke: nil)
        // Empty track
        roundRect(ctx, CGRect(x: bx, y: by, width: bw, height: bh), r: 2,
                  fill: UIColor(white: 0.15, alpha: 0.9), stroke: nil)
        // Fill — green → yellow → pink as HP drops
        let fillColor: UIColor
        if pct > 0.55 {
            fillColor = UIColor(red: 0.25, green: 0.92, blue: 0.45, alpha: 1)
        } else if pct > 0.28 {
            fillColor = UIColor(red: 1, green: 0.84, blue: 0.25, alpha: 1)
        } else {
            fillColor = UIColor(red: 1, green: 0.18, blue: 0.54, alpha: 1)
        }
        if pct > 0.001 {
            roundRect(ctx, CGRect(x: bx, y: by, width: bw * pct, height: bh), r: 2,
                      fill: fillColor, stroke: nil)
        }
    }

    private static func walkBob(_ f: Fighter) -> CGFloat {
        guard f.anim == .walk, f.kind == .player else { return 0 }
        let phase = f.animFrame % 8
        if phase == 1 || phase == 5 { return 3 }
        if phase == 0 || phase == 4 { return 1 }
        if phase == 3 || phase == 7 { return -2 }
        return 0
    }

    // MARK: - FX

    private static func drawParticles(ctx: CGContext, state: GameState, assets: GameAssets) {
        for p in state.particles {
            let alpha = max(0, p.life / p.maxLife)
            switch p.kind {
            case .impact:
                if let sheet = assets.impact {
                    let size: CGFloat = 48
                    sheet.draw(in: ctx, frame: p.frame,
                               dest: CGRect(x: p.x - state.cameraX - size/2, y: p.y - size/2, width: size, height: size),
                               flipX: false)
                }
            case .wave:
                let r = p.radius ?? 40
                ctx.saveGState()
                ctx.setAlpha(alpha * 0.85)
                ctx.setStrokeColor(color(from: p.colorHex ?? "#ff2d8a").cgColor)
                ctx.setLineWidth(4)
                ctx.addEllipse(in: CGRect(x: p.x - state.cameraX - r, y: p.y - r * 0.38, width: r * 2, height: r * 0.76))
                ctx.strokePath()
                ctx.restoreGState()
            case .note:
                ctx.saveGState()
                ctx.setAlpha(alpha)
                let str = (p.frame % 2 == 0 ? "♪" : "♫") as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 18),
                    .foregroundColor: color(from: p.colorHex ?? "#ff2d8a")
                ]
                str.draw(at: CGPoint(x: p.x - state.cameraX, y: p.y), withAttributes: attrs)
                ctx.restoreGState()
            case .smoke:
                let r = (p.radius ?? 6) * (0.6 + (1 - alpha) * 1.4)
                ctx.saveGState()
                ctx.setAlpha(alpha * 0.5)
                ctx.setFillColor(UIColor(white: 0.8, alpha: 0.9).cgColor)
                ctx.addEllipse(in: CGRect(x: p.x - state.cameraX - r, y: p.y - r * 0.75, width: r * 2, height: r * 1.5))
                ctx.fillPath()
                ctx.restoreGState()
            case .muzzle:
                let r = (p.radius ?? 12) * (0.5 + alpha)
                ctx.saveGState()
                ctx.setAlpha(alpha)
                ctx.setFillColor(UIColor(red: 1, green: 0.96, blue: 0.63, alpha: 1).cgColor)
                ctx.addEllipse(in: CGRect(x: p.x - state.cameraX - r, y: p.y - r, width: r * 2, height: r * 2))
                ctx.fillPath()
                ctx.setFillColor(UIColor(red: 1, green: 0.53, blue: 0, alpha: 1).cgColor)
                let r2 = r * 0.45
                ctx.addEllipse(in: CGRect(x: p.x - state.cameraX - r2, y: p.y - r2, width: r2 * 2, height: r2 * 2))
                ctx.fillPath()
                ctx.restoreGState()
            case .spark:
                ctx.setFillColor(UIColor(red: 1, green: 0.84, blue: 0.42, alpha: alpha).cgColor)
                ctx.fill(CGRect(x: p.x - state.cameraX - 2, y: p.y - 2, width: 4, height: 4))
            }
        }

        if state.riffPulseLife > 0, state.riffPulse > 0, state.player.attackKind == .special {
            let pl = state.player
            let a = min(1, state.riffPulseLife * 4) * 0.35
            ctx.saveGState()
            ctx.setAlpha(a)
            ctx.setStrokeColor(UIColor(red: 1, green: 0.18, blue: 0.54, alpha: 1).cgColor)
            ctx.setLineWidth(3)
            ctx.setLineDash(phase: 0, lengths: [8, 10])
            let r = state.riffPulse
            ctx.addEllipse(in: CGRect(x: pl.x - state.cameraX - r, y: pl.y - 8 - r * 0.42, width: r * 2, height: r * 0.84))
            ctx.strokePath()
            ctx.restoreGState()
        }
    }

    private static func drawFloats(ctx: CGContext, state: GameState) {
        for f in state.floats {
            let alpha = max(0, f.life / 0.7)
            let str = f.text as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: color(from: f.colorHex).withAlphaComponent(alpha)
            ]
            let size = str.size(withAttributes: attrs)
            str.draw(at: CGPoint(x: f.x - state.cameraX - size.width / 2, y: f.y), withAttributes: attrs)
        }
    }

    private static func drawSpeechBubble(ctx: CGContext, state: GameState, camX: CGFloat) {
        guard let b = state.speechBubble else { return }
        let p = state.player
        let t = 1 - b.life / b.maxLife
        var scale: CGFloat = 1
        var alpha: CGFloat = 1
        if t < 0.12 { scale = 0.4 + (t / 0.12) * 0.7 }
        else if t < 0.2 { scale = 1.1 - ((t - 0.12) / 0.08) * 0.1 }
        if b.life < 0.2 { alpha = max(0, b.life / 0.2) }

        let font = UIFont.boldSystemFont(ofSize: 13)
        let lines = wrap(b.text, maxChars: b.text.count > 28 ? 22 : 18)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(white: 0.1, alpha: 1)]
        var maxW: CGFloat = 40
        for line in lines {
            maxW = max(maxW, (line as NSString).size(withAttributes: attrs).width)
        }
        let padX: CGFloat = 12, padY: CGFloat = 8, lineH: CGFloat = 16
        let bw = maxW + padX * 2
        let bh = CGFloat(lines.count) * lineH + padY * 2
        let headY = p.y - p.bodyH * p.scale * 0.95 - p.z - 18
        let cx = p.x - camX
        let bx = cx - bw / 2
        let by = headY - bh - 18

        ctx.saveGState()
        ctx.setAlpha(alpha)
        ctx.translateBy(x: cx, y: by + bh)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -cx, y: -(by + bh))

        let rect = CGRect(x: bx, y: by, width: bw, height: bh)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        UIColor(red: 1, green: 0.97, blue: 0.99, alpha: 1).setFill()
        UIColor(white: 0.1, alpha: 1).setStroke()
        path.fill()
        path.lineWidth = 2.5
        path.stroke()

        // Tail
        let tailX = cx + (p.facing > 0 ? -6 : 6)
        let tailTop = by + bh - 1
        let tail = UIBezierPath()
        tail.move(to: CGPoint(x: tailX - 8, y: tailTop))
        tail.addLine(to: CGPoint(x: tailX + 8, y: tailTop))
        tail.addLine(to: CGPoint(x: tailX + (p.facing > 0 ? 4 : -4), y: tailTop + 14))
        tail.close()
        UIColor(red: 1, green: 0.97, blue: 0.99, alpha: 1).setFill()
        tail.fill()

        for (i, line) in lines.enumerated() {
            let s = line as NSString
            let sz = s.size(withAttributes: attrs)
            s.draw(at: CGPoint(x: cx - sz.width / 2, y: by + padY + lineH * CGFloat(i)), withAttributes: attrs)
        }
        ctx.restoreGState()
    }

    private static func wrap(_ text: String, maxChars: Int) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        var lines: [String] = []
        var cur = ""
        for w in words {
            let next = cur.isEmpty ? w : cur + " " + w
            if next.count > maxChars && !cur.isEmpty {
                lines.append(cur)
                cur = w
            } else {
                cur = next
            }
        }
        if !cur.isEmpty { lines.append(cur) }
        return lines.isEmpty ? [text] : lines
    }

    // MARK: - HUD

    private static func drawHud(ctx: CGContext, state: GameState) {
        let p = state.player
        let hpPct = max(0, min(1, p.hp / max(1, p.maxHp)))

        // Player health panel
        roundRect(ctx, CGRect(x: 16, y: 12, width: 280, height: 72), r: 12,
                  fill: UIColor(red: 0.04, green: 0.02, blue: 0.07, alpha: 0.78),
                  stroke: UIColor(red: 1, green: 0.18, blue: 0.54, alpha: 0.5))

        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 15),
            .foregroundColor: UIColor(red: 0.96, green: 0.93, blue: 0.97, alpha: 1)
        ]
        ("JJ" as NSString).draw(at: CGPoint(x: 28, y: 18), withAttributes: nameAttrs)

        let hpLabelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor(red: 0.66, green: 0.61, blue: 0.72, alpha: 1)
        ]
        ("HEALTH" as NSString).draw(at: CGPoint(x: 56, y: 20), withAttributes: hpLabelAttrs)

        let hpNum = "\(max(0, Int(p.hp.rounded())))/\(Int(p.maxHp.rounded()))" as NSString
        let hpNumAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor(red: 0.96, green: 0.93, blue: 0.97, alpha: 1)
        ]
        let hpNumSize = hpNum.size(withAttributes: hpNumAttrs)
        hpNum.draw(at: CGPoint(x: 280 - 12 - hpNumSize.width, y: 19), withAttributes: hpNumAttrs)

        // Health bar track + fill
        let barX: CGFloat = 28
        let barY: CGFloat = 42
        let barW: CGFloat = 248
        let barH: CGFloat = 18
        roundRect(ctx, CGRect(x: barX, y: barY, width: barW, height: barH), r: 8,
                  fill: UIColor(white: 0, alpha: 0.5), stroke: nil)
        if hpPct > 0.001 {
            let hpColor: UIColor
            if hpPct > 0.5 {
                hpColor = UIColor(red: 1, green: 0.18, blue: 0.54, alpha: 1)
            } else if hpPct > 0.25 {
                hpColor = UIColor(red: 1, green: 0.55, blue: 0.2, alpha: 1)
            } else {
                hpColor = UIColor(red: 0.95, green: 0.2, blue: 0.25, alpha: 1)
            }
            roundRect(ctx, CGRect(x: barX, y: barY, width: barW * hpPct, height: barH), r: 8,
                      fill: hpColor, stroke: nil)
            // Gloss highlight
            roundRect(ctx, CGRect(x: barX + 3, y: barY + 2, width: max(0, barW * hpPct - 6), height: 5), r: 3,
                      fill: UIColor(white: 1, alpha: 0.18), stroke: nil)
        }
        // Segment ticks (classic beat-em-up feel)
        ctx.saveGState()
        ctx.setStrokeColor(UIColor(white: 0, alpha: 0.35).cgColor)
        ctx.setLineWidth(1)
        for i in 1..<4 {
            let tx = barX + barW * CGFloat(i) / 4
            ctx.move(to: CGPoint(x: tx, y: barY + 2))
            ctx.addLine(to: CGPoint(x: tx, y: barY + barH - 2))
        }
        ctx.strokePath()
        ctx.restoreGState()

        // Special / riff meter
        roundRect(ctx, CGRect(x: 16, y: 92, width: 220, height: 28), r: 10,
                  fill: UIColor(red: 0.04, green: 0.02, blue: 0.07, alpha: 0.75), stroke: nil)
        roundRect(ctx, CGRect(x: 24, y: 100, width: 204, height: 12), r: 6,
                  fill: UIColor(white: 0, alpha: 0.45), stroke: nil)
        let sp = state.specialMeter / 100
        let spColor = sp >= 0.4
            ? UIColor(red: 0.18, green: 0.89, blue: 0.9, alpha: 1)
            : UIColor(red: 0.18, green: 0.89, blue: 0.9, alpha: 0.45)
        if sp > 0.001 {
            roundRect(ctx, CGRect(x: 24, y: 100, width: 204 * sp, height: 12), r: 6, fill: spColor, stroke: nil)
        }
        let spAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor(red: 0.66, green: 0.61, blue: 0.72, alpha: 1)
        ]
        ("RIFF SPECIAL" as NSString).draw(at: CGPoint(x: 28, y: 124), withAttributes: spAttrs)

        var nextY: CGFloat = 142
        if state.hasGun {
            roundRect(ctx, CGRect(x: 16, y: nextY, width: 150, height: 22), r: 8,
                      fill: UIColor(red: 0.04, green: 0.02, blue: 0.07, alpha: 0.78),
                      stroke: UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 0.55))
            let gunAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11),
                .foregroundColor: UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1)
            ]
            ("GUN READY  (F)" as NSString).draw(at: CGPoint(x: 28, y: nextY + 4), withAttributes: gunAttrs)
            nextY += 28
        }

        // Score / wave — sit below SwiftUI SOUND/PAUSE chips (top-right overlay ~48pt tall).
        let scoreStr = "\(state.score)" as NSString
        let scoreAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor(red: 0.96, green: 0.93, blue: 0.97, alpha: 1)
        ]
        let scoreSize = scoreStr.size(withAttributes: scoreAttrs)
        scoreStr.draw(at: CGPoint(x: viewW - 20 - scoreSize.width, y: 56), withAttributes: scoreAttrs)

        let waveStr = "WAVE \(state.wave)/\(state.maxWaves)" as NSString
        let waveAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(red: 0.66, green: 0.61, blue: 0.72, alpha: 1)
        ]
        let waveSize = waveStr.size(withAttributes: waveAttrs)
        waveStr.draw(at: CGPoint(x: viewW - 20 - waveSize.width, y: 80), withAttributes: waveAttrs)

        if p.combo > 1 {
            let c = "\(p.combo) HIT COMBO" as NSString
            let ca: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor(red: 1, green: 0.84, blue: 0.42, alpha: 1)
            ]
            c.draw(at: CGPoint(x: 16, y: nextY + 4), withAttributes: ca)
        }

        if state.messageTimer > 0, !state.message.isEmpty {
            let m = state.message as NSString
            let ma: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 36),
                .foregroundColor: UIColor(red: 1, green: 0.18, blue: 0.54, alpha: min(1, state.messageTimer))
            ]
            let sz = m.size(withAttributes: ma)
            m.draw(at: CGPoint(x: (viewW - sz.width) / 2, y: viewH * 0.22), withAttributes: ma)
        }
    }

    private static func roundRect(_ ctx: CGContext, _ rect: CGRect, r: CGFloat, fill: UIColor, stroke: UIColor?) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: r)
        fill.setFill()
        path.fill()
        if let stroke {
            stroke.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
    }

    private static func color(from hex: String) -> UIColor {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else {
            return UIColor.white
        }
        return UIColor(
            red: CGFloat((v >> 16) & 0xff) / 255,
            green: CGFloat((v >> 8) & 0xff) / 255,
            blue: CGFloat(v & 0xff) / 255,
            alpha: 1
        )
    }

    // MARK: - Overlays

    static func drawTitle(ctx: CGContext, assets: GameAssets, now: CFTimeInterval) {
        // Prefer full-bleed title art when present (imported title_screen asset).
        if let art = assets.titleScreen {
            drawAspectFill(ctx: ctx, image: art, in: CGRect(x: 0, y: 0, width: viewW, height: viewH))
            // Soft bottom vignette so TAP TO START stays readable.
            let gradH: CGFloat = 120
            let colors = [
                UIColor(red: 0.02, green: 0.01, blue: 0.04, alpha: 0).cgColor,
                UIColor(red: 0.02, green: 0.01, blue: 0.04, alpha: 0.78).cgColor
            ] as CFArray
            if let space = CGColorSpace(name: CGColorSpace.sRGB),
               let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                ctx.drawLinearGradient(
                    grad,
                    start: CGPoint(x: viewW / 2, y: viewH - gradH),
                    end: CGPoint(x: viewW / 2, y: viewH),
                    options: []
                )
            }
            drawTapToStart(ctx: ctx, now: now, y: viewH - 52)
            return
        }

        // Fallback procedural title (no title_screen asset).
        ctx.setFillColor(UIColor(red: 0.03, green: 0.02, blue: 0.06, alpha: 0.62).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: viewW, height: viewH))

        roundRect(ctx, CGRect(x: 36, y: 72, width: 520, height: 200), r: 16,
                  fill: UIColor(red: 0.04, green: 0.02, blue: 0.07, alpha: 0.78),
                  stroke: UIColor(red: 1, green: 0.18, blue: 0.54, alpha: 0.4))

        let title = "JJ: NIGHT BRAWL" as NSString
        title.draw(at: CGPoint(x: 56, y: 90), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: 42),
            .foregroundColor: UIColor(red: 1, green: 0.18, blue: 0.54, alpha: 1)
        ])
        ("32-bit side-scrolling beat-em-up" as NSString).draw(at: CGPoint(x: 60, y: 150), withAttributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor(red: 0.96, green: 0.93, blue: 0.97, alpha: 1)
        ])
        ("Clear five waves. Chain combos. Full meter = guitar riff!" as NSString).draw(at: CGPoint(x: 60, y: 180), withAttributes: [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor(red: 0.66, green: 0.61, blue: 0.72, alpha: 1)
        ])

        if let por = assets.jjPortrait {
            let ps: CGFloat = 96
            let px = viewW - 48 - ps
            let py: CGFloat = 48
            ctx.saveGState()
            ctx.setFillColor(UIColor(red: 0.04, green: 0.02, blue: 0.07, alpha: 0.85).cgColor)
            ctx.addEllipse(in: CGRect(x: px - 4, y: py - 4, width: ps + 8, height: ps + 8))
            ctx.fillPath()
            ctx.setStrokeColor(UIColor(red: 1, green: 0.18, blue: 0.54, alpha: 1).cgColor)
            ctx.setLineWidth(3)
            ctx.strokeEllipse(in: CGRect(x: px - 4, y: py - 4, width: ps + 8, height: ps + 8))
            ctx.addEllipse(in: CGRect(x: px, y: py, width: ps, height: ps))
            ctx.clip()
            por.draw(in: CGRect(x: px, y: py, width: ps, height: ps))
            ctx.restoreGState()
        }

        if let idle = assets.jjIdle {
            let drawH: CGFloat = 220
            let drawW = drawH * (idle.frameW / max(1, idle.frameH))
            let frame = Int(now / 0.45) % max(1, idle.frameCount)
            idle.draw(in: ctx, frame: frame,
                      dest: CGRect(x: viewW - 170 - drawW / 2, y: viewH - 64 - drawH, width: drawW, height: drawH),
                      flipX: false)
        }
        drawTapToStart(ctx: ctx, now: now, y: viewH - 52)
    }

    /// Aspect-fill image into `rect` (centered crop).
    private static func drawAspectFill(ctx: CGContext, image: UIImage, in rect: CGRect) {
        let iw = max(1, image.size.width)
        let ih = max(1, image.size.height)
        let scale = max(rect.width / iw, rect.height / ih)
        let dw = iw * scale
        let dh = ih * scale
        let dest = CGRect(
            x: rect.midX - dw / 2,
            y: rect.midY - dh / 2,
            width: dw,
            height: dh
        )
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.interpolationQuality = .none
        image.draw(in: dest)
        ctx.restoreGState()
    }

    private static func drawTapToStart(ctx: CGContext, now: CFTimeInterval, y: CGFloat) {
        let pulse = 0.72 + 0.28 * sin(now * 3.2)
        let label = "TAP TO START" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 22),
            .foregroundColor: UIColor(red: 1, green: 0.18, blue: 0.54, alpha: pulse)
        ]
        let sz = label.size(withAttributes: attrs)
        // Subtle pill behind the prompt
        let padX: CGFloat = 22
        let padY: CGFloat = 10
        let pill = CGRect(
            x: (viewW - sz.width) / 2 - padX,
            y: y - padY,
            width: sz.width + padX * 2,
            height: sz.height + padY * 2
        )
        roundRect(ctx, pill, r: 18,
                  fill: UIColor(red: 0.04, green: 0.02, blue: 0.07, alpha: 0.72),
                  stroke: UIColor(red: 1, green: 0.18, blue: 0.54, alpha: 0.55 * pulse))
        label.draw(at: CGPoint(x: (viewW - sz.width) / 2, y: y), withAttributes: attrs)
    }

    static func drawBanner(ctx: CGContext, title: String, subtitle: String) {
        ctx.setFillColor(UIColor(red: 0.03, green: 0.02, blue: 0.06, alpha: 0.62).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: viewW, height: viewH))
        let t = title as NSString
        let ta: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 42),
            .foregroundColor: UIColor(red: 1, green: 0.18, blue: 0.54, alpha: 1)
        ]
        let tsz = t.size(withAttributes: ta)
        t.draw(at: CGPoint(x: (viewW - tsz.width) / 2, y: viewH / 2 - 30), withAttributes: ta)
        let s = subtitle as NSString
        let sa: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor(red: 0.96, green: 0.93, blue: 0.97, alpha: 1)
        ]
        let ssz = s.size(withAttributes: sa)
        s.draw(at: CGPoint(x: (viewW - ssz.width) / 2, y: viewH / 2 + 20), withAttributes: sa)
    }
}
