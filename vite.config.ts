import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import path from "node:path";

// Port 5184 is pinned (strictPort) — see the AI Please local dev port registry.
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { "@": path.resolve(import.meta.dirname, "src") },
  },
  server: { port: 5184, strictPort: true },
  preview: { port: 5184, strictPort: true },
});
