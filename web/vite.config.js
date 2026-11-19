import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

// En dev, Vite relaie les appels vers les services lancés en local ou via Docker Compose.
export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:8080',
      '/ai': { target: 'http://localhost:8000', rewrite: (p) => p.replace(/^\/ai/, '') },
    },
  },
  test: {
    environment: 'jsdom',
  },
});
