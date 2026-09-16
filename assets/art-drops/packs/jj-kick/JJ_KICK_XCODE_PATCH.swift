// JJ kick — v1 Xcode notes
//
// v1 NEEDS NO GameAssets CHANGE.
// Kick is already:
//     let kick = must("jj_kick", 2, 2, stripChroma: stripChroma)
//
// 1) Xcode
//    jj_kick.imageset/img.png is already the attached 256x256 2x2.
//    Only replace it if you rebuild the sheet. Contents.json already
//    points at img.png.
//
//    Layout (row-major):
//      [f0 chamber      ] [f1 mid-extend  ← hit window]
//      [f2 full-extend  ] [f3 recover-chamber         ]
//
// 2) sheetForPlayer already routes AttackKind.kick -> jjKick.
//    Engine already plays 4 frames over 0.44s.
//    Hit window t=0.14-0.34 lives on late f0 + early f1.
//
// 3) v2 (8-frame) — only after this GameEngine change:
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
// 4) GitHub connector is text-only. PNG binaries go via Mac git or GitHub web UI.
