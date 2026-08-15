import { useEffect, useRef, useState } from "react";
import type { AssetMap, LoadedSheet } from "./assets";
import { currentTrack, playTrack, playMenuTheme, sfx, stopTrack, TRACKS } from "./audio";
import {
  ACHIEVEMENTS,
  CHARACTERS,
  formatWhen,
  lastPlayedSlot,
  SHOP_ITEMS,
  STAGES,
  type CharacterId,
  type PlayMode,
  type Profile,
  type SaveSlot,
} from "./save";

export type MenuScreen =
  | "menu"
  | "settings"
  | "gallery"
  | "credits"
  | "load"
  | "achievements"
  | "records"
  | "shop"
  | "howto"
  | "support"
  | "story"
  | "endless"
  | "chars"
  | "stages"
  | "jukebox";

const NAV: { id: MenuScreen | "continue"; label: string; group: string }[] = [
  { id: "story", label: "Story Mode", group: "Play" },
  { id: "endless", label: "Endless", group: "Play" },
  { id: "continue", label: "Continue", group: "Play" },
  { id: "load", label: "Load Game", group: "Play" },
  { id: "chars", label: "Character Select", group: "Play" },
  { id: "stages", label: "World Map", group: "Play" },
  { id: "gallery", label: "Gallery", group: "Progress" },
  { id: "achievements", label: "Achievements", group: "Progress" },
  { id: "records", label: "Records", group: "Progress" },
  { id: "shop", label: "Shop", group: "City" },
  { id: "howto", label: "How to Play", group: "Help" },
  { id: "settings", label: "Options", group: "Help" },
  { id: "jukebox", label: "Soundtrack", group: "Help" },
  { id: "credits", label: "Credits", group: "Help" },
  { id: "support", label: "Support", group: "Help" },
];

const GALLERY: { label: string; sub: string; key: keyof AssetMap; unlock: string }[] = [
  { label: "JJ", sub: "Idle", key: "jjIdle", unlock: "jjIdle" },
  { label: "JJ", sub: "Walk", key: "jjWalk", unlock: "jjWalk" },
  { label: "JJ", sub: "Punch", key: "jjAttack", unlock: "jjAttack" },
  { label: "JJ", sub: "Kick", key: "jjKick", unlock: "jjKick" },
  { label: "JJ", sub: "Jump", key: "jjJump", unlock: "jjJump" },
  { label: "JJ", sub: "Riff", key: "jjSpecial", unlock: "jjSpecial" },
  { label: "JJ", sub: "Smoke", key: "jjSmoke", unlock: "jjSmoke" },
  { label: "Andrew", sub: "Punch", key: "andrewAttack", unlock: "andrewAttack" },
  { label: "Andrew", sub: "Kick", key: "andrewKick", unlock: "andrewKick" },
  { label: "Andrew", sub: "Hurt", key: "andrewHurt", unlock: "andrewHurt" },
  { label: "Han", sub: "Punch", key: "hanAttack", unlock: "hanAttack" },
  { label: "Han", sub: "Kick", key: "hanKick", unlock: "hanKick" },
  { label: "Han", sub: "Hurt", key: "hanHurt", unlock: "hanHurt" },
  { label: "Suit", sub: "White collar", key: "bizIdle", unlock: "biz" },
  { label: "Co-opter", sub: "MAGA", key: "magaIdle", unlock: "maga" },
  { label: "Goth", sub: "Man", key: "gothmIdle", unlock: "gothm" },
  { label: "Goth", sub: "Woman", key: "gothfIdle", unlock: "gothf" },
  { label: "Impact", sub: "FX", key: "fxImpact", unlock: "fx" },
];

export function MainMenu({
  screen,
  selected,
  muted,
  assets,
  profile,
  pendingChar,
  pendingMode,
  onSelect,
  onMove,
  onOpen,
  onBack,
  onToggleMute,
  onContinue,
  onStart,
  onLoadSlot,
  onBuy,
  onSetChar,
  onSetMode,
  onFeedback,
  onHoverChar,
}: {
  screen: MenuScreen;
  selected: number;
  muted: boolean;
  assets: AssetMap | null;
  profile: Profile;
  pendingChar: CharacterId;
  pendingMode: PlayMode;
  onSelect: (i: number) => void;
  onMove: (dir: -1 | 1) => void;
  onOpen: (s: MenuScreen) => void;
  onBack: () => void;
  onToggleMute: () => void;
  onContinue: () => void;
  onStart: (opts: { mode: PlayMode; characterId: CharacterId; startWave?: number; slotIndex?: number; slot?: SaveSlot | null }) => void;
  onLoadSlot: (i: number) => void;
  onBuy: (id: string) => void;
  onSetChar: (id: CharacterId) => void;
  onSetMode: (m: PlayMode) => void;
  onFeedback: (text: string) => void;
  onHoverChar?: (id: CharacterId | null) => void;
}) {
  const last = lastPlayedSlot(profile);
  const items = NAV;

  useEffect(() => {
    playMenuTheme();
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.repeat) return;
      if (screen !== "menu") {
        if (e.code === "Escape" || e.code === "Backspace") {
          e.preventDefault();
          onBack();
        }
        return;
      }
      if (e.code === "ArrowUp" || e.code === "KeyW") {
        e.preventDefault();
        onMove(-1);
      } else if (e.code === "ArrowDown" || e.code === "KeyS") {
        e.preventDefault();
        onMove(1);
      } else if (e.code === "Enter" || e.code === "Space") {
        e.preventDefault();
        const item = items[selected];
        if (!item) return;
        if (item.id === "continue") onContinue();
        else onOpen(item.id);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [screen, selected, items, onMove, onOpen, onBack, onContinue, onStart]);

  return (
    <div className="absolute inset-0 z-10 flex items-end justify-start overflow-hidden bg-transparent p-3 sm:items-stretch sm:p-5">
      <div className="flex min-h-0 w-full max-w-[16.5rem] flex-col sm:max-w-xs">
        <p className="text-[10px] font-semibold uppercase tracking-[0.28em] text-accent">Menu select</p>
        <p className="text-[10px] font-semibold uppercase tracking-[0.28em] text-accent">Night shift</p>
        <h2 className="text-2xl font-bold tracking-tight text-fg sm:text-3xl">JJ: Night Brawl</h2>
        <p className="mb-3 text-xs text-muted">
          {pendingMode === "endless" ? "Endless" : "Story"} · {CHARACTERS[pendingChar].name} · {profile.shop.cred} cred
        </p>

        <div className="min-h-0 flex-1 overflow-y-auto pr-1">
          {screen === "menu" && (
            <nav className="flex flex-col gap-3" aria-label="Main menu">
              {(["Play", "Progress", "City", "Help"] as const).map((group) => (
                <div key={group}>
                  <p className="mb-1 text-[10px] font-bold uppercase tracking-widest text-muted">{group}</p>
                  <div className="flex flex-col gap-1">
                    {items
                      .map((item, i) => ({ item, i }))
                      .filter(({ item }) => item.group === group)
                      .map(({ item, i }) => {
                        const active = i === selected;
                        const disabled = item.id === "continue" && !last;
                        return (
                          <button
                            key={item.id}
                            type="button"
                            disabled={disabled}
                            onMouseEnter={() => onSelect(i)}
                            onClick={() => {
                              if (disabled) return;
                              sfx.uiClick();
                              if (item.id === "continue") onContinue();
                              else onOpen(item.id);
                            }}
                            className={[
                              "flex min-h-10 items-center justify-between rounded-lg border px-3 text-left text-sm font-semibold transition",
                              disabled
                                ? "cursor-not-allowed border-border/50 bg-surface/40 text-muted"
                                : active
                                  ? "border-primary bg-primary text-primary-fg"
                                  : "border-border/70 bg-bg/55 text-fg backdrop-blur-sm hover:border-muted",
                            ].join(" ")}
                          >
                            <span>{item.label}</span>
                            {item.id === "continue" && last && (
                              <span className="text-[10px] font-medium opacity-80">{formatWhen(last.updatedAt)}</span>
                            )}
                          </button>
                        );
                      })}
                  </div>
                </div>
              ))}
            </nav>
          )}

          {screen === "settings" && (
            <Panel title="Options">
              <button
                type="button"
                onClick={onToggleMute}
                className="mb-3 flex min-h-11 w-full items-center justify-between rounded-lg border border-border bg-surface-2 px-3 text-sm font-semibold text-fg"
              >
                <span>Sound</span>
                <span className={muted ? "text-muted" : "text-accent"}>{muted ? "Off" : "On"}</span>
              </button>
              <p className="text-xs text-muted">Mute also toggles with M. Shake and juice stay on for the arcade feel.</p>
              <BackButton onClick={onBack} />
            </Panel>
          )}

          {screen === "howto" && (
            <Panel title="How to Play">
              <ul className="space-y-1.5 text-xs text-muted">
                <li>Move with WASD or arrows. Stay in your lane.</li>
                <li>Punch J/Z · Kick K/X · Jump Space · Riff L (meter) · Gun F</li>
                <li>Story is five districts. Endless does not stop.</li>
                <li>Clear waves, smoke, shop, and come back louder.</li>
                <li>Character Select is for Endless. Story is JJ's night.</li>
              </ul>
              <BackButton onClick={onBack} />
            </Panel>
          )}

          {screen === "credits" && (
            <Panel title="Credits">
              <p className="text-sm font-semibold text-fg">JJ: Night Brawl</p>
              <p className="mt-1 text-xs text-muted">Directed by Andrew M. Németh</p>
              <p className="mt-3 text-xs text-muted">
                A side-scrolling beat-em-up about suits and reactionaries trying to steal punk — and the one person who still means it.
              </p>
              <p className="mt-3 text-xs text-muted">Sprites, engine, and noise built in this project. No gods, no masters, no licensed soundtrack.</p>
              <BackButton onClick={onBack} />
            </Panel>
          )}

          {screen === "load" && (
            <Panel title="Load Game">
              <div className="flex flex-col gap-2">
                {profile.slots.map((slot, i) => (
                  <button
                    key={i}
                    type="button"
                    disabled={!slot}
                    onClick={() => slot && onLoadSlot(i)}
                    className="min-h-14 rounded-lg border border-border bg-surface-2 px-3 py-2 text-left disabled:opacity-40"
                  >
                    <div className="flex items-center justify-between text-sm font-semibold text-fg">
                      <span>Slot {i + 1}</span>
                      {slot && <span className="text-[10px] text-muted">{formatWhen(slot.updatedAt)}</span>}
                    </div>
                    <p className="text-[11px] text-muted">
                      {slot
                        ? `${slot.mode} · ${CHARACTERS[slot.characterId].name} · ${slot.stageName} · ${slot.score} pts`
                        : "Empty"}
                    </p>
                  </button>
                ))}
              </div>
              <BackButton onClick={onBack} />
            </Panel>
          )}

          {screen === "gallery" && (
            <Panel title="Gallery">
              <div className="grid grid-cols-3 gap-2 sm:grid-cols-4">
                {GALLERY.map((g) => {
                  const open =
                    profile.unlocks.gallery.includes(g.unlock) ||
                    g.unlock.startsWith("jj") ||
                    (g.unlock.startsWith("andrew") && profile.shop.ownedChars.includes("andrew")) ||
                    (g.unlock.startsWith("han") && profile.shop.ownedChars.includes("han"));
                  return (
                    <figure key={g.key} className="flex flex-col items-center rounded-lg border border-border bg-bg/80 p-2">
                      {assets && open ? (
                        <SpritePreview sheet={assets[g.key]} />
                      ) : (
                        <div className="flex h-16 w-16 items-center justify-center bg-surface-2 text-[10px] text-muted">
                          Locked
                        </div>
                      )}
                      <figcaption className="mt-1 text-center text-[10px] font-semibold text-fg">{g.label}</figcaption>
                      <span className="text-[10px] text-muted">{g.sub}</span>
                    </figure>
                  );
                })}
              </div>
              <BackButton onClick={onBack} />
            </Panel>
          )}

          {screen === "achievements" && (
            <Panel title="Achievements">
              <ul className="space-y-2">
                {ACHIEVEMENTS.map((a) => {
                  const got = Boolean(profile.achievements[a.id]);
                  return (
                    <li
                      key={a.id}
                      className={`rounded-lg border px-3 py-2 ${got ? "border-accent/40 bg-surface-2" : "border-border bg-bg/50"}`}
                    >
                      <p className={`text-sm font-semibold ${got ? "text-accent" : "text-muted"}`}>{a.name}</p>
                      <p className="text-[11px] text-muted">{a.desc}</p>
                    </li>
                  );
                })}
              </ul>
              <BackButton onClick={onBack} />
            </Panel>
          )}

          {screen === "records" && (
            <Panel title="Records">
              <dl className="grid grid-cols-2 gap-2 text-sm">
                <Stat label="High score" value={String(profile.records.highScore)} />
                <Stat label="Playtime" value={`${Math.floor(profile.records.playtimeSec / 60)}m`} />
                <Stat label="Foes down" value={String(profile.records.enemiesDefeated)} />
                <Stat label="Waves cleared" value={String(profile.records.wavesCleared)} />
                <Stat label="Story clears" value={String(profile.records.storyClears)} />
                <Stat label="Endless best" value={`W${profile.records.bestEndlessWave}`} />
              </dl>
              <BackButton onClick={onBack} />
            </Panel>
          )}

          {screen === "shop" && (
            <Panel title={`Shop · ${profile.shop.cred} cred`}>
              <div className="flex flex-col gap-2">
                {SHOP_ITEMS.map((item) => {
                  const lv = profile.shop.levels[item.id] ?? 0;
                  const sold = lv >= item.max;
                  const price = item.prices[Math.min(lv, item.prices.length - 1)] ?? 0;
                  const can = !sold && profile.shop.cred >= price;
                  return (
                    <div key={item.id} className="flex items-center justify-between gap-2 rounded-lg border border-border bg-surface-2 px-3 py-2">
                      <div>
                        <p className="text-sm font-semibold text-fg">{item.name}</p>
                        <p className="text-[11px] text-muted">
                          {item.blurb} · {sold ? "Sold out" : `Lv ${lv}/${item.max}`}
                        </p>
                      </div>
                      <button
                        type="button"
                        disabled={!can}
                        onClick={() => onBuy(item.id)}
                        className="min-h-10 shrink-0 rounded-md bg-primary px-3 text-xs font-bold text-primary-fg disabled:bg-surface disabled:text-muted"
                      >
                        {sold ? "—" : `${price}`}
                      </button>
                    </div>
                  );
                })}
              </div>
              <BackButton onClick={onBack} />
            </Panel>
          )}

          {screen === "story" && (
            <Panel title="Story Mode">
              <p className="mb-3 text-xs text-muted">
                Five districts. JJ only. Corporate America and the conservative movement try to hijack punk. You don't let them.
              </p>
              <button
                type="button"
                onClick={() => onStart({ mode: "story", characterId: "jj", startWave: 1, slotIndex: nextEmptyOrLast(profile) })}
                className="min-h-11 w-full rounded-lg bg-primary text-sm font-bold text-primary-fg"
              >
                New Game
              </button>
              <button
                type="button"
                onClick={() => onOpen("stages")}
                className="mt-2 min-h-11 w-full rounded-lg border border-border bg-surface-2 text-sm font-semibold text-fg"
              >
                World Map
              </button>
              <BackButton onClick={onBack} />
            </Panel>
          )}

          {screen === "endless" && (
            <Panel title="Endless">
              <p className="mb-3 text-xs text-muted">Waves do not stop. Pick a fighter. Shop upgrades still apply.</p>
              <button
                type="button"
                onClick={() => onOpen("chars")}
                className="min-h-11 w-full rounded-lg border border-border bg-surface-2 text-sm font-semibold text-fg"
              >
                Character: {CHARACTERS[pendingChar].name}
              </button>
              <button
                type="button"
                onClick={() =>
                  onStart({
                    mode: "endless",
                    characterId: pendingChar,
                    startWave: 1,
                    slotIndex: nextEmptyOrLast(profile),
                  })
                }
                className="mt-2 min-h-11 w-full rounded-lg bg-primary text-sm font-bold text-primary-fg"
              >
                Start Endless
              </button>
              <BackButton onClick={onBack} />
            </Panel>
          )}

          {screen === "chars" && (
            <Panel title="Character Select">
              <p className="mb-2 text-xs text-muted">Endless only. Story is JJ's night. Select a fighter — their loop stays on.</p>
              <div className="flex flex-col gap-2">
                {(Object.keys(CHARACTERS) as CharacterId[]).map((id) => {
                  const c = CHARACTERS[id];
                  const owned = profile.shop.ownedChars.includes(id);
                  const active = pendingChar === id;
                  return (
                    <CharCard
                      key={id}
                      id={id}
                      name={c.name}
                      role={c.role}
                      blurb={c.blurb}
                      owned={owned}
                      active={active}
                      onPick={() => {
                        onSetChar(id);
                        onSetMode("endless");
                        onHoverChar?.(id);
                      }}
                      onHover={onHoverChar}
                    />
                  );
                })}
              </div>
              <button
                type="button"
                onClick={() =>
                  onStart({
                    mode: "endless",
                    characterId: pendingChar,
                    startWave: 1,
                    slotIndex: nextEmptyOrLast(profile),
                  })
                }
                className="mt-3 min-h-11 w-full rounded-lg bg-primary text-sm font-bold text-primary-fg"
              >
                Fight as {CHARACTERS[pendingChar].name}
              </button>
              <BackButton onClick={onBack} />
            </Panel>
          )}

          {screen === "stages" && (
            <Panel title="World Map">
              <div className="flex flex-col gap-2">
                {STAGES.map((st) => {
                  const open = profile.unlocks.stages.includes(st.id);
                  return (
                    <button
                      key={st.id}
                      type="button"
                      disabled={!open}
                      onClick={() =>
                        onStart({
                          mode: "story",
                          characterId: "jj",
                          startWave: st.id,
                          slotIndex: nextEmptyOrLast(profile),
                        })
                      }
                      className="flex min-h-12 items-center justify-between rounded-lg border border-border bg-surface-2 px-3 text-left disabled:opacity-40"
                    >
                      <span>
                        <span className="block text-sm font-semibold text-fg">
                          {st.id}. {st.name}
                        </span>
                        <span className="text-[11px] text-muted">{open ? st.sub : "Locked"}</span>
                      </span>
                    </button>
                  );
                })}
              </div>
              <BackButton onClick={onBack} />
            </Panel>
          )}

          {screen === "jukebox" && <Jukebox onBack={onBack} />}

          {screen === "support" && <SupportForm onBack={onBack} onSend={onFeedback} />}
        </div>
      </div>
    </div>
  );
}

function nextEmptyOrLast(p: Profile) {
  const empty = p.slots.findIndex((s) => !s);
  if (empty >= 0) return empty;
  return p.lastSlot ?? 0;
}

function Panel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-2xl border border-border bg-surface/95 p-4">
      <h3 className="mb-3 text-sm font-bold uppercase tracking-widest text-muted">{title}</h3>
      {children}
    </div>
  );
}

function BackButton({ onClick }: { onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="mt-4 min-h-11 w-full rounded-lg border border-border bg-surface-2 text-sm font-semibold text-fg"
    >
      Back
    </button>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-border bg-surface-2 px-3 py-2">
      <dt className="text-[10px] uppercase tracking-wide text-muted">{label}</dt>
      <dd className="font-semibold tabular-nums text-fg">{value}</dd>
    </div>
  );
}

function Jukebox({ onBack }: { onBack: () => void }) {
  const [now, setNow] = useState(currentTrack());
  return (
    <Panel title="Soundtrack">
      <p className="mb-2 text-xs text-muted">Chip riffs. No licensed tracks — just the machine.</p>
      <div className="flex flex-col gap-2">
        {TRACKS.map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => {
              if (now === t.id) {
                stopTrack();
                setNow(null);
              } else {
                playTrack(t.id);
                setNow(t.id);
              }
            }}
            className={`min-h-11 rounded-lg border px-3 text-left text-sm font-semibold ${
              now === t.id ? "border-accent bg-accent/15 text-fg" : "border-border bg-surface-2 text-fg"
            }`}
          >
            {now === t.id ? "Playing · " : ""}
            {t.name}
          </button>
        ))}
      </div>
      <BackButton
        onClick={() => {
          stopTrack();
          onBack();
        }}
      />
    </Panel>
  );
}

function SupportForm({ onBack, onSend }: { onBack: () => void; onSend: (t: string) => void }) {
  const [text, setText] = useState("");
  const [sent, setSent] = useState(false);
  return (
    <Panel title="Support / Feedback">
      <p className="mb-2 text-xs text-muted">Tell us what broke or what the street needs. Stored on this device.</p>
      <textarea
        value={text}
        onChange={(e) => setText(e.target.value)}
        rows={4}
        className="w-full resize-none rounded-lg border border-border bg-bg px-3 py-2 text-sm text-fg outline-none focus:border-accent"
        placeholder="The riff froze on wave…"
      />
      <button
        type="button"
        disabled={!text.trim()}
        onClick={() => {
          onSend(text.trim());
          setText("");
          setSent(true);
        }}
        className="mt-2 min-h-11 w-full rounded-lg bg-primary text-sm font-bold text-primary-fg disabled:opacity-40"
      >
        {sent ? "Saved" : "Send"}
      </button>
      <BackButton onClick={onBack} />
    </Panel>
  );
}

function CharCard({
  id,
  name,
  role,
  blurb,
  owned,
  active,
  onPick,
  onHover,
}: {
  id: CharacterId;
  name: string;
  role: string;
  blurb: string;
  owned: boolean;
  active: boolean;
  onPick: () => void;
  onHover?: (id: CharacterId | null) => void;
}) {
  const [hot, setHot] = useState(false);
  const still =
    id === "andrew"
      ? "/assets/ui/andrew-frames/f001.jpg"
      : id === "han"
        ? "/assets/ui/han-frames/f001.jpg"
        : "/assets/sprites/jj/idle/sheet-transparent.png";
  return (
    <button
      type="button"
      disabled={!owned}
      onClick={onPick}
      onMouseEnter={() => {
        setHot(true);
        if (owned) onPick();
        else onHover?.(id);
      }}
      onMouseLeave={() => {
        setHot(false);
      }}
      onFocus={() => {
        setHot(true);
        if (owned) onPick();
        else onHover?.(id);
      }}
      onBlur={() => {
        setHot(false);
      }}
      className={`flex items-center gap-3 rounded-lg border px-2 py-2 text-left ${
        !owned
          ? "border-border bg-bg/40 text-muted"
          : active
            ? "border-primary bg-primary/20 text-fg"
            : "border-border/70 bg-bg/55 text-fg"
      }`}
    >
      <div className="relative h-20 w-20 shrink-0 overflow-hidden rounded-md bg-black">
        <img src={still} alt="" className="pixelated h-full w-full object-cover object-right" />
      </div>
      <div className="min-w-0">
        <p className="text-sm font-semibold">
          {name} {!owned && "· Locked"}
        </p>
        <p className="text-[11px] text-muted">
          {role} — {blurb}
        </p>
        {(active || hot) && id === "andrew" && <p className="text-[10px] text-accent">Typing loop</p>}
        {(active || hot) && id === "han" && <p className="text-[10px] text-accent">Phone & cat loop</p>}
        {(active || hot) && id === "jj" && <p className="text-[10px] text-accent">Alley smoke loop</p>}
      </div>
    </button>
  );
}

function SpritePreview({ sheet }: { sheet: LoadedSheet }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    let raf = 0;
    const size = 64;
    canvas.width = size;
    canvas.height = size;
    const draw = (now: number) => {
      const f = Math.floor(now / 180) % sheet.frameCount;
      const col = f % sheet.cols;
      const row = Math.floor(f / sheet.cols);
      ctx.imageSmoothingEnabled = false;
      ctx.clearRect(0, 0, size, size);
      ctx.drawImage(
        sheet.img,
        col * sheet.frameW,
        row * sheet.frameH,
        sheet.frameW,
        sheet.frameH,
        0,
        0,
        size,
        size,
      );
      raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(raf);
  }, [sheet]);
  return <canvas ref={ref} className="pixelated h-16 w-16" aria-hidden />;
}
