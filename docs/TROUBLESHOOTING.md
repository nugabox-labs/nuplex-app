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
