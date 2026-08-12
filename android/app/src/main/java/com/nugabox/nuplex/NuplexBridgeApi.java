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
    private static final int BRIDGE_VERSION = 1;

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
                openInPlex(callId, args.optString("webUrl", null));
                break;

            // TODO(phase-5): 푸시 구현과 함께 채운다. 계약을 먼저 세워두지 않으면
            // 웹이 bridgeVersion 만 보고 부르다가 TypeError 로 화면이 죽는다.
            case "getPushPermission":
                resolve(callId, "\"prompt\"");
                break;
            case "requestPushPermission":
                resolve(callId, "\"denied\"");
                break;
            case "getPushToken":
            case "clearPushRegistration":
                resolve(callId, null);
                break;

            case "bridgeReady":
                // 주입 성공 로그. 이 줄이 안 보이면 브릿지가 안 붙은 것이다.
                Log.i(TAG, "브릿지 주입됨: " + args.optString("href", "?"));
                break;

            case "notifyWebReady":
                // TODO(phase-5): 대기 중인 푸시 라우트를 흘려보낸다.
                break;

            default:
                // 신버전 웹이 구버전 셸에 없는 메서드를 부른 경우다.
                Log.w(TAG, "알 수 없는 브릿지 메서드: " + method);
                resolve(callId, null);
        }
    }

    /**
     * Plex 로 이동한다 (ADR-003).
     *
     * https://app.plex.tv/... 링크를 그대로 넘긴다. Plex 앱이 App Links 로 가로채고,
     * 없으면 브라우저로 간다. plex:// 커스텀 스킴은 공식 문서가 없어 쓰지 않는다.
     *
     * FLAG_ACTIVITY_REQUIRE_NON_BROWSER 로 "앱이 아니면 열지 마라" 를 먼저 시도한다.
     * 그래야 앱으로 갔는지 브라우저로 갔는지를 실제로 구분할 수 있다. 이게 없으면
     * 안드로이드가 조용히 브라우저를 띄우고 우리는 앱이 열린 줄 안다.
     */
    private void openInPlex(int callId, String webUrl) {
        if (webUrl == null || webUrl.isEmpty()) {
            resolve(callId, "{\"opened\":\"browser\"}");
            return;
        }

        // TODO(verify): plex:// 커스텀 스킴은 공식 문서가 없어 형식을 확인하기 전에는
        // 구현하지 않는다. 확인 절차는 docs/PLEX_DEEPLINK.md 참고.

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            try {
                Intent appOnly = new Intent(Intent.ACTION_VIEW, Uri.parse(webUrl));
                appOnly.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                appOnly.addFlags(Intent.FLAG_ACTIVITY_REQUIRE_NON_BROWSER);
                activity.startActivity(appOnly);
                resolve(callId, "{\"opened\":\"app\"}");
                return;
            } catch (Exception e) {
                // 앱이 없거나 링크를 자기 것으로 등록하지 않았다. 브라우저로 간다.
                Log.i(TAG, "Plex 앱으로 열지 못해 브라우저로 넘깁니다.");
            }
        }

        openExternal(webUrl);
        resolve(callId, "{\"opened\":\"browser\"}");
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
