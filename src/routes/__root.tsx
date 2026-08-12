import type { ReactNode } from "react";
import {
  Outlet,
  createRootRoute,
  HeadContent,
  Scripts,
} from "@tanstack/react-router";
import { AppErrorComponent } from "@/lib/error-component";
import appCss from "@/styles.css?url";

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      {
        name: "viewport",
        content: "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no",
      },
      { title: "JJ: Night Brawl" },
      {
        name: "description",
        content: "32-bit side-scrolling beat-em-up starring JJ",
      },
      { name: "theme-color", content: "#0a0612" },
    ],
    links: [{ rel: "stylesheet", href: appCss }],
  }),
  component: RootComponent,
  errorComponent: AppErrorComponent,
});

function RootComponent() {
  return (
    <RootDocument>
      <Outlet />
    </RootDocument>
  );
}

function RootDocument({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <head>
        <HeadContent />
      </head>
      <body className="bg-bg text-fg antialiased">
        {children}
        <Scripts />
      </body>
    </html>
  );
}
