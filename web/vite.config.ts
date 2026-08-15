import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = path.dirname(fileURLToPath(import.meta.url));
const assetsRoot = path.resolve(rootDir, "../assets");

function mimeFor(file: string) {
  const ext = path.extname(file).toLowerCase();
  if (ext === ".png") return "image/png";
  if (ext === ".jpg" || ext === ".jpeg") return "image/jpeg";
  if (ext === ".gif") return "image/gif";
  if (ext === ".webp") return "image/webp";
  if (ext === ".mp3") return "audio/mpeg";
  if (ext === ".mp4") return "video/mp4";
  if (ext === ".json") return "application/json";
  if (ext === ".svg") return "image/svg+xml";
  return "application/octet-stream";
}

function resolveAsset(urlPath: string) {
  const clean = decodeURIComponent(urlPath.split("?")[0] ?? "").replace(/^\/assets\/?/, "");
  const file = path.resolve(assetsRoot, clean);
  if (!file.startsWith(assetsRoot + path.sep) && file !== assetsRoot) return null;
  if (!fs.existsSync(file) || !fs.statSync(file).isFile()) return null;
  return file;
}

function repoAssets(): Plugin {
  return {
    name: "jj-repo-assets",
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const url = req.url ?? "";
        if (!url.startsWith("/assets/")) return next();
        const file = resolveAsset(url);
        if (!file) return next();
        res.setHeader("Content-Type", mimeFor(file));
        res.setHeader("Cache-Control", "no-cache");
        fs.createReadStream(file).pipe(res);
      });
    },
    configurePreviewServer(server) {
      server.middlewares.use((req, res, next) => {
        const url = req.url ?? "";
        if (!url.startsWith("/assets/")) return next();
        const file = resolveAsset(url);
        if (!file) return next();
        res.setHeader("Content-Type", mimeFor(file));
        fs.createReadStream(file).pipe(res);
      });
    },
    closeBundle() {
      const dest = path.resolve(rootDir, "dist/assets");
      fs.rmSync(dest, { recursive: true, force: true });
      fs.cpSync(assetsRoot, dest, { recursive: true });
    },
  };
}

export default defineConfig({
  plugins: [react(), tailwindcss(), repoAssets()],
  server: {
    host: "0.0.0.0",
    port: 5173,
    fs: { allow: [rootDir, path.resolve(rootDir, "..")] },
  },
  preview: {
    host: "0.0.0.0",
    port: 5173,
  },
});
