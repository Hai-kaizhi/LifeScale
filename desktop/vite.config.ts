/// <reference types="vitest" />
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// @ts-expect-error process 是 Node.js 运行时提供的全局对象。
const host = process.env.TAURI_DEV_HOST;

// https://vite.dev/config/
export default defineConfig(async () => ({
  plugins: [react()],

  // 单元测试（vitest）：纯逻辑用 node 环境，匹配 src 下的 *.test.ts。
  test: {
    environment: "node",
    globals: true,
    include: ["src/**/*.{test,spec}.ts"],
  },

  // 以下配置专门服务 Tauri 开发链路，仅在 `tauri dev` 或 `tauri build` 时生效。
  //
  // 1. 避免 Vite 清屏后遮挡 Rust 编译错误。
  clearScreen: false,
  // 2. Tauri 依赖固定端口，端口被占用时直接失败，便于定位启动问题。
  server: {
    port: 5173,
    strictPort: true,
    host: host || false,
    hmr: host
      ? {
          protocol: "ws",
          host,
          port: 5174,
        }
      : undefined,
    watch: {
      // 3. Rust 侧代码由 Cargo 监听，Vite 不需要重复监听 `src-tauri`。
      ignored: ["**/src-tauri/**"],
    },
  },
}));
