import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  
  build: {
    target: 'esnext',
    minify: 'terser',
    cssMinify: true,
    rollupOptions: {
      output: {
        manualChunks: {
          'react-vendor': ['react', 'react-dom', 'react-router-dom'],
          'ui': ['lucide-react', 'date-fns'],
          'supabase': ['@supabase/supabase-js']
        }
      }
    }
  },
  
  optimizeDeps: {
    exclude: ['lucide-react'],
    include: ['react', 'react-dom', '@supabase/supabase-js']
  }
});