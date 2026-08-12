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
  | "titleArt";

interface SheetDef {
  src: string;
  cols: number;
  rows: number;
}

const V = "v=12";

const MENU_LOOP_COUNT = 16;
export const MENU_LOOP_SRCS = Array.from(
  { length: MENU_LOOP_COUNT },
  (_, i) => `/assets/ui/menu-loop/${String(i).padStart(2, "0")}.jpg?${V}`,
);

const SHEETS: Record<SheetKey, SheetDef> = {
  jjIdle: { src: `/assets/sprites/jj/idle/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
  jjWalk: { src: `/assets/sprites/jj/walk/sheet-transparent.png?${V}`, cols: 4, rows: 2 },
  jjAttack: { src: `/assets/sprites/jj/attack/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
  jjKick: { src: `/assets/sprites/jj/kick/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
  jjHurt: { src: `/assets/sprites/jj/hurt/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
  jjJump: { src: `/assets/sprites/jj/jump/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
  jjSpecial: { src: `/assets/sprites/jj/special/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
  jjSmoke: { src: `/assets/sprites/jj/smoke/sheet-transparent.png?${V}`, cols: 2, rows: 2 },

  bizIdle: { src: `/assets/sprites/enemies/biz/idle-sheet.png?${V}`, cols: 2, rows: 2 },
  bizWalk: { src: `/assets/sprites/enemies/biz/walk-sheet.png?${V}`, cols: 2, rows: 2 },
  bizAttack: { src: `/assets/sprites/enemies/biz/attack-sheet.png?${V}`, cols: 2, rows: 2 },

  magaIdle: { src: `/assets/sprites/enemies/maga/idle-sheet.png?${V}`, cols: 2, rows: 2 },
  magaWalk: { src: `/assets/sprites/enemies/maga/walk-sheet.png?${V}`, cols: 2, rows: 2 },
  magaAttack: { src: `/assets/sprites/enemies/maga/attack-sheet.png?${V}`, cols: 2, rows: 2 },

  gothmIdle: { src: `/assets/sprites/enemies/gothm/idle-sheet.png?${V}`, cols: 2, rows: 2 },
  gothmWalk: { src: `/assets/sprites/enemies/gothm/walk-sheet.png?${V}`, cols: 2, rows: 2 },
  gothmAttack: { src: `/assets/sprites/enemies/gothm/attack-sheet.png?${V}`, cols: 2, rows: 2 },

  gothfIdle: { src: `/assets/sprites/enemies/gothf/idle-sheet.png?${V}`, cols: 2, rows: 2 },
  gothfWalk: { src: `/assets/sprites/enemies/gothf/walk-sheet.png?${V}`, cols: 2, rows: 2 },
  gothfAttack: { src: `/assets/sprites/enemies/gothf/attack-sheet.png?${V}`, cols: 2, rows: 2 },

  fxImpact: { src: `/assets/sprites/fx/sheet-transparent.png?${V}`, cols: 2, rows: 2 },
  sky: { src: `/assets/map/sky.png?${V}`, cols: 1, rows: 1 },
  farBg: { src: `/assets/map/far-bg.png?${V}`, cols: 1, rows: 1 },
  midBg: { src: `/assets/map/mid-bg.png?${V}`, cols: 1, rows: 1 },
  titleArt: { src: `/assets/ui/title-art.jpg?${V}`, cols: 1, rows: 1 },
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

export async function loadAssets(): Promise<AssetMap> {
  const entries = await Promise.all(
    (Object.keys(SHEETS) as SheetKey[]).map(async (key) => {
      const def = SHEETS[key];
      const img = await loadImage(def.src);
      return [
        key,
        {
          img,
          cols: def.cols,
          rows: def.rows,
          frameW: Math.floor(img.naturalWidth / def.cols),
          frameH: Math.floor(img.naturalHeight / def.rows),
          frameCount: def.cols * def.rows,
        } satisfies LoadedSheet,
      ] as const;
    }),
  );
  return Object.fromEntries(entries) as AssetMap;
}

export async function loadMenuLoop(): Promise<HTMLImageElement[]> {
  return Promise.all(MENU_LOOP_SRCS.map((src) => loadImage(src)));
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
