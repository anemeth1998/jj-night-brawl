export type SheetKey =
  | "jjIdle"
  | "jjWalk"
  | "jjAttack"
  | "jjKick"
  | "jjHurt"
  | "jjJump"
  | "jjSpecial"
  | "jjSmoke"
  | "bizIdle"
  | "bizWalk"
  | "bizAttack"
  | "magaIdle"
  | "magaWalk"
  | "magaAttack"
  | "gothmIdle"
  | "gothmWalk"
  | "gothmAttack"
  | "gothfIdle"
  | "gothfWalk"
  | "gothfAttack"
  | "fxImpact"
  | "sky"
  | "farBg"
  | "midBg"
  | "titleArt"
  | "andrewIdle"
  | "andrewWalk"
  | "hanIdle"
  | "hanWalk";

interface SheetDef {
  src: string;
  cols: number;
  rows: number;
  /** Extra paths to try if the primary file is missing. */
  fallbacks?: string[];
  tint?: string;
}

const V = "v=17";

const MENU_LOOP_COUNT = 50;
export const MENU_LOOP_SRCS = Array.from(
  { length: MENU_LOOP_COUNT },
  (_, i) => `/assets/ui/menu-frames/f${String(i + 1).padStart(3, "0")}.png?${V}`,
);

export const ANDREW_LOOP_SRCS = Array.from(
  { length: MENU_LOOP_COUNT },
  (_, i) => `/assets/ui/andrew-frames/f${String(i + 1).padStart(3, "0")}.jpg?${V}`,
);

export const HAN_LOOP_SRCS = Array.from(
  { length: MENU_LOOP_COUNT },
  (_, i) => `/assets/ui/han-frames/f${String(i + 1).padStart(3, "0")}.jpg?${V}`,
);

export const CHAR_LOOP_VIDEO: Record<"jj" | "andrew" | "han", string> = {
  jj: `/assets/ui/menu-select-loop.mp4?${V}`,
  andrew: `/assets/ui/andrew-hover.mp4?${V}`,
  han: `/assets/ui/han-hover.mp4?${V}`,
};

const SHEETS: Record<SheetKey, SheetDef> = {
  jjIdle: { src: `/assets/sprites/jj/idle/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
  jjWalk: { src: `/assets/sprites/jj/walk/sheet-transparent.png?${V}`, cols: 4, rows: 2 },
  jjAttack: { src: `/assets/sprites/jj/attack/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
  jjKick: { src: `/assets/sprites/jj/kick/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
  jjHurt: { src: `/assets/sprites/jj/hurt/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
  jjJump: { src: `/assets/sprites/jj/jump/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
  jjSpecial: { src: `/assets/sprites/jj/special/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
  jjSmoke: { src: `/assets/sprites/jj/smoke/sheet-transparent.png?${V}`, cols: 2, rows: 2 },

  bizIdle: {
    src: `/assets/sprites/enemies/biz/idle-sheet.png?${V}`,
    cols: 2,
    rows: 2,
    fallbacks: [`/assets/sprites/enemy/idle/sheet-transparent.png?${V}`],
    tint: "#c8b48a",
  },
  bizWalk: {
    src: `/assets/sprites/enemies/biz/walk-sheet.png?${V}`,
    cols: 2,
    rows: 2,
    fallbacks: [`/assets/sprites/enemy/walk/sheet-transparent.png?${V}`],
    tint: "#c8b48a",
  },
  bizAttack: {
    src: `/assets/sprites/enemies/biz/attack-sheet.png?${V}`,
    cols: 2,
    rows: 2,
    fallbacks: [`/assets/sprites/enemy/attack/sheet-transparent.png?${V}`],
    tint: "#c8b48a",
  },

  magaIdle: {
    src: `/assets/sprites/enemies/maga/idle-sheet.png?${V}`,
    cols: 2,
    rows: 2,
    fallbacks: [`/assets/sprites/enemy/idle/sheet-transparent.png?${V}`],
    tint: "#d4543a",
  },
  magaWalk: {
    src: `/assets/sprites/enemies/maga/walk-sheet.png?${V}`,
    cols: 2,
    rows: 2,
    fallbacks: [`/assets/sprites/enemy/walk/sheet-transparent.png?${V}`],
    tint: "#d4543a",
  },
  magaAttack: {
    src: `/assets/sprites/enemies/maga/attack-sheet.png?${V}`,
    cols: 2,
    rows: 2,
    fallbacks: [`/assets/sprites/enemy/attack/sheet-transparent.png?${V}`],
    tint: "#d4543a",
  },

  gothmIdle: {
    src: `/assets/sprites/enemies/gothm/idle-sheet.png?${V}`,
    cols: 2,
    rows: 2,
    fallbacks: [`/assets/sprites/enemy/idle/sheet-transparent.png?${V}`],
    tint: "#6a5a88",
  },
  gothmWalk: {
    src: `/assets/sprites/enemies/gothm/walk-sheet.png?${V}`,
    cols: 2,
    rows: 2,
    fallbacks: [`/assets/sprites/enemy/walk/sheet-transparent.png?${V}`],
    tint: "#6a5a88",
  },
  gothmAttack: {
    src: `/assets/sprites/enemies/gothm/attack-sheet.png?${V}`,
    cols: 2,
    rows: 2,
    fallbacks: [`/assets/sprites/enemy/attack/sheet-transparent.png?${V}`],
    tint: "#6a5a88",
  },

  gothfIdle: {
    src: `/assets/sprites/enemies/gothf/idle-sheet.png?${V}`,
    cols: 2,
    rows: 2,
    fallbacks: [`/assets/sprites/enemy/idle/sheet-transparent.png?${V}`],
    tint: "#8a4a72",
  },
  gothfWalk: {
    src: `/assets/sprites/enemies/gothf/walk-sheet.png?${V}`,
    cols: 2,
    rows: 2,
    fallbacks: [`/assets/sprites/enemy/walk/sheet-transparent.png?${V}`],
    tint: "#8a4a72",
  },
  gothfAttack: {
    src: `/assets/sprites/enemies/gothf/attack-sheet.png?${V}`,
    cols: 2,
    rows: 2,
    fallbacks: [`/assets/sprites/enemy/attack/sheet-transparent.png?${V}`],
    tint: "#8a4a72",
  },

  fxImpact: { src: `/assets/sprites/fx/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
  sky: { src: `/assets/map/sky.png?${V}`, cols: 1, rows: 1 },
  farBg: { src: `/assets/map/far-bg.png?${V}`, cols: 1, rows: 1 },
  midBg: { src: `/assets/map/mid-bg.png?${V}`, cols: 1, rows: 1 },
  titleArt: { src: `/assets/ui/title-screen.png?${V}`, cols: 1, rows: 1 },
  andrewIdle: { src: `/assets/sprites/andrew/idle/sheet-transparent.png?${V}`, cols: 1, rows: 1 },
  andrewWalk: { src: `/assets/sprites/andrew/walk/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
  hanIdle: { src: `/assets/sprites/han/idle/sheet-transparent.png?${V}`, cols: 1, rows: 1 },
  hanWalk: { src: `/assets/sprites/han/walk/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
};

export interface LoadedSheet {
  img: HTMLImageElement;
  cols: number;
  rows: number;
  frameW: number;
  frameH: number;
  frameCount: number;
}

export type AssetMap = Record<SheetKey, LoadedSheet>;

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = "anonymous";
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error(`Failed to load ${src}`));
    img.src = src;
  });
}

function placeholderSheet(def: SheetDef, label: string): Promise<HTMLImageElement> {
  const cell = 128;
  const canvas = document.createElement("canvas");
  canvas.width = cell * def.cols;
  canvas.height = cell * def.rows;
  const ctx = canvas.getContext("2d");
  if (ctx) {
    const tint = def.tint ?? "#ff2d8a";
    for (let row = 0; row < def.rows; row++) {
      for (let col = 0; col < def.cols; col++) {
        const x = col * cell;
        const y = row * cell;
        ctx.fillStyle = row + col === 0 ? "#140e1c" : "#1c1528";
        ctx.fillRect(x, y, cell, cell);
        ctx.fillStyle = tint;
        ctx.fillRect(x + 44, y + 28, 40, 72);
        ctx.fillStyle = "#f6eef8";
        ctx.fillRect(x + 54, y + 16, 20, 18);
        ctx.strokeStyle = "rgba(255,255,255,0.18)";
        ctx.strokeRect(x + 2, y + 2, cell - 4, cell - 4);
      }
    }
    ctx.fillStyle = "#f6eef8";
    ctx.font = "bold 14px sans-serif";
    ctx.fillText(label.slice(0, 10), 8, 18);
  }
  return loadImage(canvas.toDataURL("image/png"));
}

async function loadSheetImage(def: SheetDef, key: SheetKey): Promise<HTMLImageElement> {
  const candidates = [def.src, ...(def.fallbacks ?? [])];
  for (const src of candidates) {
    try {
      return await loadImage(src);
    } catch {
      /* try next path or placeholder */
    }
  }
  console.warn(`[JJ] missing sheet ${key}, using placeholder`);
  return placeholderSheet(def, key);
}

export async function loadAssets(): Promise<AssetMap> {
  const entries = await Promise.all(
    (Object.keys(SHEETS) as SheetKey[]).map(async (key) => {
      const def = SHEETS[key];
      const img = await loadSheetImage(def, key);
      return [
        key,
        {
          img,
          cols: def.cols,
          rows: def.rows,
          frameW: Math.max(1, Math.floor((img.naturalWidth || 128 * def.cols) / def.cols)),
          frameH: Math.max(1, Math.floor((img.naturalHeight || 128 * def.rows) / def.rows)),
          frameCount: def.cols * def.rows,
        } satisfies LoadedSheet,
      ] as const;
    }),
  );
  return Object.fromEntries(entries) as AssetMap;
}

export async function loadMenuLoop(): Promise<HTMLImageElement[]> {
  const frames: HTMLImageElement[] = [];
  for (const src of MENU_LOOP_SRCS) {
    try {
      frames.push(await loadImage(src));
    } catch {
      break;
    }
  }
  return frames;
}

export async function loadCharLoop(id: "andrew" | "han"): Promise<HTMLImageElement[]> {
  const srcs = id === "andrew" ? ANDREW_LOOP_SRCS : HAN_LOOP_SRCS;
  return Promise.all(srcs.map((src) => loadImage(src)));
}

/** Frame index left-to-right, top-to-bottom */
export function drawFrame(
  ctx: CanvasRenderingContext2D,
  sheet: LoadedSheet,
  frame: number,
  dx: number,
  dy: number,
  dw: number,
  dh: number,
  flipX = false,
) {
  if (!sheet?.img || !sheet.frameW || !sheet.frameH) return;
  const total = Math.max(1, sheet.frameCount);
  const f = ((frame % total) + total) % total;
  const col = f % sheet.cols;
  const row = Math.floor(f / sheet.cols);
  const sx = col * sheet.frameW;
  const sy = row * sheet.frameH;

  ctx.save();
  if (flipX) {
    ctx.translate(dx + dw / 2, dy + dh / 2);
    ctx.scale(-1, 1);
    ctx.translate(-(dx + dw / 2), -(dy + dh / 2));
  }
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(sheet.img, sx, sy, sheet.frameW, sheet.frameH, dx, dy, dw, dh);
  ctx.restore();
}
