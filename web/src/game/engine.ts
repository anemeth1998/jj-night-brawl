import type { CharacterId, PlayMode, SaveSlot } from "./save";
import { CHARACTERS, stageName, upgradeBonuses, type Profile } from "./save";
import type {
  AttackKind,
  EnemyType,
  Fighter,
  GamePhase,
  GameState,
  RunMods,
} from "./types";
import type { AssetMap, SheetKey } from "./assets";
import { drawFrame } from "./assets";
import { sfx } from "./audio";

export const VIEW_W = 960;
export const VIEW_H = 540;

const LANE_TOP = 310;
const LANE_BOTTOM = 500;
const STAGE_WIDTH = 2800;

const PLAYER_SPEED = 190;
const PLAYER_DEPTH_SPEED = 120;
const ENEMY_SPEED = 95;
const ENEMY_DEPTH_SPEED = 70;

const JUMP_VEL = 520;
const GRAVITY = 1450;
const AIR_CONTROL = 0.72;

/** 8-frame walk cycle playback rate (frames per second) */
const PLAYER_WALK_FPS = 12;
const ENEMY_WALK_FPS = 8;

const ATTACK_DURATION: Record<AttackKind, number> = {
  punch: 0.36,
  kick: 0.48,
  special: 0.95, // full guitar riff
  gun: 0.42,
};
const ATTACK_ACTIVE: Record<AttackKind, [number, number]> = {
  punch: [0.12, 0.28],
  kick: [0.16, 0.38],
  special: [0.18, 0.82], // sustained shockwave while shredding
  gun: [0.08, 0.22],
};
const GUN_DAMAGE = 28;
const GUN_BULLET_SPEED = 720;
const GUN_BULLET_LIFE = 0.55;
const GANG_VIOLENCE_LINE = "Counting or not counting gang violence?";
const GANG_LINE_LIFE = 3.4;
/** World-space radius of the riff blast (expands during active window) */
const RIFF_RADIUS_MIN = 90;
const RIFF_RADIUS_MAX = 210;
const RIFF_DAMAGE = 22;
const RIFF_KNOCK = 340;
const HURT_DURATION = 0.35;
const INVULN_AFTER_HIT = 0.55;
const COMBO_WINDOW = 1.1;
const SPEECH_BUBBLE_LIFE = 1.15;
/** Cigarette break between waves */
const WAVE_CLEAR_DURATION = 3.2;
const SMOKE_FRAME_FPS = 2.2;

/** Pre-riff taunts — random one pops in a speech bubble above JJ */
const PUNK_SLOGANS = [
  "FUCK YEAH!",
  "EAT SHIT BOOTLICKERS!",
  "NOT MY PRESIDENT!",
  "EAT THE RICH!",
  "NO GODS NO MASTERS!",
  "SMASH THE STATE!",
  "DIE YUPPIE SCUM!",
  "THIS MACHINE KILLS FASCISTS!",
  "PUNKS NOT DEAD!",
  "BURN IT DOWN!",
  "ACAB!",
  "CLASS WAR NOW!",
  "NO FUTURE? MAKE ONE!",
  "SCREW YOUR SUIT!",
  "RIFF OR DIE!",
];

const ENEMY_TYPES: EnemyType[] = ["biz", "maga", "gothm", "gothf"];

let nextId = 1;

function grounded(f: Fighter) {
  return f.z <= 0.5 && f.zVel <= 0;
}

function makePlayer(hp = 100, hue = 0, scale = 1.7): Fighter {
  return {
    id: nextId++,
    kind: "player",
    x: 220,
    y: 400,
    z: 0,
    zVel: 0,
    vx: 0,
    vy: 0,
    facing: 1,
    hp,
    maxHp: hp,
    anim: "idle",
    animTime: 0,
    animFrame: 0,
    attackTimer: 0,
    attackActive: false,
    attackHit: false,
    attackKind: null,
    specialHitIds: [],
    hurtTimer: 0,
    invulnTimer: 0,
    combo: 0,
    comboTimer: 0,
    dead: false,
    deathTimer: 0,
    aiCooldown: 0,
    flash: 0,
    scoreValue: 0,
    scale,
    bodyW: 42,
    bodyH: 88,
    hue,
  };
}

function makeEnemy(x: number, y: number, wave: number, type?: EnemyType): Fighter {
  const enemyType = type ?? ENEMY_TYPES[Math.floor(Math.random() * ENEMY_TYPES.length)]!;
  const hpMul = enemyType === "biz" ? 1.1 : enemyType === "maga" ? 1.05 : 0.95;
  const hp = Math.round((28 + wave * 8) * hpMul);
  const scale = enemyType === "gothf" ? 1.4 : enemyType === "biz" ? 1.5 : 1.48;
  return {
    id: nextId++,
    kind: "enemy",
    enemyType,
    x,
    y,
    z: 0,
    zVel: 0,
    vx: 0,
    vy: 0,
    facing: -1,
    hp,
    maxHp: hp,
    anim: "idle",
    animTime: 0,
    animFrame: 0,
    attackTimer: 0,
    attackActive: false,
    attackHit: false,
    attackKind: null,
    specialHitIds: [],
    hurtTimer: 0,
    invulnTimer: 0,
    combo: 0,
    comboTimer: 0,
    dead: false,
    deathTimer: 0,
    aiCooldown: 0.4 + Math.random() * 0.6,
    flash: 0,
    scoreValue: 100 + wave * 40 + (enemyType === "biz" ? 20 : 0),
    scale,
    bodyW: 48,
    bodyH: 90,
  };
}

export function createGameState(): GameState {
  return {
    phase: "title",
    player: makePlayer(),
    enemies: [],
    particles: [],
    floats: [],
    speechBubble: null,
    bullets: [],
    cameraX: 0,
    score: 0,
    wave: 0,
    maxWaves: 5,
    waveEnemiesLeft: 0,
    spawnQueue: 0,
    spawnTimer: 0,
    shake: 0,
    hitStop: 0,
    message: "",
    messageTimer: 0,
    specialMeter: 0,
    hasGun: false,
    keys: new Set(),
    touch: {
      left: false,
      right: false,
      up: false,
      down: false,
    },
    actionQueue: [],
    jumpQueued: false,
    elapsed: 0,
    stageWidth: STAGE_WIDTH,
    riffPulse: 0,
    riffPulseLife: 0,
    smokePuffTimer: 0,
    mode: "story",
    characterId: "jj",
    slotIndex: 0,
    mods: { punch: 0, kick: 0, speed: 1, special: 1, hp: 0 },
    sessionKills: 0,
    sessionWavesCleared: 0,
  };
}

export interface StartOpts {
  mode?: PlayMode;
  characterId?: CharacterId;
  startWave?: number;
  slotIndex?: number;
  profile: Profile;
  slot?: SaveSlot | null;
}

export function startGame(state: GameState, opts?: StartOpts) {
  const profile = opts?.profile;
  const mods: RunMods = profile
    ? upgradeBonuses(profile)
    : { punch: 0, kick: 0, speed: 1, special: 1, hp: 0 };
  const mode = opts?.mode ?? "story";
  const characterId = opts?.characterId ?? opts?.slot?.characterId ?? "jj";
  const spec = CHARACTERS[characterId] ?? CHARACTERS.jj;
  const startWave = opts?.slot?.wave ?? opts?.startWave ?? 1;
  const hp = spec.hp + mods.hp;

  nextId = 1;
  Object.assign(state, createGameState());
  state.phase = "playing";
  state.mode = mode;
  state.characterId = characterId;
  state.slotIndex = opts?.slotIndex ?? 0;
  state.mods = mods;
  state.maxWaves = mode === "endless" ? 99 : 5;
  state.player = makePlayer(
    hp,
    0,
    characterId === "andrew" ? 1.62 : characterId === "han" ? 1.58 : 1.7,
  );
  if (opts?.slot) {
    state.score = opts.slot.score;
    state.hasGun = opts.slot.hasGun;
    state.specialMeter = opts.slot.specialMeter;
    state.player.hp = Math.min(hp, Math.max(20, opts.slot.hp));
  }
  if (startWave > 3) state.hasGun = true;
  sfx.uiConfirm();
  beginWave(state, Math.max(1, startWave));
}

export function snapshotSlot(state: GameState): SaveSlot {
  return {
    updatedAt: Date.now(),
    mode: state.mode,
    characterId: state.characterId,
    wave: Math.max(1, state.wave),
    score: state.score,
    hasGun: state.hasGun,
    hp: state.player.hp,
    maxHp: state.player.maxHp,
    specialMeter: state.specialMeter,
    stageName: stageName(state.wave),
  };
}

export function queueAction(state: GameState, kind: AttackKind) {
  if (state.phase !== "playing") return;
  state.actionQueue = [kind];
}

export function queueJump(state: GameState) {
  if (state.phase !== "playing") return;
  state.jumpQueued = true;
}


function beginSmokeBreak(state: GameState, message: string, duration: number) {
  const p = state.player;
  p.vx = 0;
  p.vy = 0;
  p.z = 0;
  p.zVel = 0;
  p.attackTimer = 0;
  p.attackKind = null;
  p.attackActive = false;
  p.anim = "smoke";
  p.animTime = 0;
  p.animFrame = 0;
  p.hurtTimer = 0;
  state.message = message;
  state.messageTimer = duration;
  state.smokePuffTimer = 0.35;
  state.actionQueue = [];
  state.jumpQueued = false;
  state.keys.clear();
  // Keep the gunshot punchline if she just dropped the last foe with a bullet
  if (state.speechBubble?.text !== GANG_VIOLENCE_LINE) {
    state.speechBubble = null;
  }
  sfx.smokeBreak();
}

function spawnCigSmoke(state: GameState, f: Fighter) {
  const face = f.facing;
  const mouthX = f.x + face * 18;
  const mouthY = f.y - f.bodyH * f.scale * 0.72 - f.z;
  for (let i = 0; i < 4; i++) {
    state.particles.push({
      x: mouthX + (Math.random() - 0.5) * 10,
      y: mouthY + (Math.random() - 0.5) * 6,
      vx: face * (12 + Math.random() * 28) + (Math.random() - 0.5) * 20,
      vy: -25 - Math.random() * 45,
      life: 0.7 + Math.random() * 0.5,
      maxLife: 1.2,
      frame: 0,
      kind: "smoke",
      radius: 4 + Math.random() * 6,
      color: "rgba(180,180,190,0.55)",
    });
  }
}

function updateSmokeBreak(state: GameState, dt: number) {
  const p = state.player;
  p.vx = 0;
  p.vy = 0;
  p.anim = "smoke";
  p.animTime += dt;
  // Cycle hold → inhale → exhale → casual
  p.animFrame = Math.floor(p.animTime * SMOKE_FRAME_FPS) % 4;
  state.smokePuffTimer -= dt;
  // Puff on exhale frames (2) and casually
  if (state.smokePuffTimer <= 0) {
    spawnCigSmoke(state, p);
    state.smokePuffTimer = p.animFrame === 2 ? 0.28 : 0.55;
    if (p.animFrame === 2) sfx.exhale();
  }
}

function beginWave(state: GameState, wave: number) {
  state.wave = wave;
  state.enemies = [];
  state.bullets = [];
  const count = 2 + wave;
  state.waveEnemiesLeft = count;
  state.spawnQueue = count;
  state.spawnTimer = 0.35;
  if (wave === state.maxWaves && state.mode === "story") {
    state.message = "FINAL WAVE";
  } else if (state.hasGun && wave === 4) {
    state.message = `${stageName(wave).toUpperCase()} — PACKIN' HEAT`;
  } else if (state.mode === "endless") {
    state.message = `ENDLESS ${wave}`;
  } else {
    state.message = stageName(wave).toUpperCase();
  }
  state.messageTimer = 1.6;
  sfx.waveStart(wave);
}

function pressed(state: GameState, code: string) {
  return state.keys.has(code);
}

function moveAxis(state: GameState): { mx: number; my: number } {
  let mx = 0;
  let my = 0;
  if (pressed(state, "KeyA") || pressed(state, "ArrowLeft") || state.touch.left) mx -= 1;
  if (pressed(state, "KeyD") || pressed(state, "ArrowRight") || state.touch.right) mx += 1;
  if (pressed(state, "KeyW") || pressed(state, "ArrowUp") || state.touch.up) my -= 1;
  if (pressed(state, "KeyS") || pressed(state, "ArrowDown") || state.touch.down) my += 1;
  if (mx !== 0 && my !== 0) {
    const inv = 1 / Math.SQRT2;
    mx *= inv;
    my *= inv;
  }
  return { mx, my };
}

function canAct(f: Fighter) {
  return !f.dead && f.hurtTimer <= 0 && f.attackTimer <= 0;
}

function canAttack(f: Fighter) {
  return !f.dead && f.hurtTimer <= 0 && f.attackTimer <= 0;
}

function pickSlogan() {
  return PUNK_SLOGANS[Math.floor(Math.random() * PUNK_SLOGANS.length)]!;
}

function spawnPunkBubble(state: GameState) {
  state.speechBubble = {
    text: pickSlogan(),
    life: SPEECH_BUBBLE_LIFE,
    maxLife: SPEECH_BUBBLE_LIFE,
    followPlayer: true,
  };
}

function startAttack(state: GameState | null, f: Fighter, kind: AttackKind) {
  f.attackKind = kind;
  f.attackTimer = ATTACK_DURATION[kind];
  f.attackActive = false;
  f.attackHit = false;
  f.specialHitIds = f.specialHitIds ?? [];
  f.specialHitIds.length = 0;
  f.anim = "attack";
  f.animTime = 0;
  f.animFrame = 0;
  if (kind === "special") {
    // Plant and shred — no lunge; brief armor while riffing
    f.vx = 0;
    f.vy = 0;
    f.invulnTimer = Math.max(f.invulnTimer, ATTACK_DURATION.special * 0.85);
    // Punk slogan pops BEFORE the riff hits
    if (f.kind === "player" && state) {
      spawnPunkBubble(state);
    }
  } else if (kind === "gun") {
    f.vy = 0;
    f.vx = -f.facing * 40;
  } else if (grounded(f)) {
    f.vy = 0;
    f.vx = f.facing * (kind === "kick" ? 220 : 140);
  } else {
    f.vx *= 0.85;
  }
  const isPlayer = f.kind === "player";
  if (kind === "kick") sfx.kick(isPlayer);
  else if (kind === "special") sfx.special(isPlayer);
  else if (kind === "gun") sfx.gunshot();
  else sfx.punch(isPlayer);
}

function spawnBullet(state: GameState, f: Fighter) {
  const muzzleX = f.x + f.facing * 36;
  const muzzleY = f.y - f.bodyH * f.scale * 0.55 - f.z;
  state.bullets.push({
    x: muzzleX,
    y: f.y,
    z: f.z + f.bodyH * f.scale * 0.45,
    vx: f.facing * GUN_BULLET_SPEED,
    facing: f.facing,
    life: GUN_BULLET_LIFE,
    damage: GUN_DAMAGE,
    hitIds: [],
  });
  state.particles.push({
    x: muzzleX,
    y: muzzleY,
    vx: f.facing * 20,
    vy: -10,
    life: 0.12,
    maxLife: 0.12,
    frame: 0,
    kind: "muzzle",
    radius: 14,
    color: "#ffe566",
  });
  state.shake = Math.min(10, state.shake + 3);
}

function spawnGangViolenceLine(state: GameState) {
  state.speechBubble = {
    text: GANG_VIOLENCE_LINE,
    life: GANG_LINE_LIFE,
    maxLife: GANG_LINE_LIFE,
    followPlayer: true,
  };
}

function spawnRiffBurst(state: GameState, x: number, y: number, radius: number) {
  state.riffPulse = radius;
  state.riffPulseLife = 0.22;
  // Cap particle flood — too many notes/waves lagged some clients into a "crash"
  if (state.particles.length > 80) {
    state.particles.splice(0, state.particles.length - 60);
  }
  state.particles.push({
    x,
    y: y - 40,
    vx: 0,
    vy: 0,
    life: 0.35,
    maxLife: 0.35,
    frame: 0,
    kind: "wave",
    radius,
    color: "#ff2d8a",
  });
  state.particles.push({
    x,
    y: y - 40,
    vx: 0,
    vy: 0,
    life: 0.28,
    maxLife: 0.28,
    frame: 0,
    kind: "wave",
    radius: radius * 0.65,
    color: "#2de2e6",
  });
  for (let i = 0; i < 6; i++) {
    const a = (Math.PI * 2 * i) / 6 + Math.random() * 0.3;
    const s = 120 + Math.random() * 160;
    state.particles.push({
      x,
      y: y - 50 - Math.random() * 30,
      vx: Math.cos(a) * s,
      vy: Math.sin(a) * s * 0.55 - 40,
      life: 0.4 + Math.random() * 0.2,
      maxLife: 0.65,
      frame: i % 4,
      kind: "note",
      color: i % 2 === 0 ? "#ff2d8a" : "#2de2e6",
    });
  }
}

function riffRadiusAt(t: number) {
  const u = Math.max(0, Math.min(1, (t - 0.15) / 0.7));
  return RIFF_RADIUS_MIN + (RIFF_RADIUS_MAX - RIFF_RADIUS_MIN) * u;
}

function inRiffRange(attacker: Fighter, target: Fighter, radius: number) {
  const dx = target.x - attacker.x;
  const dy = (target.y - attacker.y) * 1.35;
  return Math.hypot(dx, dy) <= radius && Math.abs(attacker.z - target.z) < 80;
}

function tryJump(f: Fighter) {
  if (!grounded(f) || f.dead || f.hurtTimer > 0) return false;
  f.zVel = JUMP_VEL;
  f.z = 1;
  f.anim = "jump";
  f.animTime = 0;
  f.animFrame = 1;
  sfx.jump();
  return true;
}

function updatePhysics(f: Fighter, dt: number) {
  if (!grounded(f) || f.zVel > 0) {
    f.zVel -= GRAVITY * dt;
    f.z += f.zVel * dt;
    if (f.z <= 0) {
      f.z = 0;
      f.zVel = 0;
      if (f.kind === "player" && f.attackTimer <= 0 && f.hurtTimer <= 0) {
        sfx.land();
      }
    }
  } else {
    f.z = 0;
    f.zVel = 0;
  }
}

function spawnImpact(state: GameState, x: number, y: number) {
  state.particles.push({
    x,
    y,
    vx: 0,
    vy: -20,
    life: 0.28,
    maxLife: 0.28,
    frame: 0,
    kind: "impact",
  });
  for (let i = 0; i < 5; i++) {
    const a = Math.random() * Math.PI * 2;
    const s = 80 + Math.random() * 120;
    state.particles.push({
      x,
      y,
      vx: Math.cos(a) * s,
      vy: Math.sin(a) * s - 40,
      life: 0.25 + Math.random() * 0.2,
      maxLife: 0.4,
      frame: 0,
      kind: "spark",
    });
  }
}

function floatText(state: GameState, x: number, y: number, text: string, color: string) {
  state.floats.push({ x, y, text, life: 0.7, color });
}

function bodyBox(f: Fighter) {
  return {
    x: f.x - f.bodyW / 2,
    y: f.y - f.bodyH - f.z,
    w: f.bodyW,
    h: f.bodyH,
  };
}

function attackBox(f: Fighter) {
  const kind = f.attackKind ?? "punch";
  const reach = kind === "special" ? 82 : kind === "kick" ? 78 : 54;
  const h = kind === "kick" ? 42 : 40;
  const yOff = kind === "kick" ? 52 : 44;
  return {
    x: f.facing === 1 ? f.x + 10 : f.x - 10 - reach,
    y: f.y - yOff - h / 2 - f.z,
    w: reach,
    h,
  };
}

function depthClose(a: Fighter, b: Fighter, tol = 28) {
  return Math.abs(a.y - b.y) <= tol;
}

function applyHit(
  state: GameState,
  attacker: Fighter,
  victim: Fighter,
  damage: number,
  knock: number,
  hitKind?: AttackKind | null,
) {
  if (victim.dead || victim.invulnTimer > 0) return false;
  const kind = hitKind ?? attacker.attackKind;
  victim.hp = Math.max(0, victim.hp - damage);
  victim.hurtTimer = HURT_DURATION;
  victim.invulnTimer = INVULN_AFTER_HIT;
  victim.anim = "hurt";
  victim.animTime = 0;
  victim.animFrame = 0;
  victim.attackTimer = 0;
  victim.attackActive = false;
  victim.flash = 0.12;
  if (kind === "special") {
    let dirX = victim.x - attacker.x;
    let dirY = victim.y - attacker.y;
    const len = Math.hypot(dirX, dirY) || 1;
    dirX /= len;
    dirY /= len;
    victim.vx = dirX * knock;
    victim.vy = dirY * knock * 0.55;
    victim.zVel = Math.max(victim.zVel, 220);
    victim.facing = dirX >= 0 ? -1 : 1;
  } else {
    victim.vx = attacker.facing * knock;
    victim.facing = attacker.facing === 1 ? -1 : 1;
    if (!grounded(victim)) {
      victim.zVel = Math.max(victim.zVel, 180);
    }
  }

  attacker.combo += 1;
  attacker.comboTimer = COMBO_WINDOW;
  if (attacker.kind === "player") {
    state.score += damage * 10 + Math.max(0, attacker.combo - 1) * 15;
    // Riff doesn't refill the meter from its own hits
    if (kind !== "special") {
      state.specialMeter = Math.min(100, state.specialMeter + damage * 1.8 * state.mods.special);
    }
  }

  const ab = attackBox(attacker);
  const impactX = kind === "special" || kind === "gun" ? victim.x : ab.x + ab.w / 2;
  const impactY =
    kind === "special" || kind === "gun"
      ? victim.y - victim.bodyH * 0.5 - victim.z
      : ab.y + ab.h / 2;
  spawnImpact(state, impactX, impactY);
  floatText(
    state,
    victim.x,
    victim.y - victim.bodyH - victim.z - 10,
    kind === "special"
      ? `RIFF ${damage}`
      : kind === "gun"
        ? `BANG ${damage}`
        : attacker.combo > 1
          ? `${damage}! x${attacker.combo}`
          : `${damage}`,
    kind === "special" ? "#ff2d8a" : kind === "gun" ? "#ffe566" : attacker.combo > 3 ? "#ffd56a" : "#fff",
  );
  state.shake = Math.min(10, state.shake + (kind === "special" ? 2 : kind === "gun" ? 5 : 4));
  if (kind === "special") {
    state.hitStop = Math.max(state.hitStop, 0.02);
  } else if (kind === "gun") {
    state.hitStop = Math.max(state.hitStop, 0.04);
  } else {
    state.hitStop = kind === "kick" ? 0.06 : 0.045;
  }

  sfx.hit(kind === "gun" ? "kick" : kind, attacker.combo);
  if (victim.kind === "player") sfx.hurt();

  if (victim.hp <= 0) {
    victim.dead = true;
    victim.deathTimer = 0.9;
    victim.anim = "hurt";
    if (victim.kind === "enemy") {
      state.score += victim.scoreValue;
      state.waveEnemiesLeft = Math.max(0, state.waveEnemiesLeft - 1);
      state.sessionKills += 1;
      floatText(state, victim.x, victim.y - victim.bodyH - 28, `+${victim.scoreValue}`, "#2de2e6");
      sfx.ko();
      // Last foe of the wave dropped by a gunshot
      if (
        kind === "gun" &&
        state.waveEnemiesLeft <= 0 &&
        state.spawnQueue <= 0 &&
        state.enemies.every((e) => e.dead || e.id === victim.id)
      ) {
        spawnGangViolenceLine(state);
      }
    } else {
      sfx.playerDown();
    }
  }
  return true;
}

function updateAttack(state: GameState, f: Fighter, dt: number) {
  if (f.attackTimer <= 0 || !f.attackKind) return;
  const kind = f.attackKind;
  const total = ATTACK_DURATION[kind];
  f.attackTimer -= dt;
  const t = 1 - f.attackTimer / total;
  f.animFrame = Math.min(3, Math.floor(t * 4));

  if (grounded(f) && kind !== "special") {
    f.vx *= Math.pow(0.02, dt);
  }
  if (kind === "special") {
    f.vx = 0;
    f.vy = 0;
  }

  const [activeStart, activeEnd] = ATTACK_ACTIVE[kind];
  f.attackActive = f.attackTimer > 0 && t >= activeStart && t <= activeEnd;

  if (kind === "gun" && f.kind === "player") {
    if (f.attackActive && !f.attackHit) {
      spawnBullet(state, f);
      f.attackHit = true;
    }
  } else if (kind === "special" && f.kind === "player" && f.attackActive) {
    const radius = riffRadiusAt(t);
    const pulseMarks = [0.22, 0.4, 0.58, 0.75];
    for (const m of pulseMarks) {
      if (t >= m && t - dt / total < m) {
        spawnRiffBurst(state, f.x, f.y, radius);
        state.shake = Math.min(14, state.shake + 6);
      }
    }
    state.riffPulse = radius;
    state.riffPulseLife = Math.max(state.riffPulseLife, 0.08);

    if (!f.specialHitIds) f.specialHitIds = [];
    let riffHitThisFrame = 0;
    for (const target of state.enemies) {
      if (target.dead) continue;
      if (f.specialHitIds.includes(target.id)) continue;
      if (!inRiffRange(f, target, radius)) continue;
      // Per-enemy hitstop was stacking freezes; only brief freeze on first hit
      if (applyHit(state, f, target, RIFF_DAMAGE, RIFF_KNOCK)) {
        f.specialHitIds.push(target.id);
        riffHitThisFrame += 1;
      }
    }
    if (riffHitThisFrame > 0) {
      state.hitStop = Math.min(state.hitStop, 0.03);
    }
  } else if (f.attackActive && !f.attackHit && kind !== "special" && kind !== "gun") {
    const targets = f.kind === "player" ? state.enemies : [state.player];
    const ab = attackBox(f);
    const depthTol = kind === "kick" ? 36 : 28;
    for (const target of targets) {
      if (target.dead || !depthClose(f, target, depthTol)) continue;
      if (Math.abs(f.z - target.z) > 70) continue;
      const bb = bodyBox(target);
      if (
        ab.x < bb.x + bb.w &&
        ab.x + ab.w > bb.x &&
        ab.y < bb.y + bb.h &&
        ab.y + ab.h > bb.y
      ) {
        const airBonus = !grounded(f) && kind === "kick" ? 4 : 0;
        const bonus = f.kind === "player" ? (kind === "kick" ? state.mods.kick : state.mods.punch) : 0;
        const dmg = (kind === "kick" ? 18 : 11) + airBonus + bonus;
        const knock = kind === "kick" ? 220 : 120;
        if (applyHit(state, f, target, dmg, knock)) {
          f.attackHit = true;
        }
      }
    }
  }

  if (f.attackTimer <= 0) {
    f.attackActive = false;
    f.attackKind = null;
    f.specialHitIds = [];
    if (!grounded(f)) f.anim = "jump";
    else f.anim = "idle";
    f.animTime = 0;
    if (grounded(f)) f.vx = 0;
  }
}

function updateFighterAnim(
  f: Fighter,
  dt: number,
  moving: boolean,
  walkFrames = 4,
  walkFps = ENEMY_WALK_FPS,
) {
  if (f.dead) {
    f.anim = "hurt";
    f.animFrame = Math.min(3, Math.floor((1 - f.deathTimer / 0.9) * 4));
    return;
  }
  if (f.hurtTimer > 0) {
    f.anim = "hurt";
    f.animTime += dt;
    f.animFrame = Math.min(3, Math.floor((1 - f.hurtTimer / HURT_DURATION) * 4));
    return;
  }
  if (f.attackTimer > 0) return;
  if (!grounded(f)) {
    f.anim = "jump";
    f.animTime += dt;
    if (f.zVel > 120) f.animFrame = 1;
    else if (f.zVel > -80) f.animFrame = 2;
    else f.animFrame = 3;
    return;
  }
  if (moving) {
    f.anim = "walk";
    f.animTime += dt;
    f.animFrame = Math.floor(f.animTime * walkFps) % walkFrames;
  } else {
    f.anim = "idle";
    f.animTime += dt;
    f.animFrame = Math.floor(f.animTime * 2.5) % 4;
  }
}

function clampFighter(f: Fighter, stageW: number) {
  f.x = Math.max(60, Math.min(stageW - 60, f.x));
  f.y = Math.max(LANE_TOP, Math.min(LANE_BOTTOM, f.y));
}

function consumePlayerAction(state: GameState) {
  const p = state.player;
  if (!canAttack(p)) return;

  while (state.actionQueue.length > 0) {
    const kind = state.actionQueue.shift()!;
    if (kind === "special") {
      if (state.specialMeter < 40) continue;
      if (!grounded(p)) continue;
      state.specialMeter -= 40;
    }
    if (kind === "gun" && !state.hasGun) continue;
    startAttack(state, p, kind);
    return;
  }

  if (state.hasGun && (pressed(state, "KeyF") || pressed(state, "KeyU") || pressed(state, "KeyG"))) {
    startAttack(state, p, "gun");
    state.keys.delete("KeyF");
    state.keys.delete("KeyU");
    state.keys.delete("KeyG");
  } else if (pressed(state, "KeyJ") || pressed(state, "KeyZ")) {
    startAttack(state, p, "punch");
    state.keys.delete("KeyJ");
    state.keys.delete("KeyZ");
  } else if (pressed(state, "KeyK") || pressed(state, "KeyX")) {
    startAttack(state, p, "kick");
    state.keys.delete("KeyK");
    state.keys.delete("KeyX");
  } else if (
    grounded(p) &&
    (pressed(state, "KeyL") || pressed(state, "KeyC")) &&
    state.specialMeter >= 40
  ) {
    state.specialMeter -= 40;
    startAttack(state, p, "special");
    state.keys.delete("KeyL");
    state.keys.delete("KeyC");
  }
}

function updatePlayer(state: GameState, dt: number) {
  const p = state.player;
  if (p.dead) {
    p.deathTimer -= dt;
    updatePhysics(p, dt);
    updateFighterAnim(p, dt, false, 8, PLAYER_WALK_FPS);
    if (p.deathTimer <= 0) {
      if (state.phase !== "gameover") sfx.gameOver();
      state.phase = "gameover";
    }
    return;
  }

  if (p.hurtTimer > 0) p.hurtTimer -= dt;
  if (p.invulnTimer > 0) p.invulnTimer -= dt;
  if (p.comboTimer > 0) {
    p.comboTimer -= dt;
    if (p.comboTimer <= 0) p.combo = 0;
  }
  if (p.flash > 0) p.flash -= dt;

  updateAttack(state, p, dt);

  if (state.jumpQueued) {
    state.jumpQueued = false;
    tryJump(p);
  } else if (
    grounded(p) &&
    (pressed(state, "Space") || pressed(state, "ShiftLeft") || pressed(state, "ShiftRight"))
  ) {
    if (tryJump(p)) {
      state.keys.delete("Space");
      state.keys.delete("ShiftLeft");
      state.keys.delete("ShiftRight");
    }
  }

  let moving = false;
  const air = !grounded(p);
  const { mx, my } = moveAxis(state);

  if (canAct(p) || (air && p.attackTimer <= 0 && p.hurtTimer <= 0)) {
    const specSpeed = CHARACTERS[state.characterId]?.speed ?? 1;
    const speedMul = (air ? AIR_CONTROL : 1) * state.mods.speed * specSpeed;
    if (p.attackTimer <= 0) {
      p.vx = mx * PLAYER_SPEED * speedMul;
      p.vy = air ? 0 : my * PLAYER_DEPTH_SPEED * specSpeed;
      if (mx !== 0) p.facing = mx > 0 ? 1 : -1;
      moving = !air && (mx !== 0 || my !== 0);
    }
    consumePlayerAction(state);
  } else if (p.attackTimer <= 0 && grounded(p)) {
    p.vx *= Math.pow(0.05, dt);
  }

  p.x += p.vx * dt;
  p.y += p.vy * dt;
  updatePhysics(p, dt);
  clampFighter(p, state.stageWidth);
  const walkFrames = state.characterId === "jj" ? 8 : 4;
  updateFighterAnim(p, dt, moving && canAct(p) && grounded(p), walkFrames, PLAYER_WALK_FPS);
}

function updateEnemyAI(state: GameState, e: Fighter, dt: number) {
  if (e.dead) {
    e.deathTimer -= dt;
    updatePhysics(e, dt);
    updateFighterAnim(e, dt, false, 4, ENEMY_WALK_FPS);
    return;
  }
  if (e.hurtTimer > 0) e.hurtTimer -= dt;
  if (e.invulnTimer > 0) e.invulnTimer -= dt;
  if (e.flash > 0) e.flash -= dt;

  updateAttack(state, e, dt);

  const p = state.player;
  let moving = false;

  if (canAct(e) && !p.dead) {
    e.aiCooldown -= dt;
    const dx = p.x - e.x;
    const dy = p.y - e.y;
    e.facing = dx >= 0 ? 1 : -1;

    const distX = Math.abs(dx);
    const distY = Math.abs(dy);

    if (distX > 50 || distY > 22) {
      const nx = dx === 0 ? 0 : dx / distX;
      const ny = dy === 0 ? 0 : dy / Math.abs(dy);
      e.vx = nx * ENEMY_SPEED * (0.85 + Math.random() * 0.2);
      e.vy = ny * ENEMY_DEPTH_SPEED;
      moving = true;
    } else {
      e.vx = 0;
      e.vy = 0;
      if (e.aiCooldown <= 0) {
        startAttack(null, e, Math.random() < 0.4 ? "kick" : "punch");
        e.aiCooldown = 0.7 + Math.random() * 0.9;
      }
    }
  } else if (e.attackTimer <= 0) {
    e.vx *= Math.pow(0.05, dt);
  }

  e.x += e.vx * dt;
  e.y += e.vy * dt;
  updatePhysics(e, dt);
  clampFighter(e, state.stageWidth);
  updateFighterAnim(e, dt, moving && canAct(e), 4, ENEMY_WALK_FPS);
}

function updateSpawns(state: GameState, dt: number) {
  if (state.spawnQueue <= 0) return;
  state.spawnTimer -= dt;
  if (state.spawnTimer > 0) return;
  state.spawnTimer = 0.55 + Math.random() * 0.35;
  state.spawnQueue -= 1;

  const side = Math.random() < 0.5 ? -1 : 1;
  const cam = state.cameraX;
  const x =
    side < 0
      ? cam - 40 + Math.random() * 30
      : cam + VIEW_W + 20 + Math.random() * 40;
  const y = LANE_TOP + 30 + Math.random() * (LANE_BOTTOM - LANE_TOP - 60);

  const typeIndex = (state.waveEnemiesLeft + state.spawnQueue + state.wave) % ENEMY_TYPES.length;
  const type = ENEMY_TYPES[typeIndex]!;
  state.enemies.push(
    makeEnemy(Math.max(80, Math.min(state.stageWidth - 80, x)), y, state.wave, type),
  );
}

function updateBullets(state: GameState, dt: number) {
  if (!state.bullets.length) return;
  for (const b of state.bullets) {
    b.life -= dt;
    b.x += b.vx * dt;
    for (const target of state.enemies) {
      if (target.dead || b.hitIds.includes(target.id)) continue;
      if (Math.abs(b.y - target.y) > 34) continue;
      if (Math.abs(b.z - (target.z + target.bodyH * 0.4)) > 50) continue;
      const bb = bodyBox(target);
      if (b.x < bb.x - 4 || b.x > bb.x + bb.w + 4) continue;
      b.hitIds.push(target.id);
      b.life = 0;
      const prev = state.player.attackKind;
      state.player.attackKind = "gun";
      applyHit(state, state.player, target, b.damage, 260, "gun");
      state.player.attackKind = prev;
      break;
    }
  }
  state.bullets = state.bullets.filter((b) => b.life > 0 && b.x > -40 && b.x < state.stageWidth + 40);
}

function updateParticles(state: GameState, dt: number) {
  for (const p of state.particles) {
    p.life -= dt;
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    if (p.kind === "wave" && p.radius != null) {
      p.radius += 280 * dt;
    }
    if (p.kind === "note") {
      p.vy += 120 * dt;
    }
    if (p.kind === "smoke") {
      p.vx *= Math.pow(0.9, dt * 60);
      if (p.radius != null) p.radius += 8 * dt;
    }
    p.frame = Math.min(3, Math.floor((1 - p.life / p.maxLife) * 4));
  }
  state.particles = state.particles.filter((p) => p.life > 0);

  for (const f of state.floats) {
    f.life -= dt;
    f.y -= 40 * dt;
  }
  state.floats = state.floats.filter((f) => f.life > 0);

  if (state.riffPulseLife > 0) {
    state.riffPulseLife -= dt;
    if (state.riffPulseLife <= 0) state.riffPulse = 0;
  }

  if (state.speechBubble) {
    state.speechBubble.life -= dt;
    if (state.speechBubble.life <= 0) state.speechBubble = null;
  }
}

export function updateGame(state: GameState, dt: number) {
  const capped = Math.min(dt, 0.05);
  state.elapsed += capped;

  if (state.phase === "title" || state.phase === "paused" || state.phase === "gameover") {
    return;
  }

  // Victory still animates the smoke break idle
  if (state.phase === "victory") {
    if (state.messageTimer > 0 && state.messageTimer < 98) state.messageTimer -= capped;
    updateSmokeBreak(state, capped);
    updateParticles(state, capped);
    return;
  }

  if (state.hitStop > 0) {
    state.hitStop -= capped;
    return;
  }

  if (state.messageTimer > 0) state.messageTimer -= capped;
  if (state.shake > 0) state.shake = Math.max(0, state.shake - capped * 28);

  if (state.phase === "waveClear") {
    updateSmokeBreak(state, capped);
    // fade remaining corpses
    for (const e of state.enemies) {
      if (e.dead) e.deathTimer -= capped;
    }
    state.enemies = state.enemies.filter((e) => !(e.dead && e.deathTimer <= 0));
    updateParticles(state, capped);
    const target = state.player.x - VIEW_W * 0.38;
    state.cameraX += (target - state.cameraX) * Math.min(1, capped * 4);
    state.cameraX = Math.max(0, Math.min(state.stageWidth - VIEW_W, state.cameraX));
  } else {
    updatePlayer(state, capped);
    for (const e of state.enemies) updateEnemyAI(state, e, capped);
    state.enemies = state.enemies.filter((e) => !(e.dead && e.deathTimer <= 0));

    updateSpawns(state, capped);
    updateBullets(state, capped);
    updateParticles(state, capped);

    const target = state.player.x - VIEW_W * 0.38;
    state.cameraX += (target - state.cameraX) * Math.min(1, capped * 6);
    state.cameraX = Math.max(0, Math.min(state.stageWidth - VIEW_W, state.cameraX));
  }

  if (
    state.phase === "playing" &&
    state.spawnQueue <= 0 &&
    state.enemies.length === 0 &&
    state.waveEnemiesLeft <= 0
  ) {
    if (state.wave >= state.maxWaves && state.mode === "story") {
      state.phase = "victory";
      beginSmokeBreak(state, "STREET CLEARED", 99);
      sfx.victory();
    } else {
      state.phase = "waveClear";
      state.sessionWavesCleared += 1;
      beginSmokeBreak(state, "WAVE CLEAR — SMOKE BREAK", WAVE_CLEAR_DURATION);
      sfx.waveClear();
    }
  }

  if (state.phase === "waveClear" && state.messageTimer <= 0) {
    // After clearing wave 3 she gets a gun for the rest of the run
    if (state.wave === 3 && !state.hasGun) {
      state.hasGun = true;
      state.message = "GUN UNLOCKED — PRESS F TO FIRE";
      state.messageTimer = 2.0;
      state.player.anim = "idle";
      state.player.animTime = 0;
      state.player.animFrame = 0;
      sfx.uiConfirm();
      return;
    }
    state.player.anim = "idle";
    state.player.animTime = 0;
    state.player.animFrame = 0;
    state.phase = "playing";
    beginWave(state, state.wave + 1);
  }
}

function enemySheet(type: EnemyType | undefined, anim: "idle" | "walk" | "attack", assets: AssetMap) {
  const t = type ?? "biz";
  const key = `${t}${anim.charAt(0).toUpperCase()}${anim.slice(1)}` as SheetKey;
  return assets[key] ?? assets.bizIdle;
}

function sheetFor(f: Fighter, assets: AssetMap, characterId?: string) {
  if (f.kind === "player") {
    if (characterId === "andrew") {
      if (f.anim === "attack") {
        if (f.attackKind === "kick") return assets.andrewKick;
        return assets.andrewAttack;
      }
      if (f.anim === "hurt" || f.dead) return assets.andrewHurt;
      if (f.anim === "walk") return assets.andrewWalk;
      return assets.andrewIdle;
    }
    if (characterId === "han") {
      if (f.anim === "attack") {
        if (f.attackKind === "kick") return assets.hanKick;
        return assets.hanAttack;
      }
      if (f.anim === "hurt" || f.dead) return assets.hanHurt;
      if (f.anim === "walk") return assets.hanWalk;
      return assets.hanIdle;
    }
    if (f.anim === "attack") {
      if (f.attackKind === "special") return assets.jjSpecial;
      if (f.attackKind === "kick") return assets.jjKick;
      return assets.jjAttack;
    }
    if (f.anim === "hurt" || f.dead) return assets.jjHurt;
    if (f.anim === "jump") return assets.jjJump;
    if (f.anim === "smoke" || f.anim === "victory") return assets.jjSmoke;
    if (f.anim === "walk") return assets.jjWalk;
    return assets.jjIdle;
  }
  if (f.anim === "attack") return enemySheet(f.enemyType, "attack", assets);
  if (f.anim === "walk") return enemySheet(f.enemyType, "walk", assets);
  return enemySheet(f.enemyType, "idle", assets);
}

function walkBob(f: Fighter): number {
  if (f.anim !== "walk" || f.kind !== "player") return 0;
  const phase = f.animFrame % 8;
  if (phase === 1 || phase === 5) return 3;
  if (phase === 0 || phase === 4) return 1;
  if (phase === 3 || phase === 7) return -2;
  return 0;
}

function drawFighter(
  ctx: CanvasRenderingContext2D,
  f: Fighter,
  assets: AssetMap,
  camX: number,
  characterId?: string,
) {
  const sheet = sheetFor(f, assets, characterId);
  if (!sheet?.img || !sheet.frameW || !sheet.frameH) return;
  // Slightly larger while shredding so the guitar reads
  const scaleBoost = f.kind === "player" && f.attackKind === "special" ? 1.15 : 1;
  const drawH = f.bodyH * f.scale * 0.95 * scaleBoost;
  const drawW = drawH * (sheet.frameW / sheet.frameH);
  const bob = walkBob(f);
  const dx = f.x - camX - drawW / 2;
  const dy = f.y - drawH - f.z + bob;

  const shadowScale = Math.max(0.35, 1 - f.z / 220);
  ctx.save();
  ctx.fillStyle = `rgba(0,0,0,${0.35 * shadowScale})`;
  ctx.beginPath();
  ctx.ellipse(f.x - camX, f.y - 4, drawW * 0.28 * shadowScale, 8 * shadowScale, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();

  // Neon stage light while riffing so black outfit stays readable
  if (f.kind === "player" && f.attackKind === "special") {
    const g = ctx.createRadialGradient(
      f.x - camX,
      f.y - drawH * 0.45,
      8,
      f.x - camX,
      f.y - drawH * 0.45,
      drawW * 0.85,
    );
    g.addColorStop(0, "rgba(255,45,138,0.45)");
    g.addColorStop(0.55, "rgba(45,226,230,0.18)");
    g.addColorStop(1, "rgba(255,45,138,0)");
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.ellipse(f.x - camX, f.y - drawH * 0.4, drawW * 0.7, drawH * 0.55, 0, 0, Math.PI * 2);
    ctx.fill();
  }

  if (f.dead) ctx.globalAlpha = Math.max(0, f.deathTimer / 0.9);
  if (f.invulnTimer > 0 && Math.floor(f.invulnTimer * 20) % 2 === 0 && f.kind === "player" && f.attackKind !== "special") {
    ctx.globalAlpha = 0.55;
  }
  if (f.flash > 0) {
    ctx.filter = "brightness(2.2)";
  } else if (f.kind === "player" && f.hue) {
    ctx.filter = `hue-rotate(${f.hue}deg)`;
  }

  const flip = f.facing === -1;
  drawFrame(ctx, sheet, f.animFrame, dx, dy, drawW, drawH, flip);

  ctx.filter = "none";
  ctx.globalAlpha = 1;

  // Pistol holster / aim overlay (player only, after wave 3 unlock — drawn by caller via flag on state)
  // (see drawPlayerGun)

  if (f.kind === "enemy" && !f.dead && f.hp < f.maxHp) {
    const bw = 40;
    const bx = f.x - camX - bw / 2;
    const by = dy - 10;
    ctx.fillStyle = "rgba(0,0,0,0.55)";
    ctx.fillRect(bx - 1, by - 1, bw + 2, 6);
    ctx.fillStyle = "#ff2d8a";
    ctx.fillRect(bx, by, bw * (f.hp / f.maxHp), 4);
  }
}

/** Pixel pistol on JJ when she has the gun */
function drawPlayerGun(
  ctx: CanvasRenderingContext2D,
  f: Fighter,
  camX: number,
  aiming: boolean,
) {
  const face = f.facing;
  const hipX = f.x - camX + face * (aiming ? 22 : 10);
  const hipY = f.y - f.bodyH * f.scale * (aiming ? 0.52 : 0.42) - f.z;
  ctx.save();
  ctx.translate(hipX, hipY);
  ctx.scale(face, 1);
  // grip
  ctx.fillStyle = "#1a1210";
  ctx.fillRect(-4, 0, 7, 12);
  // slide / barrel
  ctx.fillStyle = aiming ? "#2a2a30" : "#3a3a42";
  ctx.fillRect(0, -4, aiming ? 28 : 18, 7);
  ctx.fillStyle = "#111";
  ctx.fillRect(aiming ? 22 : 14, -2, aiming ? 8 : 5, 3);
  // accent
  ctx.fillStyle = "#ff2d8a";
  ctx.fillRect(2, -4, 3, 7);
  ctx.restore();
}

function drawParallax(ctx: CanvasRenderingContext2D, assets: AssetMap, camX: number) {
  const sky = assets.sky.img;
  ctx.drawImage(sky, 0, 0, VIEW_W, VIEW_H);

  const far = assets.farBg.img;
  const farOff = (camX * 0.12) % VIEW_W;
  for (let i = -1; i <= 1; i++) {
    ctx.drawImage(far, -farOff + i * VIEW_W, 40, VIEW_W, VIEW_H * 0.72);
  }

  const mid = assets.midBg.img;
  const midOff = (camX * 0.4) % VIEW_W;
  const srcH = mid.naturalHeight * 0.62;
  const dstH = LANE_TOP + 10;
  for (let i = -1; i <= 1; i++) {
    ctx.drawImage(
      mid,
      0,
      0,
      mid.naturalWidth,
      srcH,
      -midOff + i * VIEW_W,
      0,
      VIEW_W,
      dstH,
    );
  }

  const beltTop = LANE_TOP - 8;
  const g = ctx.createLinearGradient(0, beltTop, 0, VIEW_H);
  g.addColorStop(0, "rgba(22,16,36,0.35)");
  g.addColorStop(0.2, "rgba(14,10,24,0.92)");
  g.addColorStop(1, "rgba(8,4,14,1)");
  ctx.fillStyle = g;
  ctx.fillRect(0, beltTop, VIEW_W, VIEW_H - beltTop);

  ctx.strokeStyle = "rgba(255,45,138,0.22)";
  ctx.lineWidth = 2;
  ctx.setLineDash([16, 20]);
  const lineY = (LANE_TOP + LANE_BOTTOM) / 2 + 18;
  const lineOff = (camX * 0.85) % 36;
  ctx.beginPath();
  ctx.moveTo(-lineOff, lineY);
  ctx.lineTo(VIEW_W + 40, lineY);
  ctx.stroke();
  ctx.setLineDash([]);

  ctx.fillStyle = "rgba(45,226,230,0.12)";
  ctx.fillRect(0, LANE_TOP - 6, VIEW_W, 3);
  ctx.fillStyle = "rgba(255,45,138,0.1)";
  ctx.fillRect(0, LANE_BOTTOM + 8, VIEW_W, 2);
}

function drawHud(ctx: CanvasRenderingContext2D, state: GameState) {
  const p = state.player;

  ctx.fillStyle = "rgba(10,6,18,0.72)";
  roundRect(ctx, 16, 14, 260, 58, 10);
  ctx.fill();
  ctx.strokeStyle = "rgba(255,45,138,0.45)";
  ctx.lineWidth = 2;
  roundRect(ctx, 16, 14, 260, 58, 10);
  ctx.stroke();

  ctx.fillStyle = "#f4eef8";
  ctx.font = "bold 14px Segoe UI, sans-serif";
  ctx.fillText("JJ", 28, 34);

  ctx.fillStyle = "rgba(0,0,0,0.45)";
  roundRect(ctx, 28, 42, 200, 14, 6);
  ctx.fill();
  const hpPct = Math.max(0, p.hp / p.maxHp);
  const hpGrad = ctx.createLinearGradient(28, 0, 228, 0);
  hpGrad.addColorStop(0, "#ff2d8a");
  hpGrad.addColorStop(1, "#ff6bb5");
  ctx.fillStyle = hpGrad;
  roundRect(ctx, 28, 42, 200 * hpPct, 14, 6);
  ctx.fill();

  ctx.fillStyle = "rgba(10,6,18,0.72)";
  roundRect(ctx, 16, 78, 200, 18, 8);
  ctx.fill();
  ctx.fillStyle = "rgba(0,0,0,0.4)";
  roundRect(ctx, 22, 82, 188, 10, 5);
  ctx.fill();
  const sp = state.specialMeter / 100;
  ctx.fillStyle = sp >= 0.4 ? "#2de2e6" : "rgba(45,226,230,0.45)";
  roundRect(ctx, 22, 82, 188 * sp, 10, 5);
  ctx.fill();
  ctx.fillStyle = "#a89bb8";
  ctx.font = "10px Segoe UI, sans-serif";
  ctx.fillText("RIFF SPECIAL (L)", 28, 110);

  if (state.hasGun) {
    ctx.fillStyle = "rgba(10,6,18,0.78)";
    roundRect(ctx, 16, 118, 150, 22, 8);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,229,102,0.55)";
    ctx.lineWidth = 1.5;
    roundRect(ctx, 16, 118, 150, 22, 8);
    ctx.stroke();
    ctx.fillStyle = "#ffe566";
    ctx.font = "bold 11px Segoe UI, sans-serif";
    ctx.fillText("GUN READY  (F)", 28, 133);
  }

  ctx.textAlign = "right";
  ctx.fillStyle = "#f4eef8";
  ctx.font = "bold 18px Segoe UI, sans-serif";
  ctx.fillText(`${state.score}`, VIEW_W - 20, 34);
  ctx.fillStyle = "#a89bb8";
  ctx.font = "12px Segoe UI, sans-serif";
  ctx.fillText(`WAVE ${state.wave}/${state.maxWaves}`, VIEW_W - 20, 52);
  ctx.textAlign = "left";

  if (p.combo > 1) {
    ctx.fillStyle = "#ffd56a";
    ctx.font = "bold 22px Segoe UI, sans-serif";
    ctx.fillText(`${p.combo} HIT COMBO`, 16, 140);
  }

  if (state.messageTimer > 0 && state.message) {
    ctx.save();
    ctx.globalAlpha = Math.min(1, state.messageTimer);
    ctx.textAlign = "center";
    ctx.fillStyle = "#ff2d8a";
    ctx.font = "bold 36px Segoe UI, sans-serif";
    ctx.shadowColor = "rgba(0,0,0,0.8)";
    ctx.shadowBlur = 12;
    ctx.fillText(state.message, VIEW_W / 2, VIEW_H * 0.28);
    ctx.restore();
  }
}

function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
) {
  const rr = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + rr, y);
  ctx.arcTo(x + w, y, x + w, y + h, rr);
  ctx.arcTo(x + w, y + h, x, y + h, rr);
  ctx.arcTo(x, y + h, x, y, rr);
  ctx.arcTo(x, y, x + w, y, rr);
  ctx.closePath();
}


function wrapSloganLines(text: string, maxChars = 16): string[] {
  const words = text.split(" ");
  const lines: string[] = [];
  let cur = "";
  for (const w of words) {
    const next = cur ? `${cur} ${w}` : w;
    if (next.length > maxChars && cur) {
      lines.push(cur);
      cur = w;
    } else {
      cur = next;
    }
  }
  if (cur) lines.push(cur);
  return lines;
}

function drawSpeechBubble(
  ctx: CanvasRenderingContext2D,
  state: GameState,
  camX: number,
) {
  const b = state.speechBubble;
  if (!b) return;
  const p = state.player;
  const t = 1 - b.life / b.maxLife;
  // Pop-in scale then hold, slight fade out at end
  let scale = 1;
  let alpha = 1;
  if (t < 0.12) scale = 0.4 + (t / 0.12) * 0.7;
  else if (t < 0.2) scale = 1.1 - ((t - 0.12) / 0.08) * 0.1;
  if (b.life < 0.2) alpha = Math.max(0, b.life / 0.2);

  const lines = wrapSloganLines(b.text || "FUCK YEAH!", b.text.length > 28 ? 22 : 18);
  if (!lines.length) return;
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.font = "bold 13px Segoe UI, sans-serif";
  let maxW = 40;
  for (const line of lines) {
    maxW = Math.max(maxW, ctx.measureText(line).width);
  }
  const padX = 12;
  const padY = 8;
  const lineH = 16;
  const bw = maxW + padX * 2;
  const bh = lines.length * lineH + padY * 2;
  const headY = p.y - p.bodyH * p.scale * 0.95 - p.z - 18;
  const cx = p.x - camX;
  const bx = cx - bw / 2;
  const by = headY - bh - 18;

  ctx.translate(cx, by + bh);
  ctx.scale(scale, scale);
  ctx.translate(-cx, -(by + bh));

  // Bubble body
  ctx.fillStyle = "#fff8fc";
  ctx.strokeStyle = "#1a0a14";
  ctx.lineWidth = 2.5;
  roundRect(ctx, bx, by, bw, bh, 10);
  ctx.fill();
  ctx.stroke();

  // Tail pointing down to JJ
  const tailX = cx + (p.facing === 1 ? -6 : 6);
  const tailTop = by + bh - 1;
  ctx.beginPath();
  ctx.moveTo(tailX - 8, tailTop);
  ctx.lineTo(tailX + 8, tailTop);
  ctx.lineTo(tailX + (p.facing === 1 ? 4 : -4), tailTop + 14);
  ctx.closePath();
  ctx.fillStyle = "#fff8fc";
  ctx.fill();
  ctx.strokeStyle = "#1a0a14";
  ctx.beginPath();
  ctx.moveTo(tailX - 8, tailTop);
  ctx.lineTo(tailX + (p.facing === 1 ? 4 : -4), tailTop + 14);
  ctx.lineTo(tailX + 8, tailTop);
  ctx.stroke();

  // Slogan text
  ctx.fillStyle = "#1a0a14";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  lines.forEach((line, i) => {
    ctx.fillText(line, cx, by + padY + lineH * i + lineH / 2);
  });
  ctx.textAlign = "left";
  ctx.textBaseline = "alphabetic";
  ctx.restore();
}

export function renderGame(
  ctx: CanvasRenderingContext2D,
  state: GameState,
  assets: AssetMap,
) {
  const shakeX = state.shake > 0 ? (Math.random() - 0.5) * state.shake * 2 : 0;
  const shakeY = state.shake > 0 ? (Math.random() - 0.5) * state.shake * 2 : 0;

  ctx.save();
  ctx.translate(shakeX, shakeY);

  drawParallax(ctx, assets, state.cameraX);

  const fighters: Fighter[] = [state.player, ...state.enemies].filter(Boolean);
  fighters.sort((a, b) => a.y - b.y || a.z - b.z);
  for (const f of fighters) drawFighter(ctx, f, assets, state.cameraX, state.characterId);
  if (state.hasGun && !state.player.dead) {
    drawPlayerGun(
      ctx,
      state.player,
      state.cameraX,
      state.player.attackKind === "gun" && state.player.attackTimer > 0,
    );
  }

  drawSpeechBubble(ctx, state, state.cameraX);

  for (const p of state.particles) {
    const alpha = Math.max(0, p.life / p.maxLife);
    if (p.kind === "impact") {
      const size = 48;
      drawFrame(
        ctx,
        assets.fxImpact,
        p.frame,
        p.x - state.cameraX - size / 2,
        p.y - size / 2,
        size,
        size,
      );
    } else if (p.kind === "wave") {
      const r = p.radius ?? 40;
      ctx.save();
      ctx.globalAlpha = alpha * 0.85;
      ctx.strokeStyle = p.color ?? "#ff2d8a";
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.ellipse(p.x - state.cameraX, p.y, r, r * 0.38, 0, 0, Math.PI * 2);
      ctx.stroke();
      ctx.lineWidth = 2;
      ctx.globalAlpha = alpha * 0.45;
      ctx.beginPath();
      ctx.ellipse(p.x - state.cameraX, p.y, r * 0.82, r * 0.3, 0, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    } else if (p.kind === "note") {
      ctx.save();
      ctx.globalAlpha = alpha;
      ctx.fillStyle = p.color ?? "#ff2d8a";
      ctx.font = "bold 18px Segoe UI, sans-serif";
      ctx.fillText(p.frame % 2 === 0 ? "♪" : "♫", p.x - state.cameraX, p.y);
      ctx.restore();
    } else if (p.kind === "smoke") {
      const r = (p.radius ?? 6) * (0.6 + (1 - alpha) * 1.4);
      ctx.save();
      ctx.globalAlpha = alpha * 0.5;
      ctx.fillStyle = "rgba(200,200,210,0.9)";
      ctx.beginPath();
      ctx.ellipse(p.x - state.cameraX, p.y, r, r * 0.75, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    } else if (p.kind === "muzzle") {
      const r = (p.radius ?? 12) * (0.5 + alpha);
      ctx.save();
      ctx.globalAlpha = alpha;
      ctx.fillStyle = "#fff4a0";
      ctx.beginPath();
      ctx.arc(p.x - state.cameraX, p.y, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#ff8800";
      ctx.beginPath();
      ctx.arc(p.x - state.cameraX, p.y, r * 0.45, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    } else {
      ctx.fillStyle = `rgba(255,213,106,${alpha})`;
      ctx.fillRect(p.x - state.cameraX - 2, p.y - 2, 4, 4);
    }
  }

  if (state.riffPulseLife > 0 && state.riffPulse > 0 && state.player.attackKind === "special") {
    const pl = state.player;
    const a = Math.min(1, state.riffPulseLife * 4) * 0.35;
    ctx.save();
    ctx.globalAlpha = a;
    ctx.strokeStyle = "#ff2d8a";
    ctx.lineWidth = 3;
    ctx.setLineDash([8, 10]);
    ctx.beginPath();
    ctx.ellipse(
      pl.x - state.cameraX,
      pl.y - 8,
      state.riffPulse,
      state.riffPulse * 0.42,
      0,
      0,
      Math.PI * 2,
    );
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.restore();
  }

  // Bullets
  for (const b of state.bullets) {
    const bx = b.x - state.cameraX;
    const by = b.y - b.z - 8;
    ctx.save();
    ctx.fillStyle = "#fff6a8";
    ctx.shadowColor = "#ffaa00";
    ctx.shadowBlur = 8;
    ctx.fillRect(bx - 6, by - 2, 12, 4);
    ctx.fillStyle = "#ffcc33";
    ctx.fillRect(bx - (b.facing > 0 ? 10 : -2), by - 1, 8, 2);
    ctx.restore();
  }

  for (const f of state.floats) {
    ctx.globalAlpha = Math.max(0, f.life / 0.7);
    ctx.fillStyle = f.color;
    ctx.font = "bold 16px Segoe UI, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(f.text, f.x - state.cameraX, f.y);
    ctx.globalAlpha = 1;
  }

  ctx.restore();

  if (state.phase !== "title") {
    drawHud(ctx, state);
  }
}

export function setKey(state: GameState, code: string, down: boolean) {
  if (down) {
    state.keys.add(code);
    if (code === "KeyJ" || code === "KeyZ") queueAction(state, "punch");
    else if (code === "KeyK" || code === "KeyX") queueAction(state, "kick");
    else if (code === "KeyL" || code === "KeyC") queueAction(state, "special");
    else if (code === "KeyF" || code === "KeyU" || code === "KeyG") queueAction(state, "gun");
    else if (code === "Space" || code === "ShiftLeft" || code === "ShiftRight") {
      queueJump(state);
    }
  } else {
    state.keys.delete(code);
  }
}

export type { GamePhase };
