export type GamePhase = "playing" | "paused" | "waveClear" | "victory" | "gameover";

export type AnimName = "idle" | "walk" | "attack" | "hurt" | "dead" | "jump";

export type AttackKind = "punch" | "kick" | "special";

export type EnemyType = "biz" | "maga" | "goth";

export type ParticleKind = "impact" | "spark" | "wave";

export type StageId = "downtown" | "opera-alley" | "geary-strip" | "train-yard" | "water-tower";

export type Fighter = {
  id: number;
  kind: "player" | "enemy";
  enemyType?: EnemyType;
  x: number;
  y: number;
  z: number;
  zVel: number;
  vx: number;
  vy: number;
  facing: 1 | -1;
  hp: number;
  maxHp: number;
  anim: AnimName;
  animTime: number;
  animFrame: number;
  attackTimer: number;
  attackActive: boolean;
  attackHit: boolean;
  attackKind: AttackKind | null;
  specialHitIds: number[];
  hurtTimer: number;
  invulnTimer: number;
  combo: number;
  comboTimer: number;
  dead: boolean;
  deathTimer: number;
  aiCooldown: number;
  flash: number;
  scoreValue: number;
  scale: number;
  bodyW: number;
  bodyH: number;
};

export type Particle = {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  maxLife: number;
  frame: number;
  kind: ParticleKind;
};

export type FloatText = {
  x: number;
  y: number;
  text: string;
  life: number;
  color: string;
};

export type SpeechBubble = {
  text: string;
  life: number;
  maxLife: number;
};

export type TouchState = {
  left: boolean;
  right: boolean;
  up: boolean;
  down: boolean;
};

export type GameState = {
  phase: GamePhase;
  player: Fighter;
  enemies: Fighter[];
  particles: Particle[];
  floats: FloatText[];
  speech: SpeechBubble | null;
  cameraX: number;
  score: number;
  wave: number;
  maxWaves: number;
  spawnQueue: number;
  spawnTimer: number;
  shake: number;
  hitStop: number;
  message: string;
  messageTimer: number;
  specialMeter: number;
  keys: Set<string>;
  touch: TouchState;
  actionQueue: AttackKind[];
  jumpQueued: boolean;
  elapsed: number;
  stageWidth: number;
  stageId: StageId;
};

export const STAGES: { id: StageId; title: string; wave: string; blurb: string }[] = [
  {
    id: "downtown",
    title: "Downtown Junction City",
    wave: "Waves 1–2",
    blurb: "Brick storefronts, wet asphalt, first night of the brawl.",
  },
  {
    id: "opera-alley",
    title: "Hoover Opera Alley",
    wave: "Wave 3",
    blurb: "Clock tower, pink marquee, an alley that does not want you here.",
  },
  {
    id: "geary-strip",
    title: "Geary Blvd Strip",
    wave: "Wave 4",
    blurb: "Gas canopy, diner neon, a slab of asphalt made for a rumble.",
  },
  {
    id: "train-yard",
    title: "Yard & Overpass",
    wave: "Wave 5",
    blurb: "Boxcars, chain-link, interstate hanging over the fight.",
  },
  {
    id: "water-tower",
    title: "Water Tower Roof",
    wave: "Boss",
    blurb: "Tar roof, steel legs, the whole town watching from below.",
  },
];

export const VIEW_W = 960;
export const VIEW_H = 540;
export const LANE_TOP = 310;
export const LANE_BOTTOM = 500;
export const STAGE_WIDTH = 2800;
