# Firebase 설정

푸시를 붙이려면 Firebase 프로젝트가 하나 필요하다. 아래는 **사람이 한 번 해야 하는
작업**이다. 여기서 나오는 파일 두 개와 키 하나는 저장소에 커밋하지 않는다.

## 0. 준비물

- Google 계정 (Firebase Console 접근)
- Apple Developer Program 유료 계정 (iOS 푸시는 유료 계정 없이는 불가)

## 1. Firebase 프로젝트 생성

1. https://console.firebase.google.com → 프로젝트 추가
2. 이름: `nuplex` (권장). Google Analytics 는 꺼도 된다 — 푸시에 필요하지 않다.

## 2. Android 앱 등록

1. 프로젝트 설정 → 앱 추가 → Android
2. 패키지 이름: **`com.nugabox.nuplex`** (오타 시 토큰이 발급되지 않는다)
3. `google-services.json` 다운로드 → `android/app/google-services.json` 에 둔다

> 이 파일이 없으면 Gradle 이 Google Services 플러그인을 건너뛰도록 해 두었다.
> 즉 파일 없이도 앱은 빌드되고 실행되지만, **푸시만 조용히 비활성**된다.

## 3. iOS 앱 등록

1. 프로젝트 설정 → 앱 추가 → iOS
2. 번들 ID: **`com.nugabox.nuplex`**
3. `GoogleService-Info.plist` 다운로드 → `ios/App/App/GoogleService-Info.plist` 에 둔다
4. Xcode 에서 프로젝트에 추가한다 (Target: App, Copy items if needed 체크)

## 4. APNs 인증 키 (iOS)

1. https://developer.apple.com/account → Keys → `+`
2. **Apple Push Notifications service (APNs)** 체크 → 생성 → `.p8` 다운로드
3. **`.p8` 은 다시 받을 수 없다.** 비밀번호 관리자 등 안전한 곳에 보관한다.
4. Firebase Console → 프로젝트 설정 → Cloud Messaging → Apple 앱 구성 →
   APNs 인증 키 업로드 (Key ID, Team ID 함께 입력)

## 5. Xcode 설정

- Signing & Capabilities → `+ Capability` → **Push Notifications** 추가
- 같은 화면에서 **Background Modes** → Remote notifications 체크
  (사일런트 푸시로 배지만 갱신할 때 필요)

## 6. 서버(nuplex) 자격증명

발송은 웹 백엔드가 한다. FCM HTTP v1 을 쓰므로 **서비스 계정 키**가 필요하다.

1. Firebase Console → 프로젝트 설정 → 서비스 계정 → 새 비공개 키 생성 (JSON)
2. 그 JSON 을 `nuplex` 의 `.env` 에 `FCM_SERVICE_ACCOUNT` 로 넣는다.
   한 줄 JSON 또는 base64 둘 다 받는다 (`nuplex/lib/push/fcm.ts`).

자격증명이 없으면 웹은 발송을 시도하지 않고 `notice_delivery` 에 `pending` 만
쌓아둔다. 나중에 키를 넣으면 그대로 나간다.

## 7. 확인

```bash
# Android — 토큰이 발급되는지
adb logcat -s Nuplex | grep -i token

# 실제 발송 테스트는 Firebase Console → Cloud Messaging → 테스트 메시지 보내기
# 또는 nuplex 관리자 화면에서 공지를 발송한다.
```

**푸시는 시뮬레이터/에뮬레이터에서 검증할 수 없다. 실기기가 필요하다.**

## 커밋 금지 파일

`.gitignore` 에 이미 들어 있다. 실수로 올라갔는지 가끔 확인한다.

```
android/app/google-services.json
ios/App/App/GoogleService-Info.plist
*.p8
```

```bash
git log -p | grep -iE 'google-services|GoogleService-Info|BEGIN PRIVATE KEY'
```
