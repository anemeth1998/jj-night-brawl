import { useEffect, useState } from "react";
import { playMenuTheme, sfx, toggleMute } from "../audio";
import { STAGES, type StageId } from "../types";

type Panel = "root" | "stages" | "controls";

type Props = {
  muted: boolean;
  onMuteChange: (m: boolean) => void;
  onPlay: (stage?: StageId) => void;
  onBack: () => void;
};

const ROOT_ITEMS = [
  { id: "play", label: "Start Brawl" },
  { id: "stages", label: "Stage Select" },
  { id: "controls", label: "Controls" },
  { id: "title", label: "Title" },
] as const;

export function MenuSelect({ muted, onMuteChange, onPlay, onBack }: Props) {
  const [panel, setPanel] = useState<Panel>("root");
  const [index, setIndex] = useState(0);

  useEffect(() => {
    playMenuTheme();
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.code === "KeyM") {
        onMuteChange(toggleMute());
        return;
      }
      if (e.code === "Escape") {
        if (panel !== "root") {
          setPanel("root");
          setIndex(0);
          sfx.uiMove();
        } else {
          onBack();
        }
        return;
      }

      const count =
        panel === "root" ? ROOT_ITEMS.length : panel === "stages" ? STAGES.length + 1 : 1;
      if (e.code === "ArrowDown" || e.code === "KeyS") {
        e.preventDefault();
        setIndex((i) => (i + 1) % count);
        sfx.uiMove();
      }
      if (e.code === "ArrowUp" || e.code === "KeyW") {
        e.preventDefault();
        setIndex((i) => (i - 1 + count) % count);
        sfx.uiMove();
      }
      if (e.code === "Enter" || e.code === "Space" || e.code === "KeyZ") {
        e.preventDefault();
        confirm(index, panel, setPanel, setIndex, onPlay, onBack);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [index, panel, onPlay, onBack, onMuteChange]);

  return (
    <section className="relative flex h-dvh w-full overflow-hidden bg-ink text-fg">
      <video
        className="absolute inset-0 h-full w-full object-cover object-[center_30%]"
        src="/ui/menu-select-loop.mp4"
        poster="/ui/menu-jj-idle.jpg"
        autoPlay
        muted
        loop
        playsInline
        preload="auto"
      />
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-r from-ink via-ink/75 to-ink/15" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 h-28 bg-gradient-to-t from-ink to-transparent" />

      <button
        type="button"
        onClick={() => onMuteChange(toggleMute())}
        className="absolute top-4 right-4 z-20 min-h-11 min-w-11 rounded-full border border-line bg-night/70 px-3 font-display text-[9px] tracking-widest text-fg backdrop-blur-sm"
        aria-label={muted ? "Unmute" : "Mute"}
      >
        {muted ? "MUTE" : "BGM"}
      </button>

      <div className="relative z-10 flex h-full w-full max-w-xl flex-col justify-center px-6 py-10 sm:px-12">
        <p className="mb-2 font-display text-[8px] tracking-[0.35em] text-gold uppercase">
          Menu Select
        </p>
        <h1 className="mb-8 font-display text-lg leading-8 text-hot sm:text-xl">JJ Night Brawl</h1>

        {panel === "root" && (
          <nav className="flex flex-col gap-1" aria-label="Main menu">
            {ROOT_ITEMS.map((item, i) => (
              <MenuRow
                key={item.id}
                active={i === index}
                label={item.label}
                onHover={() => setIndex(i)}
                onClick={() => confirm(i, "root", setPanel, setIndex, onPlay, onBack)}
              />
            ))}
          </nav>
        )}

        {panel === "stages" && (
          <nav className="flex flex-col gap-1" aria-label="Stages">
            {STAGES.map((st, i) => (
              <MenuRow
                key={st.id}
                active={i === index}
                label={st.title}
                hint={st.wave}
                onHover={() => setIndex(i)}
                onClick={() => {
                  sfx.uiConfirm();
                  onPlay(st.id);
                }}
              />
            ))}
            <MenuRow
              active={index === STAGES.length}
              label="Back"
              onHover={() => setIndex(STAGES.length)}
              onClick={() => {
                setPanel("root");
                setIndex(1);
                sfx.uiMove();
              }}
            />
          </nav>
        )}

        {panel === "controls" && (
          <div className="max-w-sm rounded-panel border border-line bg-night/80 p-5 backdrop-blur-sm">
            <ul className="space-y-2 text-sm text-fg">
              <li>
                <span className="text-cyan">WASD / Arrows</span> — move
              </li>
              <li>
                <span className="text-cyan">J / Z</span> — punch
              </li>
              <li>
                <span className="text-cyan">K / X</span> — kick
              </li>
              <li>
                <span className="text-cyan">L / C</span> — guitar riff (meter)
              </li>
              <li>
                <span className="text-cyan">Space</span> — jump
              </li>
              <li>
                <span className="text-cyan">P / Esc</span> — pause
              </li>
              <li>
                <span className="text-cyan">M</span> — mute
              </li>
            </ul>
            <button
              type="button"
              className="mt-5 min-h-11 font-display text-[9px] tracking-widest text-hot uppercase"
              onClick={() => {
                setPanel("root");
                setIndex(2);
              }}
            >
              ← Back
            </button>
          </div>
        )}

        <p className="mt-8 max-w-sm text-xs leading-5 text-muted">
          Clear five waves through Junction City. Chain combos. Fill the riff meter.
        </p>
      </div>
    </section>
  );
}

function MenuRow({
  active,
  label,
  hint,
  onHover,
  onClick,
}: {
  active: boolean;
  label: string;
  hint?: string;
  onHover: () => void;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onMouseEnter={onHover}
      onClick={onClick}
      className={
        "flex min-h-12 items-center justify-between gap-4 rounded-md border px-4 text-left transition-colors " +
        (active
          ? "border-hot bg-hot/15 text-fg"
          : "border-transparent bg-transparent text-muted hover:text-fg")
      }
    >
      <span className="flex items-center gap-3 font-display text-[10px] tracking-wider uppercase sm:text-[11px]">
        <span className={active ? "text-hot" : "text-transparent"} aria-hidden>
          ▶
        </span>
        {label}
      </span>
      {hint && <span className="text-[11px] text-muted">{hint}</span>}
    </button>
  );
}

function confirm(
  index: number,
  panel: Panel,
  setPanel: (p: Panel) => void,
  setIndex: (i: number) => void,
  onPlay: (stage?: StageId) => void,
  onBack: () => void,
) {
  if (panel === "controls") {
    setPanel("root");
    setIndex(2);
    sfx.uiMove();
    return;
  }
  if (panel === "stages") {
    if (index >= STAGES.length) {
      setPanel("root");
      setIndex(1);
      sfx.uiMove();
      return;
    }
    const stage = STAGES[index];
    if (stage) {
      sfx.uiConfirm();
      onPlay(stage.id);
    }
    return;
  }
  const item = ROOT_ITEMS[index];
  if (!item) return;
  sfx.uiConfirm();
  if (item.id === "play") onPlay();
  else if (item.id === "stages") {
    setPanel("stages");
    setIndex(0);
  } else if (item.id === "controls") {
    setPanel("controls");
    setIndex(0);
  } else onBack();
}
