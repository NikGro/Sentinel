import preact from '@preact/preset-vite';
import { defineConfig } from 'vite';

// Im Entwicklungsbetrieb werden API und WebSocket an den lokal laufenden Server weitergereicht.
export default defineConfig({
  plugins: [preact()],
  build: { outDir: 'dist', sourcemap: false, target: 'es2022', chunkSizeWarningLimit: 1500 },
  server: {
    port: 5173,
    proxy: {
      '/api': { target: 'http://127.0.0.1:8790', ws: true },
      '/sidestore': 'http://127.0.0.1:8790',
    },
  },
});
