import path from "path";
import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");

  console.log("=== VITE CONFIG DEBUG ===");
  console.log("Mode:", mode);
  console.log("VITE_GEMINI_API_KEY:", env.VITE_GEMINI_API_KEY);

  return {
    base: "/retail/",
    server: {
      port: 3000,
      host: "0.0.0.0",
    },
    plugins: [react()],
    resolve: {
      alias: {
        "@": path.resolve(__dirname, "."),
      },
    },
  };
});
