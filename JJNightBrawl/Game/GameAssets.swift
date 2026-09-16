import UIKit
import CoreGraphics
import AVFoundation
import ImageIO

/// Sprite atlas with **cached** frame images so we never re-crop / re-allocate every draw.
/// Uncached UIImage creation every CADisplayLink tick is a common freeze cause on ProMotion devices.
final class SpriteSheet: @unchecked Sendable {
    let image: UIImage
    let cols: Int
    let rows: Int
    var frameW: CGFloat { directFrames?.first?.size.width ?? image.size.width / CGFloat(cols) }
    var frameH: CGFloat { directFrames?.first?.size.height ?? image.size.height / CGFloat(rows) }
    var frameCount: Int { directFrames?.count ?? cols * rows }

    private let directFrames: [UIImage]?
    private var frameCache: [Int: UIImage] = [:]
    /// White silhouettes (sprite alpha only) for the hit flash — built lazily on first hit.
    private var flashCache: [Int: UIImage] = [:]
    private let cacheLock = NSLock()

    init(image: UIImage, cols: Int, rows: Int) {
        self.image = image
        self.cols = max(1, cols)
        self.rows = max(1, rows)
        self.directFrames = nil
        // Warm the cache so the first on-screen frame is free of crop work.
        prefetchAllFrames()
    }

    init(frames: [UIImage]) {
        self.image = frames.first ?? UIImage()
        self.cols = max(1, frames.count)
        self.rows = 1
        self.directFrames = frames.isEmpty ? nil : frames
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
        if let directFrames { return directFrames[f] }
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

    /// White silhouette of `frame`: the frame's own alpha, filled white via `.sourceIn` in a
    /// fresh transparent bitmap. A `.sourceAtop` fill on the live canvas is *not* equivalent —
    /// the stage underneath is opaque, so "atop" covers the whole sprite rect (the white box bug).
    private func flashImage(_ frame: Int) -> UIImage? {
        let total = max(1, frameCount)
        let f = ((frame % total) + total) % total
        cacheLock.lock()
        if let cached = flashCache[f] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        guard let piece = frameImage(f), let cg = piece.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let bmp = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        bmp.draw(cg, in: rect)
        bmp.setBlendMode(.sourceIn)
        bmp.setFillColor(UIColor.white.cgColor)
        bmp.fill(rect)
        guard let out = bmp.makeImage() else { return nil }
        let img = UIImage(cgImage: out, scale: piece.scale, orientation: .up)
        cacheLock.lock()
        flashCache[f] = img
        cacheLock.unlock()
        return img
    }

    /// Hit-flash overlay: tints only the sprite's pixels, never its bounding box.
    func drawFlash(in ctx: CGContext, frame: Int, dest: CGRect, flipX: Bool, alpha: CGFloat) {
        guard alpha > 0.01, dest.width > 0.5, dest.height > 0.5 else { return }
        guard let piece = flashImage(frame) else { return }
        ctx.saveGState()
        ctx.interpolationQuality = .none
        if flipX {
            ctx.translateBy(x: dest.midX, y: dest.midY)
            ctx.scaleBy(x: -1, y: 1)
            ctx.translateBy(x: -dest.midX, y: -dest.midY)
        }
        UIGraphicsPushContext(ctx)
        piece.draw(in: dest, blendMode: .normal, alpha: min(1, alpha))
        UIGraphicsPopContext()
        ctx.restoreGState()
    }
}

final class GameAssets: @unchecked Sendable {
    private(set) var jjIdle: SpriteSheet?
    /// Front-facing 2×2 from front-idle.jpg. Loaded opt(); idle pointer stays jjIdle until we flip.
    private(set) var jjIdleFront: SpriteSheet?
    private(set) var jjWalk: SpriteSheet?
    private(set) var jjRun: SpriteSheet?
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
    private(set) var selectAndrew: UIImage?
    private(set) var selectHan: UIImage?
    /// Endless fighters — idle 1×1 128², walk 2×2 256².
    private(set) var andrewIdle: SpriteSheet?
    private(set) var andrewWalk: SpriteSheet?
    private(set) var hanIdle: SpriteSheet?
    private(set) var hanWalk: SpriteSheet?
    /// Andrew/Han combat — 1-frame 128 cells (not JJ 2×2). Missing → that fighter's idle.
    private(set) var andrewAttack: SpriteSheet?
    private(set) var andrewKick: SpriteSheet?
    private(set) var andrewHurt: SpriteSheet?
    private(set) var hanAttack: SpriteSheet?
    private(set) var hanKick: SpriteSheet?
    private(set) var hanHurt: SpriteSheet?
    /// Andrew/Han jump + guitar riff — 2×2 256² sheets mirroring jj_jump / jj_special frame order.
    private(set) var andrewJump: SpriteSheet?
    private(set) var andrewSpecial: SpriteSheet?
    private(set) var hanJump: SpriteSheet?
    private(set) var hanSpecial: SpriteSheet?

    private var enemySheets: [String: SpriteSheet] = [:]
    /// Moveset sheets keyed `<fighter>_<sheetKey>` (jj_punch1, han_kick2, andrew_knockdown …).
    /// All optional: `sheetForPlayer` degrades to the base attack / kick / hurt atlas.
    private var moveSheets: [String: SpriteSheet] = [:]
    /// Suffixes probed for every fighter at load — matches tools/pack_sheet.py `--move` names.
    static let moveSheetKeys = ["punch1", "punch2", "punch3", "kick1", "kick2", "airkick", "dash", "knockdown"]
    private(set) var sky: UIImage?
    private(set) var farBg: UIImage?
    private(set) var midBg: UIImage?
    /// Act I stage parallax (0..<4). Falls back to sky/farBg/midBg.
    private(set) var stageMaps: [Int: (sky: UIImage?, far: UIImage?, mid: UIImage?)] = [:]
    private(set) var impact: SpriteSheet?
    /// Only flipped to true on the main thread after a full load finishes.
    private(set) var ready = false

    /// Build sprite sheets. Prefer `stripChroma: false` for first paint — production assets
    /// are already transparent; chroma is expensive and blocked the main thread on device.
    func load(stripChroma: Bool = false) {
        let t0 = CFAbsoluteTimeGetCurrent()
        let idle = must("jj_idle", 2, 2, stripChroma: stripChroma)
        let idleFront = opt("jj_idle_front", 2, 2, stripChroma: stripChroma)
        let walk = must("jj_walk", 4, 2, stripChroma: stripChroma)
        let run = Self.loadCachedRunSheet() ?? opt("jj_run", 4, 2, stripChroma: stripChroma)
        let attack = must("jj_attack", 2, 2, stripChroma: stripChroma)
        let kick = must("jj_kick", 2, 2, stripChroma: stripChroma)
        let hurt = must("jj_hurt", 2, 2, stripChroma: stripChroma)
        let jump = must("jj_jump", 2, 2, stripChroma: stripChroma)
        // 8-frame 4×2 riff (wind-up → strums → crouch → head-bang → finisher); engine reads frameCount.
        let special = must("jj_special", 4, 2, stripChroma: stripChroma)
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
            // Reaction sheets from the clip pipeline (any square-cell grid). Missing → idle.
            for a in ["hurt", "knockdown", "dead"] {
                if let s = optAuto("en_\(t)_\(a)") {
                    enemies["\(t)_\(a)"] = s
                }
            }
        }
        var moves: [String: SpriteSheet] = [:]
        for who in ["jj", "andrew", "han"] {
            for key in Self.moveSheetKeys {
                if let s = optAuto("\(who)_\(key)") {
                    moves["\(who)_\(key)"] = s
                }
            }
        }
        let impactSheet = opt("fx_impact", 2, 2, stripChroma: stripChroma)
        // Do NOT decode map_* at title — 1536×864 ×3 (+ stage packs) jetsam'd the sim ~5s after title.
        // Parallax loads lazily in maps(forStageIndex:) when gameplay first draws a stage.
        let skyImg: UIImage? = nil
        let farImg: UIImage? = nil
        let midImg: UIImage? = nil
        let titleImg = UIImage(named: "title_screen")
        let selectAndrewImg = UIImage(named: "select_andrew")
        let selectHanImg = UIImage(named: "select_han")
        // Andrew/Han: grid inferred from the PNG (1×1 128² today; 2×2 / 4×2 once the clip
        // pipeline re-packs them). Missing → nil, never force-unwrap.
        let andrewIdleSheet = optAuto("andrew_idle")
        let andrewWalkSheet = optAuto("andrew_walk")
        let hanIdleSheet = optAuto("han_idle")
        let hanWalkSheet = optAuto("han_walk")
        let andrewAttackSheet = optAuto("andrew_attack")
        let andrewKickSheet = optAuto("andrew_kick")
        let andrewHurtSheet = optAuto("andrew_hurt")
        let hanAttackSheet = optAuto("han_attack")
        let hanKickSheet = optAuto("han_kick")
        let hanHurtSheet = optAuto("han_hurt")
        let andrewJumpSheet = opt("andrew_jump", 2, 2, stripChroma: stripChroma)
        let andrewSpecialSheet = opt("andrew_special", 2, 2, stripChroma: stripChroma)
        let hanJumpSheet = opt("han_jump", 2, 2, stripChroma: stripChroma)
        let hanSpecialSheet = opt("han_special", 2, 2, stripChroma: stripChroma)

        let isReady = idle != nil && walk != nil
        print("[JJ] assets load stripChroma=\(stripChroma) ready=\(isReady) idle=\(idle != nil) walk=\(walk != nil) title=\(titleImg != nil) enemies=\(enemies.count) dt=\(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - t0))s")

        let publish = { [weak self] in
            guard let self else { return }
            self.jjIdle = idle
            self.jjIdleFront = idleFront
            self.jjWalk = walk
            self.jjRun = run
            self.jjAttack = attack
            self.jjKick = kick
            self.jjHurt = hurt
            self.jjJump = jump
            self.jjSpecial = special
            self.jjSmoke = smoke
            self.jjVictory = victory
            self.jjPortrait = portrait
            self.titleScreen = titleImg
            self.selectAndrew = selectAndrewImg
            self.selectHan = selectHanImg
            self.andrewIdle = andrewIdleSheet
            self.andrewWalk = andrewWalkSheet
            self.hanIdle = hanIdleSheet
            self.hanWalk = hanWalkSheet
            self.andrewAttack = andrewAttackSheet
            self.andrewKick = andrewKickSheet
            self.andrewHurt = andrewHurtSheet
            self.hanAttack = hanAttackSheet
            self.hanKick = hanKickSheet
            self.hanHurt = hanHurtSheet
            self.andrewJump = andrewJumpSheet
            self.andrewSpecial = andrewSpecialSheet
            self.hanJump = hanJumpSheet
            self.hanSpecial = hanSpecialSheet
            self.enemySheets = enemies
            self.moveSheets = moves
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
            // Pass 1: no chroma — title must stay alive (stripChroma:true jetsam'd sim ~5s after title).
            // Sheets are already transparent in xcassets; chroma polish is optional later.
            self.load(stripChroma: false)
            DispatchQueue.main.async {
                onDone()
            }

            // Bake a 16-frame loop from the bundled run movie. The 8-frame atlas stays
            // on screen until the cycle-cropped sheet is ready (or a previous bake is cached).
            Task { [weak self] in
                guard let runSheet = await Self.makeRunSheetFromVideo() else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.jjRun = runSheet
                }
            }
        }
    }

    // MARK: - JJ run (movie → 128px loop)

    /// Unique cells in the baked run strip. Engine plays them in ~0.5s.
    private static let runOutputFrames = 16
    private static let runCell = 128
    private static let runBakeVersion = 3

    private static func makeRunSheetFromVideo() async -> SpriteSheet? {
        if let cached = loadCachedRunSheet() { return cached }

        guard let videoURL = runningAnimationURL() else {
            print("[JJ] running animation video is missing from the app bundle")
            return nil
        }

        let asset = AVURLAsset(url: videoURL)
        let duration: Double
        do {
            duration = try await asset.load(.duration).seconds
        } catch {
            print("[JJ] couldn't read running animation duration: \(error)")
            return nil
        }
        guard duration.isFinite, duration > 0.08 else {
            print("[JJ] running animation has an invalid duration")
            return nil
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 720, height: 720)
        // A little slack so we don't drop times on compressed movies.
        let slack = CMTime(seconds: 0.02, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = slack
        generator.requestedTimeToleranceAfter = slack

        // Probe densely enough to find one gait cycle. Sampling the whole clip
        // (old path) mixed several strides and looked like a strobe.
        let probeFps = 12.0
        let probeWindow = min(duration, 2.5)
        let probeCount = max(8, Int((probeWindow * probeFps).rounded()))
        var probe: [CGImage] = []
        probe.reserveCapacity(probeCount)
        for i in 0..<probeCount {
            let seconds = min(duration - 0.001, (Double(i) + 0.5) / probeFps)
            if let img = await cgImage(from: generator, at: seconds) {
                probe.append(img)
            }
        }
        guard probe.count >= 6 else {
            print("[JJ] running animation decoded \(probe.count) probe frames; keeping atlas fallback")
            return nil
        }

        let rawPeriod: Double
        if duration <= 2.0 {
            rawPeriod = duration
        } else {
            rawPeriod = detectRunPeriod(frames: probe, fps: probeFps) ?? min(0.7, duration)
        }
        let period = max(0.28, min(rawPeriod, duration))

        let frameCount = runOutputFrames
        var raw: [CGImage] = []
        raw.reserveCapacity(frameCount)
        for index in 0..<frameCount {
            let seconds = (Double(index) + 0.5) / Double(frameCount) * period
            if let img = await cgImage(from: generator, at: min(duration - 0.001, seconds)) {
                raw.append(img)
            }
        }
        guard raw.count == frameCount else {
            print("[JJ] running animation decoded \(raw.count)/\(frameCount) cycle frames; keeping atlas fallback")
            return nil
        }

        let crop = registeredRunCrop(in: raw) ?? centerSquare(raw[0])
        var cells: [UIImage] = []
        cells.reserveCapacity(raw.count)
        for image in raw {
            guard let cropped = image.cropping(to: crop) else { continue }
            guard let scaled = scaleImage(cropped, to: runCell) else { continue }
            let keyed = keyRunBackground(scaled)
            cells.append(UIImage(cgImage: keyed, scale: 1, orientation: .up))
        }
        guard cells.count == frameCount else {
            print("[JJ] running animation failed to register \(cells.count)/\(frameCount) cells")
            return nil
        }

        saveRunCache(cells)
        print("[JJ] running animation ready: \(frameCount) frames, period=\(String(format: "%.2f", period))s crop=\(Int(crop.width))x\(Int(crop.height))")
        return SpriteSheet(frames: cells)
    }

    private static func runningAnimationURL() -> URL? {
        let names = ["Running Animation ", "Running Animation", "RunningAnimation"]
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: "MP4") { return url }
            if let url = Bundle.main.url(forResource: name, withExtension: "mp4") { return url }
            if let url = Bundle.main.url(forResource: name, withExtension: "MP4", subdirectory: "Video") { return url }
            if let url = Bundle.main.url(forResource: name, withExtension: "mp4", subdirectory: "Video") { return url }
        }
        let exts = ["MP4", "mp4", "MOV", "mov"]
        for ext in exts {
            if let url = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil)?
                .first(where: { $0.lastPathComponent.localizedCaseInsensitiveContains("running animation") }) {
                return url
            }
        }
        return nil
    }

    private static func runCacheURL() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("jj_run_smooth_v\(runBakeVersion).png")
    }

    private static func loadCachedRunSheet() -> SpriteSheet? {
        guard let url = runCacheURL(),
              FileManager.default.fileExists(atPath: url.path),
              let img = UIImage(contentsOfFile: url.path),
              let cg = img.cgImage else { return nil }
        let cols = cg.width / runCell
        let rows = max(1, cg.height / runCell)
        guard cols >= 4, rows >= 1,
              cg.width == cols * runCell,
              cg.height == rows * runCell else { return nil }
        print("[JJ] running animation cache hit \(cols)×\(rows) cells")
        return SpriteSheet(image: img, cols: cols, rows: rows)
    }

    private static func saveRunCache(_ frames: [UIImage]) {
        guard frames.count >= 4, let url = runCacheURL() else { return }
        let cols = frames.count
        let w = cols * runCell
        let h = runCell
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: &data, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w * 4, space: cs, bitmapInfo: info
        ) else { return }
        ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.interpolationQuality = .high
        for (i, frame) in frames.enumerated() {
            guard let cg = frame.cgImage else { continue }
            ctx.draw(cg, in: CGRect(x: i * runCell, y: 0, width: runCell, height: runCell))
        }
        guard let atlas = ctx.makeImage() else { return }
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, atlas, nil)
        CGImageDestinationFinalize(dest)
    }

    private static func cgImage(from generator: AVAssetImageGenerator, at seconds: Double) async -> CGImage? {
        let time = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        do {
            return try await generator.image(at: time).image
        } catch {
            print("[JJ] run frame at \(String(format: "%.3f", seconds))s failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// First lag after ~0.35s whose 32×32 luma is closest to frame 0 (gait period).
    private static func detectRunPeriod(frames: [CGImage], fps: Double) -> Double? {
        guard frames.count >= 8 else { return nil }
        let thumbs = frames.compactMap { lumaThumb($0, size: 32) }
        guard thumbs.count == frames.count, let first = thumbs.first else { return nil }
        let minLag = max(4, Int((0.35 * fps).rounded()))
        let maxLag = min(thumbs.count - 1, max(minLag + 1, Int((1.35 * fps).rounded())))
        guard maxLag > minLag else { return Double(thumbs.count) / fps }

        var bestSad = Int.max
        var sadAt: [Int] = Array(repeating: Int.max, count: maxLag + 1)
        for lag in minLag...maxLag {
            let sad = lumaSad(first, thumbs[lag])
            sadAt[lag] = sad
            if sad < bestSad { bestSad = sad }
        }
        // First local minimum near the best SAD — the first stride, not a later echo.
        let threshold = bestSad + max(1, bestSad / 4)
        for lag in minLag...maxLag {
            let prev = lag > minLag ? sadAt[lag - 1] : Int.max
            let next = lag < maxLag ? sadAt[lag + 1] : Int.max
            let sad = sadAt[lag]
            if sad <= prev && sad <= next && sad <= threshold {
                return Double(lag) / fps
            }
        }
        return Double(minLag) / fps
    }

    private static func lumaThumb(_ image: CGImage, size: Int) -> [UInt8]? {
        var buf = [UInt8](repeating: 0, count: size * size * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &buf, width: size, height: size, bitsPerComponent: 8,
            bytesPerRow: size * 4, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        var luma = [UInt8](repeating: 0, count: size * size)
        for i in 0..<(size * size) {
            let o = i * 4
            let r = Int(buf[o]), g = Int(buf[o + 1]), b = Int(buf[o + 2])
            luma[i] = UInt8(min(255, (r * 3 + g * 6 + b) / 10))
        }
        return luma
    }

    private static func lumaSad(_ a: [UInt8], _ b: [UInt8]) -> Int {
        let n = min(a.count, b.count)
        var s = 0
        for i in 0..<n { s += abs(Int(a[i]) - Int(b[i])) }
        return s
    }

    private static func centerSquare(_ image: CGImage) -> CGRect {
        let side = min(image.width, image.height)
        return CGRect(
            x: (image.width - side) / 2,
            y: (image.height - side) / 2,
            width: side,
            height: side
        )
    }

    /// Union of the character silhouette, then a square pinned to the feet so the
    /// beat-em-up draw rect doesn't bob from a naive center crop.
    private static func registeredRunCrop(in frames: [CGImage]) -> CGRect? {
        var minX = Int.max, minY = Int.max, maxX = 0, maxY = 0
        var any = false
        for image in frames {
            guard let b = subjectBounds(in: image) else { continue }
            any = true
            minX = min(minX, b.0)
            minY = min(minY, b.1)
            maxX = max(maxX, b.2)
            maxY = max(maxY, b.3)
        }
        guard any, maxX > minX, maxY > minY else { return nil }
        let bw = maxX - minX + 1
        let bh = maxY - minY + 1
        let pad = max(4, Int(Double(max(bw, bh)) * 0.08))
        minX -= pad
        minY -= pad
        maxX += pad
        maxY += pad
        var side = max(maxX - minX + 1, maxY - minY + 1)
        let imgW = frames[0].width
        let imgH = frames[0].height
        side = min(side, min(imgW, imgH))
        var x = (minX + maxX + 1 - side) / 2
        var y = maxY + 1 - side
        x = max(0, min(x, imgW - side))
        y = max(0, min(y, imgH - side))
        return CGRect(x: x, y: y, width: side, height: side)
    }

    private static func subjectBounds(in image: CGImage) -> (Int, Int, Int, Int)? {
        let w = image.width, h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &data, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w * 4, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var minX = w, minY = h, maxX = 0, maxY = 0
        for y in 0..<h {
            let row = y * w * 4
            for x in 0..<w {
                let i = row + x * 4
                let r = Int(data[i]), g = Int(data[i + 1]), b = Int(data[i + 2]), a = Int(data[i + 3])
                if a < 20 { continue }
                if r + g + b < 36 { continue }
                minX = min(minX, x); minY = min(minY, y)
                maxX = max(maxX, x); maxY = max(maxY, y)
            }
        }
        guard maxX > minX, maxY > minY else { return nil }
        return (minX, minY, maxX, maxY)
    }

    private static func scaleImage(_ image: CGImage, to cell: Int) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: cell, height: cell, bitsPerComponent: 8,
            bytesPerRow: 0, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.clear(CGRect(x: 0, y: 0, width: cell, height: cell))
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: cell, height: cell))
        return ctx.makeImage()
    }

    /// Flood-fill near-black / empty canvas from the edges so boots and hair stay solid.
    private static func keyRunBackground(_ image: CGImage) -> CGImage {
        let w = image.width, h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        let bpr = w * 4
        guard let ctx = CGContext(
            data: &data, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: bpr, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        func isKey(_ i: Int) -> Bool {
            let r = Int(data[i]), g = Int(data[i + 1]), b = Int(data[i + 2]), a = Int(data[i + 3])
            if a < 18 { return true }
            return r < 22 && g < 22 && b < 22
        }

        var visited = [UInt8](repeating: 0, count: w * h)
        var queue: [Int] = []
        queue.reserveCapacity(w + h)
        func enqueue(_ x: Int, _ y: Int) {
            guard x >= 0, y >= 0, x < w, y < h else { return }
            let p = y * w + x
            if visited[p] != 0 { return }
            if !isKey(p * 4) { return }
            visited[p] = 1
            queue.append(p)
        }
        for x in 0..<w {
            enqueue(x, 0)
            enqueue(x, h - 1)
        }
        for y in 0..<h {
            enqueue(0, y)
            enqueue(w - 1, y)
        }
        var q = 0
        while q < queue.count {
            let p = queue[q]; q += 1
            let x = p % w, y = p / w
            let i = p * 4
            data[i] = 0; data[i + 1] = 0; data[i + 2] = 0; data[i + 3] = 0
            enqueue(x - 1, y)
            enqueue(x + 1, y)
            enqueue(x, y - 1)
            enqueue(x, y + 1)
        }
        return ctx.makeImage() ?? image
    }

    private var fallbackSheet: SpriteSheet {
        jjIdle ?? jjWalk ?? .empty
    }


    /// Parallax plates for the current campaign stage index (Act I 0..<5, i5 = water tower).
    /// Keeps only the requested stage resident — drops other stage packs to avoid jetsam.
    func maps(forStageIndex index: Int) -> (sky: UIImage?, far: UIImage?, mid: UIImage?) {
        if let hit = stageMaps[index] { return hit }
        let i = index + 1
        let pack: (sky: UIImage?, far: UIImage?, mid: UIImage?)
        if (1...5).contains(i) {
            pack = (
                UIImage(named: "map_i\(i)_sky") ?? UIImage(named: "map_sky"),
                UIImage(named: "map_i\(i)_far") ?? UIImage(named: "map_far"),
                UIImage(named: "map_i\(i)_mid") ?? UIImage(named: "map_mid")
            )
        } else {
            pack = (UIImage(named: "map_sky"), UIImage(named: "map_far"), UIImage(named: "map_mid"))
        }
        // Retain current stage only.
        stageMaps = [index: pack]
        sky = pack.sky
        farBg = pack.far
        midBg = pack.mid
        return pack
    }


    /// Moveset sheet for a fighter (`jj_punch2`, `han_airkick` …) if the pipeline has packed it.
    func moveSheet(fighter: String, key: String) -> SpriteSheet? {
        moveSheets["\(fighter.lowercased())_\(key)"]
    }

    /// Sheet for a fighter's current pose. `variant` selects the chain step / situational move
    /// (see MoveTable); a missing variant sheet degrades to the base attack / kick atlas, then idle,
    /// so a fighter never swaps to another fighter's art mid-move.
    func sheetForPlayer(anim: AnimName, attackKind: AttackKind?, variant: Int = 0, fighter: String = "jj") -> SpriteSheet {
        let fb = fallbackSheet
        let id = fighter.lowercased()

        // Variant sheet first — same lookup for every fighter.
        func variantSheet() -> SpriteSheet? {
            guard anim == .attack, let attackKind else { return nil }
            let key = MoveTable.base(kind: attackKind, variant: variant).sheetKey
            return moveSheet(fighter: id, key: key)
        }

        // Endless fighters: every anim resolves within that fighter's own sheets so a missing
        // atlas degrades to their idle pose, never to a JJ sprite swap mid-move.
        if id == "andrew" || id == "han" {
            let isAndrew = id == "andrew"
            let idle = (isAndrew ? andrewIdle : hanIdle) ?? fb
            let walk = (isAndrew ? andrewWalk : hanWalk) ?? idle
            let hurt = (isAndrew ? andrewHurt : hanHurt) ?? idle
            switch anim {
            case .attack:
                if let v = variantSheet() { return v }
                if attackKind == .special { return (isAndrew ? andrewSpecial : hanSpecial) ?? idle }
                if attackKind == .kick { return (isAndrew ? andrewKick : hanKick) ?? idle }
                // Gun reuses punch pose + drawn pistol overlay
                return (isAndrew ? andrewAttack : hanAttack) ?? idle
            case .hurt:
                return hurt
            case .knockdown, .dead:
                return moveSheet(fighter: id, key: "knockdown") ?? hurt
            case .jump:
                return (isAndrew ? andrewJump : hanJump) ?? idle
            case .walk, .run:
                return walk
            case .smoke, .victory, .idle:
                return idle
            }
        }

        switch anim {
        case .attack:
            if let v = variantSheet() { return v }
            if attackKind == .special { return jjSpecial ?? jjAttack ?? fb }
            if attackKind == .kick { return jjKick ?? jjAttack ?? fb }
            // Gun reuses punch pose + drawn pistol overlay
            return jjAttack ?? fb
        case .hurt: return jjHurt ?? fb
        case .knockdown, .dead: return moveSheet(fighter: "jj", key: "knockdown") ?? jjHurt ?? fb
        case .jump: return jjJump ?? fb
        case .smoke: return jjSmoke ?? fb
        case .victory: return jjVictory ?? fb
        case .walk: return jjWalk ?? fb
        case .run: return jjRun ?? jjWalk ?? fb
        case .idle: return jjIdle ?? fb
        }
    }

    /// Enemy atlases are pre-keyed transparent PNGs (runtime chroma is off for perf), so a
    /// loaded sheet never carries a solid pink cell. Reactions: hurt → `<t>_hurt`, knockdown /
    /// death → `<t>_knockdown` (or `_dead`) → hurt. A missing sheet degrades to that type's
    /// idle, then to any other enemy idle — never to a JJ sheet or a placeholder fill.
    func sheetForEnemy(type: EnemyType?, anim: AnimName) -> SpriteSheet {
        let t = type?.rawValue ?? "biz"
        let candidates: [String]
        switch anim {
        case .walk, .run: candidates = ["\(t)_walk"]
        case .attack: candidates = ["\(t)_attack"]
        case .hurt: candidates = ["\(t)_hurt"]
        case .knockdown, .dead: candidates = ["\(t)_knockdown", "\(t)_dead", "\(t)_hurt"]
        case .idle, .jump, .smoke, .victory: candidates = []
        }
        for key in candidates {
            if let s = enemySheets[key] { return s }
        }
        if let s = enemySheets["\(t)_idle"] { return s }
        for other in ["biz", "maga", "gothm", "gothf"] where other != t {
            if let s = enemySheets["\(other)_idle"] { return s }
        }
        return fallbackSheet
    }

    /// Optional sheet whose grid is inferred from the PNG: square cells, trying 128 → 160 → 192
    /// → 256 px. Lets `tools/pack_sheet.py` output drop in with no code change.
    private func optAuto(_ name: String) -> SpriteSheet? {
        guard let img = UIImage(named: name), let cg = img.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }
        for cell in [128, 160, 192, 256] where w % cell == 0 && h % cell == 0 {
            let cols = w / cell, rows = h / cell
            if cols >= 1, rows >= 1, cols <= 8, rows <= 4 {
                return SpriteSheet(image: img, cols: cols, rows: rows)
            }
        }
        // Not a cell multiple — treat as a single frame rather than mis-slicing.
        return SpriteSheet(image: img, cols: 1, rows: 1)
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
