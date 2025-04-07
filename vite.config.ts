import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig({
  base: '/LocDecor/', // 👈 ISSO É O QUE FALTAVA!
  plugins: [react()],
  optimizeDeps: {
    exclude: ['lucide-react'],
  },
});
