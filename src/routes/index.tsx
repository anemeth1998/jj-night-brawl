import { createFileRoute } from "@tanstack/react-router";
import { GamePage } from "@/components/game-page";

export const Route = createFileRoute("/")({
  component: GamePage,
});
