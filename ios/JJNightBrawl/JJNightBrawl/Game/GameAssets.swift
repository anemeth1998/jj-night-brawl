import UIKit

/// Sprite / sheet loader. Full art sheets live in the local Mac project / asset tar;
/// this scaffold provides a frame cache API and safe placeholders so the canvas can run.
final class GameAssets {
    private(set) var ready = false
    private var frameCache: [String: UIImage] = [:]

    var jjIdle: UIImage?
    var jjWalk: UIImage?
    var jjAttack: UIImage?
    var jjHurt: UIImage?
    var enemyIdle: UIImage?
    var enemyWalk: UIImage?
    var enemyAttack: UIImage?
    var fxImpact: UIImage?
    var mapSky: UIImage?
    var mapFar: UIImage?
    var mapMid: UIImage?

    func loadAsync(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.loadSync()
            DispatchQueue.main.async {
                self?.ready = true
                completion()
            }
        }
    }

    private func loadSync() {
        // Prefer Assets.xcassets / bundle sheets when present; otherwise procedural placeholders.
        jjIdle = named("jj-idle") ?? placeholderSheet(tint: UIColor(red: 0.85, green: 0.2, blue: 0.45, alpha: 1))
        jjWalk = named("jj-walk") ?? jjIdle
        jjAttack = named("jj-attack") ?? jjIdle
        jjHurt = named("jj-hurt") ?? jjIdle
        enemyIdle = named("enemy-idle") ?? placeholderSheet(tint: UIColor(red: 0.3, green: 0.35, blue: 0.55, alpha: 1))
        enemyWalk = named("enemy-walk") ?? enemyIdle
        enemyAttack = named("enemy-attack") ?? enemyIdle
        fxImpact = named("fx-impact")
        mapSky = named("map-sky")
        mapFar = named("map-far")
        mapMid = named("map-mid")
    }

    private func named(_ name: String) -> UIImage? {
        UIImage(named: name)
    }

    private func placeholderSheet(tint: UIColor) -> UIImage {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let cell: CGFloat = 128
            for row in 0..<2 {
                for col in 0..<2 {
                    let r = CGRect(x: CGFloat(col) * cell + 24, y: CGFloat(row) * cell + 16, width: 80, height: 96)
                    tint.withAlphaComponent(0.9).setFill()
                    UIBezierPath(roundedRect: r, cornerRadius: 8).fill()
                }
            }
        }
    }

    /// Cached crop of a sheet cell (avoids re-cropping every draw — freeze mitigation).
    func frame(sheet: UIImage?, cols: Int = 2, rows: Int = 2, index: Int, key: String) -> UIImage? {
        guard let sheet else { return nil }
        let cacheKey = "\(key)-\(index)"
        if let hit = frameCache[cacheKey] { return hit }
        let cw = sheet.size.width / CGFloat(cols)
        let ch = sheet.size.height / CGFloat(rows)
        let col = index % cols
        let row = (index / cols) % rows
        let rect = CGRect(x: CGFloat(col) * cw * sheet.scale,
                          y: CGFloat(row) * ch * sheet.scale,
                          width: cw * sheet.scale,
                          height: ch * sheet.scale)
        guard let cg = sheet.cgImage?.cropping(to: rect) else { return sheet }
        let img = UIImage(cgImage: cg, scale: sheet.scale, orientation: sheet.imageOrientation)
        frameCache[cacheKey] = img
        return img
    }
}
