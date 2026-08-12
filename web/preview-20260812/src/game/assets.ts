import type { AnimName, AttackKind, EnemyType, StageId } from "./types";

export type SpriteAnim = {
  frames: HTMLImageElement[];
};

function loadImage(src: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = "anonymous";
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error(`Failed to load ${src}`));
    img.src = src;
  });
}

async function loadAnim(paths: string[]): Promise<SpriteAnim> {
  const frames = await Promise.all(paths.map(loadImage));
  return { frames };
}

export type GameAssets = {
  ready: boolean;
  jj: Record<"idle" | "walk" | "attack" | "hurt", SpriteAnim>;
  enemy: Record<"idle" | "walk" | "attack", SpriteAnim>;
  impact: SpriteAnim;
  stages: Record<StageId, { sky: HTMLImageElement; far: HTMLImageElement; mid: HTMLImageElement }>;
};

const STAGE_IDS: StageId[] = [
  "downtown",
  "opera-alley",
  "geary-strip",
  "train-yard",
  "water-tower",
];

export async function loadAssets(): Promise<GameAssets> {
  const [jjIdle, jjWalk, jjAttack, jjHurt, enIdle, enWalk, enAttack, impact, ...stageImgs] =
    await Promise.all([
      loadAnim([1, 2, 3, 4].map((i) => `/sprites/jj/idle/idle-${i}.png`)),
      loadAnim([1, 2, 3, 4].map((i) => `/sprites/jj/walk/walk-${i}.png`)),
      loadAnim([1, 2, 3, 4].map((i) => `/sprites/jj/attack/attack-${i}.png`)),
      loadAnim([1, 2, 3, 4].map((i) => `/sprites/jj/hurt/hurt-${i}.png`)),
      loadAnim([1, 2, 3, 4].map((i) => `/sprites/enemy/idle/idle-${i}.png`)),
      loadAnim([1, 2, 3, 4].map((i) => `/sprites/enemy/walk/frame-${i}.png`)),
      loadAnim([1, 2, 3, 4].map((i) => `/sprites/enemy/attack/attack-${i}.png`)),
      loadAnim([1, 2, 3, 4].map((i) => `/sprites/fx/impact-${i}.png`)),
      ...STAGE_IDS.flatMap((id) => [
        loadImage(`/stages/${id}/sky.png`),
        loadImage(`/stages/${id}/far-bg.png`),
        loadImage(`/stages/${id}/mid-bg.png`),
      ]),
    ]);

  const stages = {} as GameAssets["stages"];
  STAGE_IDS.forEach((id, i) => {
    stages[id] = {
      sky: stageImgs[i * 3] as HTMLImageElement,
      far: stageImgs[i * 3 + 1] as HTMLImageElement,
      mid: stageImgs[i * 3 + 2] as HTMLImageElement,
    };
  });

  return {
    ready: true,
    jj: { idle: jjIdle, walk: jjWalk, attack: jjAttack, hurt: jjHurt },
    enemy: { idle: enIdle, walk: enWalk, attack: enAttack },
    impact,
    stages,
  };
}

export function sheetForPlayer(
  assets: GameAssets,
  anim: AnimName,
  _kind: AttackKind | null,
): SpriteAnim {
  if (anim === "walk") return assets.jj.walk;
  if (anim === "attack") return assets.jj.attack;
  if (anim === "hurt" || anim === "dead") return assets.jj.hurt;
  return assets.jj.idle;
}

export function sheetForEnemy(assets: GameAssets, anim: AnimName, _type?: EnemyType): SpriteAnim {
  if (anim === "walk") return assets.enemy.walk;
  if (anim === "attack") return assets.enemy.attack;
  return assets.enemy.idle;
}
