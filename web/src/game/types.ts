import type { CharacterId, PlayMode } from "./save";

export type GamePhase = "title" | "playing" | "paused" | "waveClear" | "victory" | "gameover";

export type AnimName = "idle" | "walk" | "attack" | "hurt" | "dead" | "jump" | "smoke" | "victory";

export type Facing = 1 | -1;

export type AttackKind = "punch" | "kick" | "special" | "gun";

/** Themed enemy roster (replaces generic thugs) */
export type EnemyType = "biz" | "maga" | "gothm" | "gothf";

export interface Hitbox {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface Fighter {
  id: number;
  kind: "player" | "enemy";
  enemyType?: EnemyType;
  x: number;
  /** Lane depth (higher = closer to camera) */
  y: number;
  /** Height above the ground plane (jump) */
  z: number;
  /** Vertical jump velocity */
  zVel: number;
  vx: number;
  /** Depth velocity along the lane */
  vy: number;
  facing: Facing;
  hp: number;
  maxHp: number;
  anim: AnimName;
  animTime: number;
  animFrame: number;
  attackTimer: number;
  attackActive: boolean;
  attackHit: boolean;
  attackKind: AttackKind | null;
  /** Enemies already hit by the current special (AOE multi-target) */
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
  hue?: number;
}

export interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  maxLife: number;
  frame: number;
  kind: "impact" | "spark" | "wave" | "note" | "smoke" | "muzzle";
  /** For expanding soundwave rings */
  radius?: number;
  color?: string;
}

export interface FloatingText {
  x: number;
  y: number;
  text: string;
  life: number;
  color: string;
}

/** Comic speech bubble above JJ (e.g. pre-riff punk slogans) */
export interface SpeechBubble {
  text: string;
  life: number;
  maxLife: number;
  /** Follow player while active */
  followPlayer: boolean;
}

/** Player firearm projectile (unlocked after wave 3) */
export interface Bullet {
  x: number;
  y: number;
  z: number;
  vx: number;
  facing: Facing;
  life: number;
  damage: number;
  hitIds: number[];
}

export interface RunMods {
  punch: number;
  kick: number;
  speed: number;
  special: number;
  hp: number;
}

export interface GameState {
  phase: GamePhase;
  player: Fighter;
  enemies: Fighter[];
  particles: Particle[];
  floats: FloatingText[];
  speechBubble: SpeechBubble | null;
  bullets: Bullet[];
  cameraX: number;
  score: number;
  wave: number;
  maxWaves: number;
  waveEnemiesLeft: number;
  spawnQueue: number;
  spawnTimer: number;
  shake: number;
  hitStop: number;
  message: string;
  messageTimer: number;
  specialMeter: number;
  /** Unlocked after clearing wave 3 */
  hasGun: boolean;
  keys: Set<string>;
  touch: {
    left: boolean;
    right: boolean;
    up: boolean;
    down: boolean;
  };
  actionQueue: AttackKind[];
  jumpQueued: boolean;
  elapsed: number;
  stageWidth: number;
  /** Visual radius of active riff pulse (for drawing) */
  riffPulse: number;
  riffPulseLife: number;
  /** Cigarette-break smoke puff timer during waveClear */
  smokePuffTimer: number;
  mode: PlayMode;
  characterId: CharacterId;
  slotIndex: number;
  mods: RunMods;
  sessionKills: number;
  sessionWavesCleared: number;
}
