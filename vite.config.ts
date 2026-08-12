import { resolve } from 'node:path';
import { defineConfig } from 'vite';

/**
 * 셸 전용 로컬 자산 빌드.
 *
 * 소스는 shell/ 에 두고, 산출물은 www/ 로 나간다.
 * www/ 는 capacitor.config.ts 의 webDir 이며 빌드 산출물이므로 커밋하지 않는다.
 * (ADR-001 하이브리드 로드 — 여기 있는 페이지는 셸 고유 화면뿐이고,
 *  실제 콘텐츠는 원격 webBaseUrl 에서 로드한다.)
 */
const shellDir = resolve(import.meta.dirname, 'shell');

export default defineConfig({
  root: shellDir,
  publicDir: resolve(shellDir, 'public'),
  // shell/entries/*.ts 가 저장소 루트의 src/ 를 import 하므로 dev 서버에 접근을 허용한다.
  server: {
    fs: { allow: [import.meta.dirname] },
  },
  build: {
    outDir: resolve(import.meta.dirname, 'www'),
    emptyOutDir: true,
    target: 'es2022',
    rollupOptions: {
      input: {
        index: resolve(shellDir, 'index.html'),
        offline: resolve(shellDir, 'offline.html'),
        'update-required': resolve(shellDir, 'update-required.html'),
        onboarding: resolve(shellDir, 'onboarding.html'),
      },
    },
  },
});
