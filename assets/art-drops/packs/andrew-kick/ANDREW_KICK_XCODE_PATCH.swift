// Andrew kick — v1 Xcode patch (4-frame 2x2)
//
// 1) GameAssets.swift load()
//    OLD: let andrewKickSheet = opt("andrew_kick", 1, 1, stripChroma: stripChroma)
//    NEW: let andrewKickSheet = opt("andrew_kick", 2, 2, stripChroma: stripChroma)
//
// 2) Xcode
//    Replace JJNightBrawl/Assets.xcassets/andrew_kick.imageset/img.png
//    with artifacts/04-ios-drops/andrew-kick/andrew_kick.imageset/img.png
//    (256x256, 2x2, row-major). Contents.json already points at img.png.
//
//    Layout:
//      [f0 chamber/snap] [f1 CONTACT = uploaded PNG]
//      [f2 fold-back   ] [f3 recover               ]
//
// 3) sheetForPlayer already routes AttackKind.kick -> andrewKick. No renderer change.
//    Engine already plays 4 frames over 0.44s. Hit window t=0.14-0.34 lives on f0/f1.
//
// 4) v2 (8-frame) — only after this GameEngine change:
//    var playerKickFrames: Int = 4
//    let frames: Int
//    if kind == .special { frames = max(1, playerSpecialFrames) }
//    else if kind == .kick { frames = max(1, playerKickFrames) }
//    else { frames = 4 }
//    Inject from canvas tick:
//      engine.playerKickFrames = assets.sheetForPlayer(
//          anim: .attack, attackKind: .kick, fighter: engine.state.selectedFighter
//      ).frameCount
//
// 5) GitHub connector is text-only. PNG binaries go via Mac git or GitHub web UI.
