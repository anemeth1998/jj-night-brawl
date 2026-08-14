import UIKit

/// Core Graphics renderer for the beat-em-up stage.
/// Uses cached sprite frames from GameAssets (no force-unwrap on missing art).
final class GameRenderer {
    func draw(context ctx: CGContext, rect: CGRect, state: GameState, assets: GameAssets) {
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(rect)

        let w = rect.width
        let h = rect.height
        let groundY = h * 0.72
        let shakeX = (state.shake > 0 ? CGFloat.random(in: -3...3) * state.shake * 10 : 0)
        let shakeY = (state.shake > 0 ? CGFloat.random(in: -2...2) * state.shake * 10 : 0)

        ctx.saveGState()
        ctx.translateBy(x: shakeX, y: shakeY)

        drawParallax(ctx: ctx, rect: rect, cameraX: state.cameraX, assets: assets, groundY: groundY)

        // Sort fighters by lane depth (y) for painter's order.
        var fighters: [Fighter] = state.enemies
        fighters.append(state.player)
        fighters.sort { $0.y < $1.y }

        for f in fighters {
            drawFighter(ctx: ctx, f: f, cameraX: state.cameraX, groundY: groundY, assets: assets, viewW: w)
        }

        for b in state.bullets {
            let sx = b.x - state.cameraX
            let sy = groundY - b.y * 0.35 - b.z
            ctx.setFillColor(UIColor.yellow.cgColor)
            ctx.fillEllipse(in: CGRect(x: sx - 4, y: sy - 3, width: 10, height: 6))
        }

        for p in state.particles {
            let alpha = max(0, p.life / max(p.maxLife, 0.01))
            ctx.setFillColor(UIColor.orange.withAlphaComponent(alpha).cgColor)
            let sx = p.x - state.cameraX
            ctx.fillEllipse(in: CGRect(x: sx - 8, y: groundY + p.y - 8, width: 16, height: 16))
        }

        ctx.restoreGState()

        if let bubble = state.speechBubble {
            drawBubble(ctx: ctx, text: bubble.text, rect: rect, life: bubble.life / bubble.maxLife)
        }

        if state.messageTimer > 0, !state.message.isEmpty {
            drawCenteredText(ctx: ctx, text: state.message, rect: rect, size: 28)
        }

        if state.phase == .title {
            // Title art — never force-unwrap jjIdle.
            if let idle = assets.jjIdle {
                let frame = assets.frame(sheet: idle, index: Int(state.elapsed * 4) % 4, key: "title-jj") ?? idle
                let iw: CGFloat = 160
                let ih: CGFloat = 160
                frame.draw(in: CGRect(x: (w - iw) / 2, y: h * 0.28, width: iw, height: ih))
            }
        }
    }

    private func drawParallax(ctx: CGContext, rect: CGRect, cameraX: CGFloat, assets: GameAssets, groundY: CGFloat) {
        let w = rect.width
        let h = rect.height
        if let sky = assets.mapSky {
            sky.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
        } else {
            let colors = [UIColor(red: 0.08, green: 0.05, blue: 0.18, alpha: 1).cgColor,
                          UIColor(red: 0.35, green: 0.12, blue: 0.2, alpha: 1).cgColor]
            let space = CGColorSpaceCreateDeviceRGB()
            if let g = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 1]) {
                ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: h), options: [])
            }
        }
        if let far = assets.mapFar {
            let ox = -fmod(cameraX * 0.25, w)
            far.draw(in: CGRect(x: ox, y: 0, width: w, height: h))
            far.draw(in: CGRect(x: ox + w, y: 0, width: w, height: h))
        }
        if let mid = assets.mapMid {
            let ox = -fmod(cameraX * 0.5, w)
            mid.draw(in: CGRect(x: ox, y: 0, width: w, height: h))
            mid.draw(in: CGRect(x: ox + w, y: 0, width: w, height: h))
        }

        // Street slab
        ctx.setFillColor(UIColor(white: 0.12, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: groundY - 20, width: w, height: h - groundY + 20))
        ctx.setStrokeColor(UIColor(white: 0.25, alpha: 1).cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: 0, y: groundY - 20))
        ctx.addLine(to: CGPoint(x: w, y: groundY - 20))
        ctx.strokePath()
    }

    private func drawFighter(ctx: CGContext, f: Fighter, cameraX: CGFloat, groundY: CGFloat, assets: GameAssets, viewW: CGFloat) {
        let sx = f.x - cameraX
        let sy = groundY - f.y * 0.35 - f.z
        guard sx > -80 && sx < viewW + 80 else { return }

        let sheet: UIImage?
        let key: String
        if f.kind == .player {
            switch f.anim {
            case .walk: sheet = assets.jjWalk; key = "jj-walk"
            case .attack: sheet = assets.jjAttack; key = "jj-atk"
            case .hurt, .dead: sheet = assets.jjHurt; key = "jj-hurt"
            default: sheet = assets.jjIdle; key = "jj-idle"
            }
        } else {
            switch f.anim {
            case .walk: sheet = assets.enemyWalk; key = "en-walk"
            case .attack: sheet = assets.enemyAttack; key = "en-atk"
            default: sheet = assets.enemyIdle; key = "en-idle"
            }
        }

        let frameImg = assets.frame(sheet: sheet, index: f.animFrame, key: key)
        let fw: CGFloat = 96 * f.scale
        let fh: CGFloat = 96 * f.scale
        let dest = CGRect(x: sx - fw / 2, y: sy - fh, width: fw, height: fh)

        ctx.saveGState()
        if f.facing < 0 {
            ctx.translateBy(x: dest.midX, y: 0)
            ctx.scaleBy(x: -1, y: 1)
            ctx.translateBy(x: -dest.midX, y: 0)
        }
        if let frameImg {
            if f.flash > 0 {
                frameImg.draw(in: dest, blendMode: .normal, alpha: 1)
                ctx.setFillColor(UIColor.white.withAlphaComponent(0.45).cgColor)
                ctx.fill(dest)
            } else {
                frameImg.draw(in: dest)
            }
        } else {
            let color: UIColor = f.kind == .player
                ? UIColor(red: 0.9, green: 0.25, blue: 0.45, alpha: 1)
                : UIColor(red: 0.35, green: 0.4, blue: 0.65, alpha: 1)
            color.setFill()
            UIBezierPath(roundedRect: dest.insetBy(dx: 18, dy: 8), cornerRadius: 6).fill()
        }
        ctx.restoreGState()

        // Shadow
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.35).cgColor)
        let shadow = CGRect(x: sx - 22, y: groundY - f.y * 0.35 - 6, width: 44, height: 12)
        ctx.fillEllipse(in: shadow)
    }

    private func drawBubble(ctx: CGContext, text: String, rect: CGRect, life: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        let ns = text as NSString
        let size = ns.size(withAttributes: attrs)
        let box = CGRect(
            x: (rect.width - size.width) / 2 - 14,
            y: rect.height * 0.18,
            width: size.width + 28,
            height: size.height + 16
        )
        UIColor.white.withAlphaComponent(0.85 * life).setFill()
        UIBezierPath(roundedRect: box, cornerRadius: 8).fill()
        ns.draw(at: CGPoint(x: box.minX + 14, y: box.minY + 8), withAttributes: attrs)
    }

    private func drawCenteredText(ctx: CGContext, text: String, rect: CGRect, size: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: .black),
            .foregroundColor: UIColor.white
        ]
        let ns = text as NSString
        let s = ns.size(withAttributes: attrs)
        ns.draw(at: CGPoint(x: (rect.width - s.width) / 2, y: rect.height * 0.4), withAttributes: attrs)
    }
}
