package com.nugabox.nuplex;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.util.Log;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;

/**
 * 브릿지 메서드의 실제 구현 (Android).
 *
 * 계약: docs/BRIDGE_CONTRACT.md §1. **메서드를 지우지 않는다** — 신버전 셸에 구버전
 * 웹이 로드될 수도, 그 반대일 수도 있다.
 *
 * 여기서 예외가 새어나가면 웹의 클릭 핸들러가 죽는다. 모든 경로가 값을 돌려주고
 * 실패해도 조용히 물러난다.
 */
public class NuplexBridgeApi {

    private static final String TAG = "Nuplex";
    private static final int BRIDGE_VERSION = 2;

    private final Activity activity;
    private final WebView webView;

    NuplexBridgeApi(Activity activity, WebView webView) {
        this.activity = activity;
        this.webView = webView;
    }

    /**
     * 웹 자산으로 딸려온 스크립트를 읽어 자리표시자를 채운다. 실패하면 브릿지 없이 뜬다.
     * assets/public/ 은 cap sync 가 www/ 를 복사해 넣는 곳이다.
     */
    String buildBridgeScript() {
        String template = readAsset("public/nuplex-bridge.js");
        if (template == null) return null;

        return template
            .replace("__NUPLEX_PLATFORM__", "android")
            .replace("__NUPLEX_APP_VERSION__", appVersion())
            .replace("__NUPLEX_BRIDGE_VERSION__", String.valueOf(BRIDGE_VERSION));
    }

    private String readAsset(String name) {
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(activity.getAssets().open(name), StandardCharsets.UTF_8))) {
            StringBuilder out = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                out.append(line).append('\n');
            }
            return out.toString();
        } catch (Exception e) {
            Log.e(TAG, name + " 를 assets 에서 읽지 못했습니다. npm run sync 를 실행하세요.", e);
            return null;
        }
    }

    private String appVersion() {
        try {
            PackageManager pm = activity.getPackageManager();
            return pm.getPackageInfo(activity.getPackageName(), 0).versionName;
        } catch (Exception e) {
            return "0.0.0";
        }
    }

    // --- 웹에서 호출되는 창구 -------------------------------------------------

    @JavascriptInterface
    public void postMessage(String raw) {
        int callId = 0;
        try {
            JSONObject message = new JSONObject(raw);
            callId = message.optInt("id", 0);
            String method = message.optString("method", "");
            JSONObject args = message.optJSONObject("args");
            if (args == null) args = new JSONObject();

            dispatch(callId, method, args);
        } catch (Exception e) {
            Log.e(TAG, "브릿지 메시지 처리 실패", e);
            resolve(callId, null);
        }
    }

    private void dispatch(int callId, String method, JSONObject args) {
        switch (method) {
            case "openExternal":
                openExternal(args.optString("url", null));
                resolve(callId, null);
                break;

            case "setBadgeCount":
                // Android 는 런처가 배지를 그린다. 표준 API 가 없어 알림 채널의
                // 뱃지 설정에 맡긴다 — 여기서 할 수 있는 일이 없다.
                resolve(callId, null);
                break;

            case "openInPlex":
                openInPlex(
                    callId,
                    args.optString("webUrl", null),
                    args.optString("machineIdentifier", null),
                    args.optString("ratingKey", null),
                    args.optString("type", null));
                break;

            case "getPushPermission":
                resolve(callId, "\"" + NuplexPush.permissionState(activity) + "\"");
                break;

            case "requestPushPermission":
                // OS 다이얼로그 결과는 onRequestPermissionsResult 로 따로 온다. 여기서는
                // 지금 상태를 돌려주고, 웹은 화면에 돌아왔을 때 다시 조회하면 된다.
                NuplexPush.requestPermission(activity);
                resolve(callId, "\"" + NuplexPush.permissionState(activity) + "\"");
                break;

            case "getPushToken":
                com.google.firebase.messaging.FirebaseMessaging.getInstance().getToken()
                    .addOnCompleteListener(task -> {
                        if (!task.isSuccessful() || task.getResult() == null) {
                            // 자격증명이 없거나 Play 서비스가 없는 기기다. null 을 돌려준다.
                            Log.i(TAG, "FCM 토큰을 받지 못했습니다.");
                            resolve(callId, null);
                            return;
                        }
                        resolve(callId, org.json.JSONObject.quote(task.getResult()));
                    });
                break;

            case "clearPushRegistration":
                // 세션이 살아 있는 동안 불려야 한다. 로그아웃 뒤에 부르면 401 이다.
                NuplexTokenRegistrar.unregister(activity);
                resolve(callId, null);
                break;

            case "listCastTargets":
                NuplexCast.listTargets(
                    args.optJSONArray("candidates"),
                    args.optString("token", null),
                    literal -> resolve(callId, literal));
                break;

            case "castToTarget":
                NuplexCast.play(args, literal -> resolve(callId, literal));
                break;

            case "openRoutePicker":
                NuplexCast.showRoutePicker(activity, literal -> resolve(callId, literal));
                break;

            case "bridgeReady":
                // 주입 성공 로그. 이 줄이 안 보이면 브릿지가 안 붙은 것이다.
                Log.i(TAG, "브릿지 주입됨: " + args.optString("href", "?"));
                break;

            case "notifyWebReady":
                // 앱이 꺼진 상태에서 알림을 탭했다면 라우트가 여기까지 대기하고 있다.
                NuplexRouteQueue.flush(webView, NuplexPreferences.webBaseUrl(activity));
                // 웹이 준비됐다는 것은 로그인·프로필 선택을 마쳤다는 뜻이다. 토큰 등록에
                // 필요한 세션 쿠키가 이제야 생겼으므로 여기서 등록을 시도한다.
                registerPushTokenIfPossible();
                break;

            default:
                // 신버전 웹이 구버전 셸에 없는 메서드를 부른 경우다.
                Log.w(TAG, "알 수 없는 브릿지 메서드: " + method);
                resolve(callId, null);
        }
    }

    /** Plex 앱 식별자와 스토어 주소. src/config/constants.ts 의 PLEX 와 같이 고칠 것. */
    private static final String PLEX_PACKAGE = "com.plexapp.android";
    private static final String PLEX_STORE_MARKET = "market://details?id=com.plexapp.android";
    private static final String PLEX_STORE_WEB =
        "https://play.google.com/store/apps/details?id=com.plexapp.android";

    /**
     * Plex 로 이동한다 (docs/PLEX_DEEPLINK.md).
     *
     * **웹이 준 webUrl 을 그대로 열지 않는다.** 웹은 이제 우리 Plex 서버가 직접 서빙하는
     * 웹앱 주소를 만든다(plex.nugabox.com/web/index.html#!/...). 브라우저에서는 그게
     * 맞지만 Plex 앱은 그 도메인을 자기 것으로 등록하지 않아 절대 가로채지 않는다.
     * 앱에서는 Plex 앱으로 보내는 것이 목적이므로 machineIdentifier · ratingKey 로
     * 주소를 다시 만든다.
     *
     * 사다리는 넷이다.
     *
     *   1. Plex 앱 미설치 → Play 스토어 (opened: "store")
     *   2. plex://watch/video — Plex 앱이 실제로 받는 형식. 영화 · 에피소드가 바로
     *      재생된다. 시리즈처럼 재생할 파일이 없는 종류는 여기서 건너뛴다(type 참고)
     *   3. https://app.plex.tv/... 를 setPackage(PLEX_PACKAGE) 로 던진다. 명시적
     *      패키지라 브라우저로 새지 않는다. 지금 Plex 는 이 링크를 등록하지 않아
     *      항상 실패하지만, 다시 등록할 경우를 위해 남겨둔다
     *   4. 전부 실패하면 웹이 준 주소를 브라우저로. **작품까지는 정확히 가므로 여기까지
     *      내려와도 시청은 된다.** 이 폴백을 지우지 말 것
     */
    private void openInPlex(
            int callId, String webUrl, String machineIdentifier, String ratingKey, String type) {
        if (!isPlexInstalled()) {
            if (startViewIntent(PLEX_STORE_MARKET, null) || startViewIntent(PLEX_STORE_WEB, null)) {
                resolve(callId, "{\"opened\":\"store\"}");
                return;
            }
            openExternal(webUrl);
            resolve(callId, "{\"opened\":\"browser\"}");
            return;
        }

        for (String candidate : deepLinkLadder(machineIdentifier, ratingKey, type)) {
            if (startViewIntent(candidate, PLEX_PACKAGE)) {
                // Plex 가 "그 작품"을 못 찾을 때 원인이 우리가 넘긴 값인지 Plex 쪽인지
                // 가르려면 실제로 던진 주소가 필요하다. 시스템 로그는 이 값을 줄인다.
                Log.i(TAG, "Plex 앱으로 보냅니다: " + candidate);
                resolve(callId, "{\"opened\":\"app\"}");
                return;
            }
        }

        Log.i(TAG, "Plex 앱이 링크를 받지 않아 브라우저로 넘깁니다.");
        openExternal(webUrl);
        resolve(callId, "{\"opened\":\"browser\"}");
    }

    /** 재생할 파일을 직접 갖지 않는 묶음인가. 알 수 없으면(null) 재생 가능으로 본다. */
    private boolean isContainer(String type) {
        if (type == null || type.isEmpty()) return false;
        switch (type) {
            case "show": case "season": case "collection": case "artist": case "album":
                return true;
            default:
                return false;
        }
    }

    /**
     * Plex 앱이 깔려 있는가.
     *
     * AndroidManifest 의 &lt;queries&gt; 에 com.plexapp.android 가 선언돼 있어야 한다.
     * 빠지면 API 30+ 에서 항상 NameNotFoundException 이 나 전부 스토어로 간다.
     */
    private boolean isPlexInstalled() {
        try {
            activity.getPackageManager().getPackageInfo(PLEX_PACKAGE, 0);
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            return false;
        }
    }

    /**
     * 앱으로 보낼 후보 주소를 순서대로 만든다. 식별자가 없으면 만들 수 없다.
     *
     * 1순위 `plex://watch/video?uri=…` 는 **Plex 앱 APK 에서 직접 확인한 형식**이다
     * (2026.15.0). 등록된 딥링크 문자열이 두 개뿐이고, 그중 항목을 받는 것은 이것이다.
     * `uri` 값의 형식도 앱 안의 파서 정규식 그대로다 — docs/PLEX_DEEPLINK.md.
     * 에뮬레이터에서 실제로 그 작품이 재생되는 것까지 확인했다.
     *
     * 2순위 app.plex.tv 는 **Plex 앱이 등록하지 않는다**(매니페스트 확인). 남겨둔 것은
     * Plex 가 다시 등록할 경우를 위한 자리이고, 지금은 항상 실패한다. 비용은 예외 하나다.
     */
    private java.util.List<String> deepLinkLadder(
            String machineIdentifier, String ratingKey, String type) {
        java.util.List<String> urls = new java.util.ArrayList<>();
        if (machineIdentifier == null || machineIdentifier.isEmpty()) return urls;
        if (ratingKey == null || ratingKey.isEmpty()) return urls;
        // 재생할 파일이 없는 묶음이다. 재생 명령을 보내면 Plex 가 "Item not known" 으로
        // 실패한다 — 상세 화면을 띄우도록 웹 폴백으로 내려보낸다.
        if (isContainer(type)) {
            Log.i(TAG, "재생 대상이 아닌 종류(" + type + ")라 웹으로 보냅니다.");
            return urls;
        }

        String metadataKey = "/library/metadata/" + ratingKey;
        String encodedKey;
        String encodedUri;
        try {
            encodedKey = java.net.URLEncoder.encode(metadataKey, "UTF-8");
            encodedUri = java.net.URLEncoder.encode(
                "server://" + machineIdentifier + "/com.plexapp.plugins.library" + metadataKey,
                "UTF-8");
        } catch (Exception e) {
            return urls;
        }

        urls.add("plex://watch/video?uri=" + encodedUri);
        urls.add("https://app.plex.tv/desktop/#!/server/" + machineIdentifier
            + "/details?key=" + encodedKey);
        return urls;
    }

    /**
     * ACTION_VIEW 를 던진다. 받아줄 곳이 없으면 false — 예외를 밖으로 내보내지 않는다.
     *
     * @param pkg null 이 아니면 그 패키지만 받게 한다. 브라우저로 새는 것을 막고,
     *            앱으로 갔는지를 실제로 구분할 수 있게 해준다.
     */
    private boolean startViewIntent(String url, String pkg) {
        if (url == null || url.isEmpty()) return false;
        try {
            Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            if (pkg != null) intent.setPackage(pkg);
            activity.startActivity(intent);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * 웹이 준비된 시점에 푸시 토큰을 등록한다.
     *
     * 이 시점이어야 하는 이유: /api/app/push/token 은 인증 게이트 뒤에 있는데,
     * 로그인·프로필 선택을 마치기 전에는 세션 쿠키가 없어 401 이 된다.
     *
     * **토큰이 같아도 매번 보낸다.** 서버는 이 요청의 쿠키를 보고 기기의 프로필을
     * 정하는데(nuplex/app/api/app/push/token/route.ts), 계정을 바꿔도 FCM 토큰은
     * 그대로다. 전에 쓰던 registerIfChanged 는 그럴 때 요청을 통째로 건너뛰어
     * 기기가 이전 프로필에 묶인 채 남았다 — 다음 사람이 이전 사람 앞으로 온 공지를
     * 받았다(docs/plan/active/phase-9-push-badge.md 결함 D).
     * 앱을 켤 때 POST 한 번이 늘어날 뿐이고, 그 대가로 대상이 항상 맞는다.
     */
    private void registerPushTokenIfPossible() {
        try {
            com.google.firebase.messaging.FirebaseMessaging.getInstance().getToken()
                .addOnCompleteListener(task -> {
                    if (task.isSuccessful() && task.getResult() != null) {
                        NuplexTokenRegistrar.register(activity, task.getResult());
                    }
                });
        } catch (Exception e) {
            // Firebase 설정이 없는 빌드. 푸시만 비활성될 뿐 앱은 정상 동작한다.
            Log.i(TAG, "FCM 을 사용할 수 없어 토큰 등록을 건너뜁니다.");
        }
    }

    private void openExternal(String url) {
        if (url == null || url.isEmpty()) return;
        try {
            Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
        } catch (Exception e) {
            Log.w(TAG, "외부 링크를 열지 못했습니다: " + url, e);
        }
    }

    /**
     * 주입된 스크립트의 Promise 를 푼다.
     *
     * @param payload 이미 JSON 으로 직렬화된 리터럴. null 이면 JS 의 null 이 된다.
     */
    private void resolve(int callId, String payload) {
        if (callId == 0) return;  // fire-and-forget 호출
        final String literal = payload == null ? "null" : payload;
        // WebView 조작은 UI 스레드에서만 안전하다. @JavascriptInterface 는 별도
        // 스레드에서 불린다.
        webView.post(() ->
            webView.evaluateJavascript(
                "window.__nuplexBridgeResolve(" + callId + ", " + literal + ");", null));
    }
}
