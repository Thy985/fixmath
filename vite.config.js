import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: '/fixmath/',
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          'vendor-react': ['react', 'react-dom'],
          'vendor-katex': ['katex'],
          'vendor-docx': ['docx'],
          'vendor-pdf': ['html2canvas', 'html2pdf.js'],
          'vendor-marked': ['marked'],
        },
      },
    },
    chunkSizeWarningLimit: 500,
  },
  optimizeDeps: {
    include: ['react', 'react-dom', 'katex'],
  },
})
