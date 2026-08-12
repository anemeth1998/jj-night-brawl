import { createRouter } from "@tanstack/react-router";
import { routeTree } from "./routeTree.gen";
import { AppErrorComponent } from "@/lib/error-component";

export function getRouter() {
  const router = createRouter({
    routeTree,
    scrollRestoration: true,
    defaultPreload: "intent",
    defaultPendingMinMs: 0,
    defaultErrorComponent: AppErrorComponent,
  });
  return router;
}

declare module "@tanstack/react-router" {
  interface Register {
    router: ReturnType<typeof getRouter>;
  }
}
