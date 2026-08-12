import { sfx } from "./audio";
import {
  LANE_BOTTOM,
  LANE_TOP,
  STAGE_WIDTH,
  STAGES,
  VIEW_W,
  type AttackKind,
  type EnemyType,
  type Fighter,
  type GameState,
  type StageId,
} from "./types";

const PLAYER_SPEED = 190;
const PLAYER_DEPTH = 120;
const ENEMY_SPEED = 95;
const ENEMY_DEPTH = 70;
const JUMP_VEL = 520;
const GRAVITY = 1450;
const AIR_CONTROL = 0.72;
const HURT_DUR = 0.35;
const INVULN = 0.55;
const COMBO_WIN = 1.1;

const ATTACK_DUR: Record<AttackKind, number> = { punch: 0.36, kick: 0.48, special: 0.95 };
const ATTACK_WIN: Record<AttackKind, [number, number]> = {
  punch: [0.12, 0.28],
  kick: [0.16, 0.38],
  special: [0.18, 0.82],
};
const ATTACK_RANGE: Record<AttackKind, number> = { punch: 62, kick: 78, special: 210 };
const ATTACK_DMG: Record<AttackKind, number> = { punch: 12, kick: 18, special: 22 };

const SLOGANS = [
  "FUCK YEAH!",
  "EAT SHIT BOOTLICKERS!",
  "NOT MY PRESIDENT!",
  "EAT THE RICH!",
  "NO GODS NO MASTERS!",
  "SMASH THE STATE!",
  "PUNKS NOT DEAD!",
  "RIFF OR DIE!",
];

const ENEMY_TYPES: EnemyType[] = ["biz", "maga", "goth"];

function stageForWave(wave: number): StageId {
  if (wave <= 2) return "downtown";
  if (wave === 3) return "opera-alley";
  if (wave === 4) return "geary-strip";
  if (wave === 5) return "train-yard";
  return "water-tower";
}

function makePlayer(id: number): Fighter {
  return {
    id,
    kind: "player",
    x: 220,
    y: 400,
    z: 0,
    zVel: 0,
    vx: 0,
    vy: 0,
    facing: 1,
    hp: 100,
    maxHp: 100,
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
    scale: 1.7,
    bodyW: 36,
    bodyH: 78,
  };
}

function makeEnemy(id: number, x: number, y: number, wave: number, type: EnemyType): Fighter {
  const hpMul = type === "biz" ? 1.1 : type === "maga" ? 1.05 : 0.95;
  return {
    id,
    kind: "enemy",
    enemyType: type,
    x,
    y,
    z: 0,
    zVel: 0,
    vx: 0,
    vy: 0,
    facing: -1,
    hp: Math.round((28 + wave * 8) * hpMul),
    maxHp: Math.round((28 + wave * 8) * hpMul),
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
    scoreValue: 100 + wave * 40 + (type === "biz" ? 20 : 0),
    scale: type === "goth" ? 1.4 : 1.5,
    bodyW: 40,
    bodyH: 78,
  };
}

function grounded(f: Fighter) {
  return f.z <= 0.5 && f.zVel <= 0;
}

function canAct(f: Fighter) {
  return !f.dead && f.hurtTimer <= 0 && f.attackTimer <= 0;
}

export class GameEngine {
  state: GameState;
  private nextId = 1;

  constructor(startStage?: StageId) {
    this.state = this.blank(startStage);
  }

  private blank(startStage?: StageId): GameState {
    return {
      phase: "playing",
      player: makePlayer(0),
      enemies: [],
      particles: [],
      floats: [],
      speech: null,
      cameraX: 0,
      score: 0,
      wave: 0,
      maxWaves: 5,
      spawnQueue: 0,
      spawnTimer: 0,
      shake: 0,
      hitStop: 0,
      message: "",
      messageTimer: 0,
      specialMeter: 0,
      keys: new Set(),
      touch: { left: false, right: false, up: false, down: false },
      actionQueue: [],
      jumpQueued: false,
      elapsed: 0,
      stageWidth: STAGE_WIDTH,
      stageId: startStage ?? "downtown",
    };
  }

  start(startStage?: StageId) {
    this.nextId = 1;
    this.state = this.blank(startStage);
    this.state.player = makePlayer(this.nextId++);
    this.state.stageId = startStage ?? "downtown";
    sfx.uiConfirm();
    this.beginWave(1);
  }

  togglePause() {
    if (this.state.phase === "playing") {
      this.state.phase = "paused";
      sfx.pause();
    } else if (this.state.phase === "paused") {
      this.state.phase = "playing";
      sfx.resume();
    }
  }

  setKey(code: string, down: boolean) {
    if (down) {
      this.state.keys.add(code);
      if (code === "punch") this.queueAction("punch");
      if (code === "kick") this.queueAction("kick");
      if (code === "special") this.queueAction("special");
      if (code === "jump") this.state.jumpQueued = true;
    } else {
      this.state.keys.delete(code);
    }
  }

  setTouch(partial: Partial<GameState["touch"]>) {
    Object.assign(this.state.touch, partial);
  }

  clearTouch() {
    this.state.touch = { left: false, right: false, up: false, down: false };
  }

  queueAction(kind: AttackKind) {
    if (this.state.phase !== "playing") return;
    this.state.actionQueue = [kind];
  }

  update(rawDt: number) {
    const dt = Math.min(Math.max(rawDt, 0), 0.05);
    this.state.elapsed += dt;
    const s = this.state;

    if (s.phase === "paused" || s.phase === "gameover") return;

    if (s.phase === "victory") {
      s.player.animTime += dt;
      if (s.player.animTime > 0.35) {
        s.player.animTime = 0;
        s.player.animFrame = (s.player.animFrame + 1) % 4;
      }
      this.tickFx(dt);
      return;
    }

    if (s.hitStop > 0) {
      s.hitStop -= dt;
      return;
    }

    if (s.messageTimer > 0) s.messageTimer -= dt;
    if (s.shake > 0) s.shake = Math.max(0, s.shake - dt * 28);
    if (s.speech) {
      s.speech.life -= dt;
      if (s.speech.life <= 0) s.speech = null;
    }

    if (s.phase === "waveClear") {
      this.updatePhysics(s.player, dt, true);
      this.updateAnim(s.player, dt, false, 8);
      s.enemies = s.enemies.filter((e) => !(e.dead && e.deathTimer <= 0));
      for (const e of s.enemies) {
        if (e.dead) e.deathTimer -= dt;
        this.updatePhysics(e, dt, false);
      }
      this.tickFx(dt);
      this.followCam(dt, 4);
    } else {
      this.updatePlayer(dt);
      const n = s.enemies.length;
      for (let i = 0; i < n; i++) this.updateEnemy(i, dt);
      s.enemies = s.enemies.filter((e) => !(e.dead && e.deathTimer <= 0));
      this.updateSpawns(dt);
      this.tickFx(dt);
      this.followCam(dt, 6);
    }

    if (s.phase === "playing" && s.spawnQueue <= 0 && s.enemies.length === 0) {
      if (s.wave >= s.maxWaves) {
        s.phase = "victory";
        s.message = "STREET CLEARED";
        s.messageTimer = 99;
        s.player.anim = "idle";
        sfx.victory();
      } else {
        s.phase = "waveClear";
        s.message = "WAVE CLEAR — SMOKE BREAK";
        s.messageTimer = 2.4;
        sfx.waveClear();
      }
    }

    if (s.phase === "waveClear" && s.messageTimer <= 0) {
      s.player.anim = "idle";
      s.phase = "playing";
      this.beginWave(s.wave + 1);
    }
  }

  private beginWave(wave: number) {
    const s = this.state;
    s.wave = wave;
    s.enemies = [];
    const count = 2 + wave;
    s.spawnQueue = count;
    s.spawnTimer = 0.35;
    s.stageId = stageForWave(wave);
    s.message = wave === s.maxWaves ? "FINAL WAVE" : `WAVE ${wave} — ${STAGES.find((st) => st.id === s.stageId)?.title ?? ""}`;
    s.messageTimer = 1.6;
    sfx.waveStart(wave);
  }

  private pressed(code: string) {
    return this.state.keys.has(code);
  }

  private moveAxis(): [number, number] {
    let mx = 0;
    let my = 0;
    if (this.pressed("left") || this.state.touch.left) mx -= 1;
    if (this.pressed("right") || this.state.touch.right) mx += 1;
    if (this.pressed("up") || this.state.touch.up) my -= 1;
    if (this.pressed("down") || this.state.touch.down) my += 1;
    if (mx && my) {
      const inv = 1 / Math.SQRT2;
      mx *= inv;
      my *= inv;
    }
    return [mx, my];
  }

  private followCam(dt: number, lag: number) {
    const target = this.state.player.x - VIEW_W * 0.38;
    this.state.cameraX += (target - this.state.cameraX) * Math.min(1, dt * lag);
    this.state.cameraX = Math.max(0, Math.min(STAGE_WIDTH - VIEW_W, this.state.cameraX));
  }

  private updatePhysics(f: Fighter, dt: number, isPlayer: boolean) {
    if (!grounded(f) || f.zVel > 0) {
      f.zVel -= GRAVITY * dt;
      f.z += f.zVel * dt;
      if (f.z <= 0) {
        f.z = 0;
        f.zVel = 0;
        if (isPlayer && f.attackTimer <= 0 && f.hurtTimer <= 0) sfx.land();
      }
    } else {
      f.z = 0;
      f.zVel = 0;
    }
  }

  private clamp(f: Fighter) {
    f.x = Math.max(60, Math.min(STAGE_WIDTH - 60, f.x));
    f.y = Math.max(LANE_TOP, Math.min(LANE_BOTTOM, f.y));
  }

  private updateAnim(f: Fighter, dt: number, moving: boolean, fps: number) {
    if (f.attackTimer > 0) return;
    if (f.hurtTimer > 0 || f.dead) {
      f.anim = f.dead ? "dead" : "hurt";
      f.animTime += dt;
      f.animFrame = Math.min(3, Math.floor(f.animTime / 0.08));
      return;
    }
    if (!grounded(f)) {
      f.anim = "jump";
      f.animFrame = 1;
      return;
    }
    if (moving) {
      f.anim = "walk";
      f.animTime += dt;
      f.animFrame = Math.floor(f.animTime * fps) % 4;
    } else {
      f.anim = "idle";
      f.animTime += dt;
      f.animFrame = Math.floor(f.animTime * 4) % 4;
    }
  }

  private startAttack(f: Fighter, kind: AttackKind, isPlayer: boolean) {
    f.attackKind = kind;
    f.attackTimer = ATTACK_DUR[kind];
    f.attackActive = false;
    f.attackHit = false;
    f.specialHitIds = [];
    f.anim = "attack";
    f.animTime = 0;
    f.animFrame = 0;
    if (kind === "special") {
      f.vx = 0;
      f.vy = 0;
      f.invulnTimer = Math.max(f.invulnTimer, ATTACK_DUR.special * 0.85);
    } else if (grounded(f)) {
      f.vy = 0;
      f.vx = f.facing * (kind === "kick" ? 220 : 140);
    }
    if (kind === "kick") sfx.kick();
    else if (kind === "special") sfx.special();
    else sfx.punch();
    if (isPlayer && kind === "special") {
      this.state.speech = {
        text: SLOGANS[Math.floor(Math.random() * SLOGANS.length)] ?? "FUCK YEAH!",
        life: 1.15,
        maxLife: 1.15,
      };
    }
  }

  private updatePlayer(dt: number) {
    const p = this.state.player;
    if (p.dead) {
      p.deathTimer -= dt;
      this.updatePhysics(p, dt, true);
      this.updateAnim(p, dt, false, 8);
      if (p.deathTimer <= 0) {
        if (this.state.phase !== "gameover") sfx.gameOver();
        this.state.phase = "gameover";
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

    this.updateAttack(p, dt, true);

    if (this.state.jumpQueued) {
      this.state.jumpQueued = false;
      this.tryJump(p);
    } else if (grounded(p) && this.pressed("jump")) {
      if (this.tryJump(p)) this.state.keys.delete("jump");
    }

    const air = !grounded(p);
    const [mx, my] = this.moveAxis();
    let moving = false;

    if (canAct(p) || (air && p.attackTimer <= 0 && p.hurtTimer <= 0)) {
      const mul = air ? AIR_CONTROL : 1;
      if (p.attackTimer <= 0) {
        p.vx = mx * PLAYER_SPEED * mul;
        p.vy = air ? 0 : my * PLAYER_DEPTH;
        if (mx !== 0) p.facing = mx > 0 ? 1 : -1;
        moving = !air && (mx !== 0 || my !== 0);
      }
      this.consumeAction();
    } else if (p.attackTimer <= 0 && grounded(p)) {
      p.vx *= Math.pow(0.05, dt);
    }

    p.x += p.vx * dt;
    p.y += p.vy * dt;
    this.updatePhysics(p, dt, true);
    this.clamp(p);
    this.updateAnim(p, dt, moving && canAct(p) && grounded(p), 12);
  }

  private consumeAction() {
    const p = this.state.player;
    if (!canAct(p) && p.attackTimer > 0) return;
    if (p.hurtTimer > 0 || p.dead) return;
    while (this.state.actionQueue.length) {
      const kind = this.state.actionQueue.shift();
      if (!kind) break;
      if (kind === "special") {
        if (this.state.specialMeter < 40 || !grounded(p)) continue;
        this.state.specialMeter -= 40;
      }
      this.startAttack(p, kind, true);
      return;
    }
    if (this.pressed("punch")) {
      this.startAttack(p, "punch", true);
      this.state.keys.delete("punch");
    } else if (this.pressed("kick")) {
      this.startAttack(p, "kick", true);
      this.state.keys.delete("kick");
    } else if (grounded(p) && this.pressed("special") && this.state.specialMeter >= 40) {
      this.state.specialMeter -= 40;
      this.startAttack(p, "special", true);
      this.state.keys.delete("special");
    }
  }

  private tryJump(f: Fighter) {
    if (!grounded(f) || f.dead || f.hurtTimer > 0) return false;
    f.zVel = JUMP_VEL;
    f.z = 1;
    f.anim = "jump";
    f.animFrame = 1;
    sfx.jump();
    return true;
  }

  private updateEnemy(i: number, dt: number) {
    const e = this.state.enemies[i];
    if (!e) return;
    if (e.dead) {
      e.deathTimer -= dt;
      this.updatePhysics(e, dt, false);
      this.updateAnim(e, dt, false, 8);
      return;
    }
    if (e.hurtTimer > 0) e.hurtTimer -= dt;
    if (e.invulnTimer > 0) e.invulnTimer -= dt;
    if (e.flash > 0) e.flash -= dt;

    this.updateAttack(e, dt, false);

    const p = this.state.player;
    let moving = false;
    if (canAct(e) && !p.dead) {
      e.aiCooldown -= dt;
      const dx = p.x - e.x;
      const dy = p.y - e.y;
      e.facing = dx >= 0 ? 1 : -1;
      const distX = Math.abs(dx);
      const distY = Math.abs(dy);
      if (distX > 50 || distY > 22) {
        e.vx = (dx === 0 ? 0 : dx / distX) * ENEMY_SPEED * (0.85 + Math.random() * 0.2);
        e.vy = (dy === 0 ? 0 : dy / Math.abs(dy)) * ENEMY_DEPTH;
        moving = true;
      } else {
        e.vx = 0;
        e.vy = 0;
        if (e.aiCooldown <= 0) {
          this.startAttack(e, Math.random() < 0.4 ? "kick" : "punch", false);
          e.aiCooldown = 0.7 + Math.random() * 0.9;
        }
      }
    } else if (e.attackTimer <= 0) {
      e.vx *= Math.pow(0.05, dt);
    }

    e.x += e.vx * dt;
    e.y += e.vy * dt;
    this.updatePhysics(e, dt, false);
    this.clamp(e);
    this.updateAnim(e, dt, moving && canAct(e), 8);
  }

  private updateAttack(f: Fighter, dt: number, isPlayer: boolean) {
    if (f.attackTimer <= 0 || !f.attackKind) return;
    const kind = f.attackKind;
    const total = ATTACK_DUR[kind];
    f.attackTimer -= dt;
    const t = 1 - f.attackTimer / total;
    f.animFrame = Math.min(3, Math.floor(t * 4));
    if (grounded(f) && kind !== "special") f.vx *= Math.pow(0.02, dt);
    if (kind === "special") {
      f.vx = 0;
      f.vy = 0;
    }
    const [a0, a1] = ATTACK_WIN[kind];
    f.attackActive = f.attackTimer > 0 && t >= a0 && t <= a1;
    if (f.attackActive) {
      if (kind === "special" && isPlayer) this.handleRiff(f);
      else if (!f.attackHit && kind !== "special") this.handleMelee(f, kind, isPlayer);
    }
    if (f.attackTimer <= 0) {
      f.attackKind = null;
      f.attackActive = false;
      f.attackHit = false;
    }
  }

  private handleMelee(atk: Fighter, kind: AttackKind, isPlayer: boolean) {
    const range = ATTACK_RANGE[kind];
    const dmg = ATTACK_DMG[kind];
    const targets = isPlayer ? this.state.enemies : [this.state.player];
    for (const tgt of targets) {
      if (tgt.dead || tgt.invulnTimer > 0) continue;
      if (Math.abs(tgt.y - atk.y) > 28) continue;
      const dx = tgt.x - atk.x;
      if (Math.sign(dx || 1) !== atk.facing && Math.abs(dx) > 16) continue;
      if (Math.abs(dx) > range) continue;
      this.applyHit(tgt, atk, dmg, kind, isPlayer);
      atk.attackHit = true;
      if (!isPlayer) break;
    }
  }

  private handleRiff(atk: Fighter) {
    for (const tgt of this.state.enemies) {
      if (tgt.dead || atk.specialHitIds.includes(tgt.id)) continue;
      if (Math.abs(tgt.y - atk.y) > 40) continue;
      const dx = tgt.x - atk.x;
      if (Math.abs(dx) > ATTACK_RANGE.special) continue;
      this.applyHit(tgt, atk, ATTACK_DMG.special, "special", true);
      atk.specialHitIds.push(tgt.id);
    }
  }

  private applyHit(tgt: Fighter, atk: Fighter, dmg: number, kind: AttackKind, fromPlayer: boolean) {
    tgt.hp -= dmg;
    tgt.hurtTimer = HURT_DUR;
    tgt.invulnTimer = INVULN;
    tgt.flash = 0.12;
    tgt.vx = atk.facing * (kind === "special" ? 340 : kind === "kick" ? 220 : 140);
    tgt.zVel = kind === "kick" || kind === "special" ? 180 : 80;
    tgt.z = Math.max(tgt.z, 4);
    tgt.anim = "hurt";
    tgt.animTime = 0;
    tgt.attackTimer = 0;
    this.state.shake = Math.min(12, this.state.shake + (kind === "special" ? 6 : 3));
    this.state.hitStop = kind === "special" ? 0.08 : 0.045;
    this.state.particles.push({
      x: tgt.x,
      y: tgt.y - tgt.bodyH * 0.5 - tgt.z,
      vx: atk.facing * 40,
      vy: -40,
      life: 0.28,
      maxLife: 0.28,
      frame: 0,
      kind: "impact",
    });
    this.state.floats.push({
      x: tgt.x,
      y: tgt.y - tgt.bodyH - tgt.z,
      text: `${dmg}`,
      life: 0.7,
      color: kind === "special" ? "#f4c84a" : "#ff2d8a",
    });
    sfx.hit(kind !== "punch");
    if (fromPlayer) {
      const p = this.state.player;
      p.combo += 1;
      p.comboTimer = COMBO_WIN;
      this.state.specialMeter = Math.min(100, this.state.specialMeter + (kind === "special" ? 0 : 8));
      this.state.score += dmg * 10 + p.combo * 5;
    } else {
      sfx.hurt();
    }
    if (tgt.hp <= 0) {
      tgt.hp = 0;
      tgt.dead = true;
      tgt.deathTimer = 0.9;
      tgt.anim = "dead";
      sfx.ko();
      if (fromPlayer) this.state.score += tgt.scoreValue;
    }
  }

  private updateSpawns(dt: number) {
    const s = this.state;
    if (s.spawnQueue <= 0) return;
    s.spawnTimer -= dt;
    if (s.spawnTimer > 0) return;
    s.spawnTimer = 0.7 + Math.random() * 0.5;
    s.spawnQueue -= 1;
    const side = Math.random() < 0.55 ? 1 : -1;
    const x = s.player.x + side * (220 + Math.random() * 180);
    const y = LANE_TOP + 20 + Math.random() * (LANE_BOTTOM - LANE_TOP - 40);
    const type = ENEMY_TYPES[Math.floor(Math.random() * ENEMY_TYPES.length)] ?? "biz";
    s.enemies.push(makeEnemy(this.nextId++, x, y, s.wave, type));
  }

  private tickFx(dt: number) {
    const s = this.state;
    for (const p of s.particles) {
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.frame = Math.min(3, Math.floor((1 - p.life / p.maxLife) * 4));
    }
    s.particles = s.particles.filter((p) => p.life > 0);
    for (const f of s.floats) {
      f.life -= dt;
      f.y -= 28 * dt;
    }
    s.floats = s.floats.filter((f) => f.life > 0);
  }
}
