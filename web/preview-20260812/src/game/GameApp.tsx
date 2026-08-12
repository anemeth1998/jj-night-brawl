import { useCallback, useEffect, useState } from "react";
import { isMuted, subscribeAudio } from "./audio";
import { TitleScreen } from "./screens/TitleScreen";
import { MenuSelect } from "./screens/MenuSelect";
import { GameView } from "./screens/GameView";
import type { StageId } from "./types";

type Screen = "title" | "menu" | "playing";

export function GameApp() {
  const [screen, setScreen] = useState<Screen>("title");
  const [stage, setStage] = useState<StageId | undefined>(undefined);
  const [muted, setMuted] = useState(false);

  useEffect(() => subscribeAudio(() => setMuted(isMuted())), []);

  const toMenu = useCallback(() => setScreen("menu"), []);
  const toTitle = useCallback(() => setScreen("title"), []);
  const play = useCallback((id?: StageId) => {
    setStage(id);
    setScreen("playing");
  }, []);

  if (screen === "title") {
    return <TitleScreen muted={muted} onMuteChange={setMuted} onStart={toMenu} />;
  }
  if (screen === "menu") {
    return (
      <MenuSelect muted={muted} onMuteChange={setMuted} onPlay={play} onBack={toTitle} />
    );
  }
  return <GameView startStage={stage} onQuit={toMenu} />;
}
