# Phase 1 — 프로젝트 스캐폴딩

- 상태: 완료 (2026-08-12)
- 커밋: `fbba268` chore: scaffold capacitor shell

## 한 일

- [x] 환경 검증 및 블로커 해소
- [x] Capacitor 8.5.0 고정, appId `com.nugabox.nuplex`, appName `NUPLEX`
- [x] TypeScript 5.9.3 + Vite 8.2.1, `shell/` → `www/` 빌드
- [x] `.nvmrc`(22.23.2), `.gitignore`(시크릿 차단), `README.md`
- [x] `npx cap add ios` / `add android`

## 개발 환경 블로커 3건

| 블로커 | 해소 방법 |
| --- | --- |
| Node 20 (22 필요) | nvm 으로 22.23.2 설치 · default 지정 |
| JDK 11 (AGP 8.13 은 17+) | Android Studio 번들 JBR 21 사용. `scripts/cap.mjs` 가 JAVA_HOME 지정 |
| CocoaPods 크래시 | RVM 이 GEM_HOME/GEM_PATH 를 전역 export 해 Homebrew Ruby 오염. 전역 설정 대신 `scripts/cap.mjs` 에서 변수 제거 |

→ 그래서 이 저장소는 `npx cap` 대신 **`npm run cap -- <명령>`** 을 쓴다.

## 명세와 다른 점

- **minSdk 24** (명세는 23). Capacitor 8 기본값을 그대로 뒀다.
- **TypeScript 5.9.3** 고정. 최신은 7.x 지만 명세가 5.x 로 못박았다.
- **iOS 는 CocoaPods 를 쓰지 않는다.** Capacitor 8 은 SPM 기반이다.

## 검증

- Android `assembleDebug` 통과 (APK 4.2MB)
- iOS 시뮬레이터 빌드 통과
