import { sheetForEnemy, sheetForPlayer, type GameAssets, type SpriteAnim } from "./assets";
import { LANE_BOTTOM, LANE_TOP, VIEW_H, VIEW_W, type Fighter, type GameState } from "./types";

function drawSprite(
  ctx: CanvasRenderingContext2D,
  anim: SpriteAnim,
  frame: number,
  dest: { x: number; y: number; w: number; h: number },
  flipX: boolean,
) {
  const img = anim.frames[((frame % anim.frames.length) + anim.frames.length) % anim.frames.length];
  if (!img) return;
  ctx.save();
  ctx.imageSmoothingEnabled = false;
  if (flipX) {
    ctx.translate(dest.x + dest.w / 2, dest.y + dest.h / 2);
    ctx.scale(-1, 1);
    ctx.translate(-(dest.x + dest.w / 2), -(dest.y + dest.h / 2));
  }
  ctx.drawImage(img, dest.x, dest.y, dest.w, dest.h);
  ctx.restore();
}

function drawParallax(ctx: CanvasRenderingContext2D, assets: GameAssets, state: GameState) {
  const plates = assets.stages[state.stageId];
  if (plates?.sky) ctx.drawImage(plates.sky, 0, 0, VIEW_W, VIEW_H);
  else {
    ctx.fillStyle = "#0a0812";
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);
  }

  if (plates?.far) {
    const off = (state.cameraX * 0.12) % VIEW_W;
    for (let i = -1; i <= 1; i++) {
      ctx.drawImage(plates.far, -off + i * VIEW_W, 40, VIEW_W, VIEW_H * 0.72);
    }
  }
  if (plates?.mid) {
    const off = (state.cameraX * 0.4) % VIEW_W;
    for (let i = -1; i <= 1; i++) {
      ctx.drawImage(plates.mid, -off + i * VIEW_W, 0, VIEW_W, LANE_TOP + 10);
    }
  }

  const belt = ctx.createLinearGradient(0, LANE_TOP - 8, 0, VIEW_H);
  belt.addColorStop(0, "rgba(22, 16, 36, 0.35)");
  belt.addColorStop(0.2, "rgba(12, 8, 20, 0.92)");
  belt.addColorStop(1, "#07060c");
  ctx.fillStyle = belt;
  ctx.fillRect(0, LANE_TOP - 8, VIEW_W, VIEW_H - LANE_TOP + 8);

  ctx.save();
  ctx.strokeStyle = "rgba(255, 45, 138, 0.22)";
  ctx.lineWidth = 2;
  ctx.setLineDash([16, 20]);
  const lineY = (LANE_TOP + LANE_BOTTOM) / 2 + 18;
  const lineOff = (state.cameraX * 0.85) % 36;
  ctx.beginPath();
  ctx.moveTo(-lineOff, lineY);
  ctx.lineTo(VIEW_W + 40, lineY);
  ctx.stroke();
  ctx.restore();
}

function drawFighter(
  ctx: CanvasRenderingContext2D,
  f: Fighter,
  assets: GameAssets,
  camX: number,
) {
  const anim =
    f.kind === "player"
      ? sheetForPlayer(assets, f.anim, f.attackKind)
      : sheetForEnemy(assets, f.anim, f.enemyType);
  const boost = f.kind === "player" && f.attackKind === "special" ? 1.15 : 1;
  const drawH = f.bodyH * f.scale * 0.95 * boost;
  const drawW = drawH;
  const dest = {
    x: f.x - camX - drawW / 2,
    y: f.y - drawH - f.z,
    w: drawW,
    h: drawH,
  };

  ctx.save();
  ctx.fillStyle = "rgba(0,0,0,0.35)";
  ctx.beginPath();
  ctx.ellipse(f.x - camX, f.y + 6, drawW * 0.28, 8, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();

  if (f.flash > 0) ctx.filter = "brightness(2.2)";
  if (f.dead) ctx.globalAlpha = Math.max(0.15, f.deathTimer);
  drawSprite(ctx, anim, f.animFrame, dest, f.facing < 0);
  ctx.filter = "none";
  ctx.globalAlpha = 1;
}

function drawHud(ctx: CanvasRenderingContext2D, state: GameState) {
  const p = state.player;
  ctx.save();
  ctx.fillStyle = "rgba(7,6,12,0.72)";
  ctx.fillRect(16, 14, 240, 54);
  ctx.strokeStyle = "rgba(255,45,138,0.45)";
  ctx.strokeRect(16.5, 14.5, 239, 53);

  ctx.fillStyle = "#f6eef8";
  ctx.font = "bold 11px 'IBM Plex Sans', sans-serif";
  ctx.fillText("JJ", 26, 32);

  ctx.fillStyle = "#2a2036";
  ctx.fillRect(52, 22, 190, 10);
  ctx.fillStyle = "#ff2d8a";
  ctx.fillRect(52, 22, 190 * Math.max(0, p.hp / p.maxHp), 10);

  ctx.fillStyle = "#2a2036";
  ctx.fillRect(52, 36, 190, 8);
  ctx.fillStyle = "#3ee8e0";
  ctx.fillRect(52, 36, 190 * (state.specialMeter / 100), 8);

  ctx.fillStyle = "#9a8ca8";
  ctx.font = "10px 'IBM Plex Sans', sans-serif";
  ctx.fillText("HP", 26, 31);
  ctx.fillText("RIFF", 26, 44);

  ctx.textAlign = "right";
  ctx.fillStyle = "#f6eef8";
  ctx.font = "bold 13px 'IBM Plex Sans', sans-serif";
  ctx.fillText(`WAVE ${state.wave}/${state.maxWaves}`, VIEW_W - 20, 28);
  ctx.fillStyle = "#f4c84a";
  ctx.fillText(String(state.score).padStart(6, "0"), VIEW_W - 20, 48);
  if (p.combo > 1) {
    ctx.fillStyle = "#ff2d8a";
    ctx.fillText(`${p.combo} HIT`, VIEW_W - 20, 68);
  }
  ctx.restore();

  if (state.messageTimer > 0 && state.message) {
    ctx.save();
    ctx.textAlign = "center";
    ctx.fillStyle = "rgba(7,6,12,0.7)";
    ctx.fillRect(VIEW_W / 2 - 220, 86, 440, 36);
    ctx.fillStyle = "#ff2d8a";
    ctx.font = "700 16px 'IBM Plex Sans', sans-serif";
    ctx.fillText(state.message, VIEW_W / 2, 110);
    ctx.restore();
  }

  if (state.speech) {
    const alpha = Math.min(1, state.speech.life / 0.2, state.speech.maxLife ? 1 : 1);
    ctx.save();
    ctx.globalAlpha = Math.max(0.2, alpha);
    const bx = p.x - state.cameraX;
    const by = p.y - p.bodyH * p.scale - p.z - 18;
    ctx.fillStyle = "#f6eef8";
    ctx.font = "bold 12px 'IBM Plex Sans', sans-serif";
    const w = ctx.measureText(state.speech.text).width + 18;
    ctx.fillRect(bx - w / 2, by - 22, w, 22);
    ctx.fillStyle = "#07060c";
    ctx.textAlign = "center";
    ctx.fillText(state.speech.text, bx, by - 7);
    ctx.restore();
  }
}

export function renderFrame(
  ctx: CanvasRenderingContext2D,
  state: GameState,
  assets: GameAssets,
) {
  const sx = state.shake > 0 ? (Math.random() * 2 - 1) * state.shake : 0;
  const sy = state.shake > 0 ? (Math.random() * 2 - 1) * state.shake : 0;
  ctx.save();
  ctx.translate(sx, sy);
  ctx.imageSmoothingEnabled = false;

  drawParallax(ctx, assets, state);

  const fighters: Fighter[] = [state.player, ...state.enemies].sort((a, b) => a.y - b.y || a.z - b.z);
  for (const f of fighters) drawFighter(ctx, f, assets, state.cameraX);

  for (const p of state.particles) {
    const dest = { x: p.x - state.cameraX - 28, y: p.y - 28, w: 56, h: 56 };
    drawSprite(ctx, assets.impact, p.frame, dest, false);
  }

  ctx.font = "bold 14px 'IBM Plex Sans', sans-serif";
  ctx.textAlign = "center";
  for (const f of state.floats) {
    ctx.globalAlpha = Math.max(0, f.life / 0.7);
    ctx.fillStyle = f.color;
    ctx.fillText(f.text, f.x - state.cameraX, f.y);
  }
  ctx.globalAlpha = 1;

  ctx.restore();
  drawHud(ctx, state);
}
