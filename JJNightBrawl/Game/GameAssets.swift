import UIKit
import CoreGraphics

/// Sprite atlas with **cached** frame images so we never re-crop / re-allocate every draw.
/// Uncached UIImage creation every CADisplayLink tick is a common freeze cause on ProMotion devices.
final class SpriteSheet {
    let image: UIImage
    let cols: Int
    let rows: Int
    var frameW: CGFloat { image.size.width / CGFloat(cols) }
    var frameH: CGFloat { image.size.height / CGFloat(rows) }
    var frameCount: Int { cols * rows }

    private var frameCache: [Int: UIImage] = [:]
    private let cacheLock = NSLock()

    init(image: UIImage, cols: Int, rows: Int) {
        self.image = image
        self.cols = max(1, cols)
        self.rows = max(1, rows)
        // Warm the cache so the first on-screen frame is free of crop work.
        prefetchAllFrames()
    }

    /// 1×1 transparent placeholder so callers never force-unwrap a missing sheet.
    static let empty: SpriteSheet = {
        let w = 1, h = 1, bpp = 4, bpr = 4
        var pixels: [UInt8] = [0, 0, 0, 0]
        let cs = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        let img: UIImage
        if let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8,
                               bytesPerRow: bpr, space: cs, bitmapInfo: info),
           let cg = ctx.makeImage() {
            img = UIImage(cgImage: cg, scale: 1, orientation: .up)
        } else {
            img = UIImage()
        }
        return SpriteSheet(image: img, cols: 1, rows: 1)
    }()

    private func prefetchAllFrames() {
        guard let cg = image.cgImage else { return }
        let scale = image.scale
        let total = frameCount
        for f in 0..<total {
            if let img = makeFrameImage(f, cg: cg, scale: scale) {
                frameCache[f] = img
            }
        }
    }

    private func makeFrameImage(_ frame: Int, cg: CGImage, scale: CGFloat) -> UIImage? {
        let total = max(1, frameCount)
        let f = ((frame % total) + total) % total
        let col = f % cols
        let row = f / cols
        let crop = CGRect(
            x: CGFloat(col) * frameW * scale,
            y: CGFloat(row) * frameH * scale,
            width: frameW * scale,
            height: frameH * scale
        ).integral
        guard crop.width > 0, crop.height > 0,
              let piece = cg.cropping(to: crop) else { return nil }
        return UIImage(cgImage: piece, scale: scale, orientation: .up)
    }

    private func frameImage(_ frame: Int) -> UIImage? {
        let total = max(1, frameCount)
        let f = ((frame % total) + total) % total
        cacheLock.lock()
        if let cached = frameCache[f] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        guard let cg = image.cgImage else { return nil }
        guard let img = makeFrameImage(f, cg: cg, scale: image.scale) else { return nil }
        cacheLock.lock()
        frameCache[f] = img
        cacheLock.unlock()
        return img
    }

    func draw(in ctx: CGContext, frame: Int, dest: CGRect, flipX: Bool) {
        guard dest.width > 0.5, dest.height > 0.5 else { return }
        guard let piece = frameImage(frame) else { return }
        ctx.saveGState()
        // Crisp pixel art (avoid blurry bilinear upscale on large logical sizes)
        ctx.interpolationQuality = .none
        if flipX {
            ctx.translateBy(x: dest.midX, y: dest.midY)
            ctx.scaleBy(x: -1, y: 1)
            ctx.translateBy(x: -dest.midX, y: -dest.midY)
        }
        UIGraphicsPushContext(ctx)
        piece.draw(in: dest)
        UIGraphicsPopContext()
        ctx.restoreGState()
    }
}

final class GameAssets {
    private(set) var jjIdle: SpriteSheet?
    private(set) var jjWalk: SpriteSheet?
    private(set) var jjAttack: SpriteSheet?
    private(set) var jjKick: SpriteSheet?
    private(set) var jjHurt: SpriteSheet?
    private(set) var jjJump: SpriteSheet?
    private(set) var jjSpecial: SpriteSheet?
    private(set) var jjSmoke: SpriteSheet?
    private(set) var jjVictory: SpriteSheet?
    private(set) var jjPortrait: UIImage?
    /// Full-bleed title art (optional). When present, replaces the procedural title card.
    private(set) var titleScreen: UIImage?

    private var enemySheets: [String: SpriteSheet] = [:]
    private(set) var sky: UIImage?
    private(set) var farBg: UIImage?
    private(set) var midBg: UIImage?
    private(set) var impact: SpriteSheet?
    /// Only flipped to true on the main thread after a full load finishes.
    private(set) var ready = false

    /// Build sprite sheets. Prefer `stripChroma: false` for first paint — production assets
    /// are already transparent; chroma is expensive and blocked the main thread on device.
    func load(stripChroma: Bool = false) {
        let t0 = CFAbsoluteTimeGetCurrent()
        let idle = must("jj_idle", 2, 2, stripChroma: stripChroma)
        let walk = must("jj_walk", 4, 2, stripChroma: stripChroma)
        let attack = must("jj_attack", 2, 2, stripChroma: stripChroma)
        let kick = must("jj_kick", 2, 2, stripChroma: stripChroma)
        let hurt = must("jj_hurt", 2, 2, stripChroma: stripChroma)
        let jump = must("jj_jump", 2, 2, stripChroma: stripChroma)
        let special = must("jj_special", 2, 2, stripChroma: stripChroma)
        let smoke = must("jj_smoke", 2, 2, stripChroma: stripChroma)
        let victory = must("jj_victory", 2, 2, stripChroma: stripChroma)
        let portrait = UIImage(named: "jj_portrait")

        var enemies: [String: SpriteSheet] = [:]
        for t in ["biz", "maga", "gothm", "gothf"] {
            for a in ["idle", "walk", "attack"] {
                if let s = opt("en_\(t)_\(a)", 2, 2, stripChroma: stripChroma) {
                    enemies["\(t)_\(a)"] = s
                }
            }
        }
        let impactSheet = opt("fx_impact", 2, 2, stripChroma: stripChroma)
        let skyImg = UIImage(named: "map_sky")
        let farImg = UIImage(named: "map_far")
        let midImg = UIImage(named: "map_mid")
        let titleImg = UIImage(named: "title_screen")
        let isReady = idle != nil && walk != nil
        print("[JJ] assets load stripChroma=\(stripChroma) ready=\(isReady) idle=\(idle != nil) walk=\(walk != nil) title=\(titleImg != nil) enemies=\(enemies.count) dt=\(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - t0))s")

        let publish = { [weak self] in
            guard let self else { return }
            self.jjIdle = idle
            self.jjWalk = walk
            self.jjAttack = attack
            self.jjKick = kick
            self.jjHurt = hurt
            self.jjJump = jump
            self.jjSpecial = special
            self.jjSmoke = smoke
            self.jjVictory = victory
            self.jjPortrait = portrait
            self.titleScreen = titleImg
            self.enemySheets = enemies
            self.impact = impactSheet
            self.sky = skyImg
            self.farBg = farImg
            self.midBg = midImg
            self.ready = isReady
        }

        // Never main.sync from background — that deadlocks / freezes device launch.
        if Thread.isMainThread {
            publish()
        } else {
            DispatchQueue.main.async(execute: publish)
        }
    }

    /// Fast background load (no chroma) so the title paints quickly on device, then
    /// optional chroma polish on a background queue without blocking UI.
    func loadAsync(onDone: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else {
                DispatchQueue.main.async(execute: onDone)
                return
            }
            // Pass 1: Load with chroma stripping enabled - the pink boxes indicate we need this
            // Pre-keyed assets won't be affected, but raw exports will be cleaned
            self.load(stripChroma: true)
            DispatchQueue.main.async {
                onDone()
            }
        }
    }

    private var fallbackSheet: SpriteSheet {
        jjIdle ?? jjWalk ?? .empty
    }

    func sheetForPlayer(anim: AnimName, attackKind: AttackKind?) -> SpriteSheet {
        let fb = fallbackSheet
        switch anim {
        case .attack:
            if attackKind == .special { return jjSpecial ?? jjAttack ?? fb }
            if attackKind == .kick { return jjKick ?? jjAttack ?? fb }
            // Gun reuses punch pose + drawn pistol overlay
            return jjAttack ?? fb
        case .hurt, .dead: return jjHurt ?? fb
        case .jump: return jjJump ?? fb
        case .smoke: return jjSmoke ?? fb
        case .victory: return jjVictory ?? fb
        case .walk: return jjWalk ?? fb
        case .idle: return jjIdle ?? fb
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
        return enemySheets[key] ?? enemySheets["\(t)_idle"] ?? fallbackSheet
    }

    private func must(_ name: String, _ c: Int, _ r: Int, stripChroma: Bool = false) -> SpriteSheet? {
        guard var img = UIImage(named: name) else {
            print("[JJ] missing \(name) in Assets.xcassets")
            return nil
        }
        if stripChroma {
            img = Self.stripChromaKey(from: img, cols: c, rows: r)
        }
        return SpriteSheet(image: img, cols: c, rows: r)
    }

    private func opt(_ name: String, _ c: Int, _ r: Int, stripChroma: Bool = false) -> SpriteSheet? {
        guard var img = UIImage(named: name) else { return nil }
        if stripChroma {
            img = Self.stripChromaKey(from: img, cols: c, rows: r)
        }
        return SpriteSheet(image: img, cols: c, rows: r)
    }

    // MARK: - Chroma key cleanup

    /// Removes solid pink/magenta frame backgrounds left from sprite generation.
    /// Samples each cell's border for chroma fill colors, then keys matching pixels to alpha 0.
    /// Costume pink that does not fill the frame border is preserved.
    private static func stripChromaKey(from image: UIImage, cols: Int, rows: Int) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let w = cg.width
        let h = cg.height
        // Skip heavy work on already-small transparent sheets (typical production size)
        if w * h > 512 * 512 {
            // Downscale first if a raw sheet was dropped into the asset catalog by mistake
            // — still process, but this path is the freeze risk; log it.
            print("[JJ] chroma-key on large sheet \(w)x\(h) — prefer pre-keyed 256×256 assets")
        }
        let bpp = 4
        let bpr = bpp * w
        var data = [UInt8](repeating: 0, count: h * bpr)
        let cs = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: &data,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bpr,
            space: cs,
            bitmapInfo: bitmapInfo
        ) else { return image }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        let cellW = max(1, w / max(1, cols))
        let cellH = max(1, h / max(1, rows))

        for row in 0..<rows {
            for col in 0..<cols {
                let ox = col * cellW
                let oy = row * cellH
                let cw = min(cellW, w - ox)
                let ch = min(cellH, h - oy)
                guard cw > 6, ch > 6 else { continue }

                // Sample a ring just inside the cell (past black gutters) for solid BG fills.
                var samples: [(Int, Int, Int)] = []
                let inset = max(2, min(cw, ch) / 10)
                let yTop = oy + inset
                let yBot = oy + ch - 1 - inset
                let xLeft = ox + inset
                let xRight = ox + cw - 1 - inset
                let stepX = max(1, cw / 8)
                let stepY = max(1, ch / 8)
                for x in stride(from: xLeft, through: xRight, by: stepX) {
                    appendSample(x, yTop, bpr: bpr, bpp: bpp, data: data, into: &samples)
                    appendSample(x, yBot, bpr: bpr, bpp: bpp, data: data, into: &samples)
                }
                for y in stride(from: yTop, through: yBot, by: stepY) {
                    appendSample(xLeft, y, bpr: bpr, bpp: bpp, data: data, into: &samples)
                    appendSample(xRight, y, bpr: bpr, bpp: bpp, data: data, into: &samples)
                }

                let chromaSamples = samples.filter { isChromaCandidate(r: $0.0, g: $0.1, b: $0.2) }
                // Need a meaningful border fill before keying (avoids eating costume pink).
                guard chromaSamples.count >= max(3, samples.count / 5) else {
                    // Still remove pure classic magenta (#FF00FF-ish) if present.
                    keyPureMagenta(ox: ox, oy: oy, cw: cw, ch: ch, bpr: bpr, bpp: bpp, data: &data)
                    continue
                }

                // Average sampled chroma as the key color for this cell.
                let n = chromaSamples.count
                let avgR = chromaSamples.reduce(0) { $0 + $1.0 } / n
                let avgG = chromaSamples.reduce(0) { $0 + $1.1 } / n
                let avgB = chromaSamples.reduce(0) { $0 + $1.2 } / n
                let keys: [(Int, Int, Int)] = chromaSamples + [(avgR, avgG, avgB), (255, 0, 255)]

                for y in oy..<(oy + ch) {
                    for x in ox..<(ox + cw) {
                        let i = y * bpr + x * bpp
                        let r = Int(data[i]), g = Int(data[i + 1]), b = Int(data[i + 2]), a = Int(data[i + 3])
                        if a < 8 { continue }
                        if matchesAnyChroma(r: r, g: g, b: b, keys: keys) {
                            data[i] = 0
                            data[i + 1] = 0
                            data[i + 2] = 0
                            data[i + 3] = 0
                        }
                    }
                }
            }
        }

        guard let out = ctx.makeImage() else { return image }
        return UIImage(cgImage: out, scale: image.scale, orientation: image.imageOrientation)
    }

    private static func appendSample(
        _ x: Int, _ y: Int,
        bpr: Int, bpp: Int,
        data: [UInt8],
        into samples: inout [(Int, Int, Int)]
    ) {
        let i = y * bpr + x * bpp
        let r = Int(data[i]), g = Int(data[i + 1]), b = Int(data[i + 2]), a = Int(data[i + 3])
        if a >= 16 {
            samples.append((r, g, b))
        }
    }

    private static func keyPureMagenta(ox: Int, oy: Int, cw: Int, ch: Int, bpr: Int, bpp: Int, data: inout [UInt8]) {
        for y in oy..<(oy + ch) {
            for x in ox..<(ox + cw) {
                let i = y * bpr + x * bpp
                let r = Int(data[i]), g = Int(data[i + 1]), b = Int(data[i + 2]), a = Int(data[i + 3])
                if a >= 8 && r > 200 && b > 200 && g < 90 {
                    data[i] = 0; data[i + 1] = 0; data[i + 2] = 0; data[i + 3] = 0
                }
            }
        }
    }

    private static func isChromaCandidate(r: Int, g: Int, b: Int) -> Bool {
        // Classic magenta / purple chroma
        if r > 170 && b > 170 && g < 120 { return true }
        // Hot pink / brand pink solid fills (high R, mid B, low G)
        if r > 200 && g < 120 && b > 70 && b < 220 && (r - g) > 90 { return true }
        // Mauve fill used on biz walk cells
        if r > 160 && b > 140 && g < 130 && abs(r - b) < 90 && (r + b) > 2 * g + 40 { return true }
        return false
    }

    private static func matchesAnyChroma(r: Int, g: Int, b: Int, keys: [(Int, Int, Int)]) -> Bool {
        if r > 200 && b > 200 && g < 90 { return true }
        guard isChromaCandidate(r: r, g: g, b: b) else { return false }
        for (kr, kg, kb) in keys {
            if abs(r - kr) <= 52 && abs(g - kg) <= 52 && abs(b - kb) <= 52 {
                return true
            }
        }
        return false
    }
}
