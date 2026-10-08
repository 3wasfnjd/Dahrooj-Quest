import { defineConfig } from 'vite';
import { iwsdkDev } from '@iwsdk/vite-plugin-dev';
import { fileURLToPath } from 'node:url';
import { mkdirSync, writeFileSync } from 'node:fs';
export default defineConfig({
  plugins: [process.env.VITE_XR_AUTOMATION === '1' ? undefined : iwsdkDev({ https: false, bundle: { fonts: [] } }), { name: 'production-module-audit', generateBundle(_options, bundle) { const modules = new Set<string>(); for (const file of Object.values(bundle)) if (file.type === 'chunk') for (const id of Object.keys(file.modules)) modules.add(id.split('/node_modules/').at(-1)!); mkdirSync('reports', { recursive: true }); writeFileSync('reports/bundled-modules.json', JSON.stringify([...modules].sort(), null, 2)); } }],
  resolve: { dedupe: ['three'], alias: { '@drawcall/uikitml': fileURLToPath(new URL('./src/platform/disabled-uikitml.ts', import.meta.url)) } },
  worker: { format: 'es' },
  optimizeDeps: { exclude: ['@iwsdk/core', '@iwsdk/locomotor', '@babylonjs/havok'] },
  server: { port: 5173, strictPort: true },
  preview: { port: 4173, strictPort: true },
  build: { target: 'es2022', sourcemap: false, assetsInlineLimit: 0, chunkSizeWarningLimit: 2000 }
});
