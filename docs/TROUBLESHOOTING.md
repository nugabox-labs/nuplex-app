# 트러블슈팅

## 개발 환경

### `pod` 실행 시 `Could not find 'bigdecimal'` 크래시

이 개발 머신은 RVM 이 `GEM_HOME` / `GEM_PATH` 를 셸 프로필에서 전역 export 한다.
그 결과 Homebrew 로 설치한 CocoaPods 가 RVM(ruby 2.7.4)의 gem 경로를 뒤지다 실패한다.

전역 셸 설정을 고치면 다른 Ruby 프로젝트가 깨지므로, 이 저장소에서는
`scripts/cap.mjs` 래퍼가 해당 변수를 걷어낸 채 Capacitor CLI 를 실행한다.
**`npx cap` 대신 `npm run cap -- <명령>` 을 쓸 것.**

직접 확인하려면:

```bash
env -u GEM_HOME -u GEM_PATH pod --version   # 1.17.0
```

> Capacitor 8 의 iOS 플랫폼은 CocoaPods 가 아닌 **Swift Package Manager** 를 쓴다.
> 따라서 현재 플러그인 구성에서는 `pod` 이 필요 없다. 다만 SPM 을 지원하지 않는
> 서드파티 플러그인을 추가하면 다시 필요해질 수 있어 위 우회를 유지한다.

### Gradle 이 `Unable to infer default Android SDK settings` 또는 JDK 오류

기본 JDK 가 11 인데 AGP 8.13 은 17 이상을 요구한다.
`scripts/cap.mjs` 가 Android Studio 번들 JBR(21)을 `JAVA_HOME` 으로 지정한다.
CLI 에서 Gradle 을 직접 부를 때는 다음처럼 넘긴다:

```bash
cd android
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug
```

CI 처럼 적절한 JDK 가 이미 잡힌 환경에서는 `CAP_SKIP_JBR=1` 로 이 동작을 끈다.

### `npm run cap -- add android` 첫 실행 시 Gradle sync 실패

`local.properties` 가 아직 없어 SDK 경로를 못 찾는 경우다. Android Studio 로 한 번
열면 자동 생성된다. 이 파일은 머신마다 달라 커밋하지 않는다.

## 런타임

### 웹뷰가 흰 화면으로 멈춤

`www/` 가 비어 있거나 `npm run sync` 를 하지 않은 경우가 대부분이다.
`npm run build && npm run cap -- sync` 로 재동기화한다.

### 웹 배포 후에도 앱에 구버전 UI 가 뜸

웹뷰 캐시 문제다. `nuplex` 웹의 HTML 응답에 `Cache-Control: no-store` 가 붙어 있는지
확인한다. 해시가 붙은 정적 자산만 장기 캐시해야 한다. (설계 명세 §9.3)

### 원격 설정 조회가 항상 실패하고 오프라인 화면만 뜸

셸의 로컬 페이지 origin 은 `capacitor://localhost` 다. 여기서 웹 도메인으로 보내는
브라우저 `fetch` 는 교차 출처라 CORS 에 막힌다. 그래서 `remote-config.ts` 는
`CapacitorHttp`(네이티브에서 나가는 요청)를 쓴다. 이걸 다시 `fetch` 로 바꾸면
증상이 재발한다.

웹뷰가 웹 도메인으로 이동한 뒤의 요청은 동일 출처라 영향이 없다.

### 원격 페이지에서 window.NuplexNative 가 undefined

주입 자체가 실패한 경우다. 네이티브 로그에 `[Nuplex] 브릿지 주입됨: <url>` 이
찍히는지 본다.

```bash
# iOS 시뮬레이터
xcrun simctl spawn booted log show --last 2m --predicate 'eventMessage CONTAINS "Nuplex"'
# Android
adb logcat -s Nuplex
```

- 로그가 아예 없다 → 스크립트를 못 읽었다. `npm run sync` 후 앱을 다시 설치한다
  (`ios/App/App/public/nuplex-bridge.js`, `android/app/src/main/assets/public/nuplex-bridge.js` 존재 확인).
- 로컬 주소로만 찍히고 웹 도메인으로는 안 찍힌다 → `capacitor.config.ts` 의
  `allowNavigation` 에 그 도메인이 없다. Android 는 이 목록이 주입 허용 origin 이다.

### 실기기에서 맥의 dev 서버를 보고 싶다

`localhost` 는 기기 자신을 가리킨다. 맥의 사설망 주소를 넣어 빌드한다.

```bash
VITE_WEB_BASE_URL=http://192.168.0.10:2620 npm run sync
```

`allowNavigation` 에 `192.168.*` 과 `10.*` 이 이미 들어 있다.
릴리스 빌드에서는 이 환경변수를 넘기지 않는다(docs/RELEASE.md 점검 목록).
