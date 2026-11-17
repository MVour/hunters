import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

// `npm run dev` talks to a lobby service on localhost:8787.
export default defineConfig({
  plugins: [vue()],
  build: { outDir: 'dist', emptyOutDir: true, sourcemap: false },
  server: {
    proxy: {
      '/api': 'http://127.0.0.1:8787',
      '/play': { target: 'ws://127.0.0.1:8787', ws: true },
    },
  },
});
