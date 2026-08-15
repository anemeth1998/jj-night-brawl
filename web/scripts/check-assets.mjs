import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");

const required = [
  "assets/ui/title-screen.png",
  "assets/ui/jj-frames/f001.jpg",
  "assets/ui/menu-select-loop.mp4",
  "assets/ui/andrew-hover.mp4",
  "assets/ui/han-hover.mp4",
  "assets/audio/tdm-8bit.mp3",
  "assets/map/sky.png",
  "assets/map/far-bg.png",
  "assets/map/mid-bg.png",
  "assets/sprites/jj/idle/sheet-transparent.png",
  "assets/sprites/jj/walk/sheet-transparent.png",
  "assets/sprites/jj/walk/walk-1.png",
  "assets/sprites/jj/walk/walk-2.png",
  "assets/sprites/jj/walk/walk-3.png",
  "assets/sprites/jj/walk/walk-4.png",
  "assets/sprites/jj/walk/walk-5.png",
  "assets/sprites/jj/walk/walk-6.png",
  "assets/sprites/jj/walk/walk-7.png",
  "assets/sprites/jj/walk/walk-8.png",
  "assets/sprites/jj/attack/sheet-transparent.png",
  "assets/sprites/jj/kick/sheet-transparent.png",
  "assets/sprites/jj/hurt/sheet-transparent.png",
  "assets/sprites/jj/jump/sheet-transparent.png",
  "assets/sprites/jj/special/sheet-transparent.png",
  "assets/sprites/jj/smoke/sheet-transparent.png",
  "assets/sprites/fx/sheet-transparent.png",
  "assets/sprites/andrew/idle/sheet-transparent.png",
  "assets/sprites/andrew/walk/sheet-transparent.png",
  "assets/sprites/andrew/walk/walk-1.png",
  "assets/sprites/andrew/walk/walk-2.png",
  "assets/sprites/andrew/walk/walk-3.png",
  "assets/sprites/andrew/walk/walk-4.png",
  "assets/sprites/andrew/walk/walk-5.png",
  "assets/sprites/andrew/walk/walk-6.png",
  "assets/sprites/andrew/walk/walk-7.png",
  "assets/sprites/andrew/walk/walk-8.png",
  "assets/sprites/andrew/attack/sheet-transparent.png",
  "assets/sprites/andrew/kick/sheet-transparent.png",
  "assets/sprites/andrew/hurt/sheet-transparent.png",
  "assets/sprites/han/idle/sheet-transparent.png",
  "assets/sprites/han/walk/sheet-transparent.png",
  "assets/sprites/han/walk/walk-1.png",
  "assets/sprites/han/walk/walk-2.png",
  "assets/sprites/han/walk/walk-3.png",
  "assets/sprites/han/walk/walk-4.png",
  "assets/sprites/han/walk/walk-5.png",
  "assets/sprites/han/walk/walk-6.png",
  "assets/sprites/han/walk/walk-7.png",
  "assets/sprites/han/walk/walk-8.png",
  "assets/sprites/han/attack/sheet-transparent.png",
  "assets/sprites/han/kick/sheet-transparent.png",
  "assets/sprites/han/hurt/sheet-transparent.png",
];

for (const type of ["biz", "maga", "gothm", "gothf"]) {
  for (const anim of ["idle", "walk", "attack"]) {
    required.push(`assets/sprites/enemies/${type}/${anim}-sheet.png`);
  }
}

const missing = required.filter((rel) => !fs.existsSync(path.join(root, rel)));
if (missing.length) {
  console.error("Missing runtime assets:");
  for (const file of missing) console.error(`  - ${file}`);
  process.exit(1);
}

console.log(`All ${required.length} runtime assets are present.`);
