package com.nugabox.nuplex;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;
import android.webkit.CookieManager;

import org.json.JSONObject;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.TimeZone;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * 푸시 토큰을 서버에 등록·해제한다 (docs/PUSH_PAYLOAD.md 토큰 생명주기).
 *
 * 까다로운 점이 둘 있다.
 *
 * 1. `/api/app/push/token` 은 **인증 게이트 뒤에** 있다. 그런데 네이티브 HTTP 는
 *    웹뷰의 쿠키 저장소를 공유하지 않는다. CookieManager 에서 꺼내 직접 실어야 한다.
 * 2. 그래서 **로그인 전에 부르면 401 이다.** 실패를 정상 흐름으로 취급하고, 웹이
 *    준비를 알릴 때(notifyWebReady) 다시 시도한다.
 */
final class NuplexTokenRegistrar {

    private static final String TAG = "Nuplex";
    private static final String PREFS = "nuplex_push";
    private static final String KEY_DEVICE_ID = "device_id";
    private static final String KEY_LAST_TOKEN = "last_registered_token";

    private static final ExecutorService executor = Executors.newSingleThreadExecutor();

    private NuplexTokenRegistrar() {}

    /**
     * 기기 식별자. 앱을 지웠다 깔면 새 값이 된다 — 서버도 그렇게 전제하고 있다
     * (nuplex/database/0004_push.sql 의 device.device_id 주석).
     */
    static String deviceId(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        String id = prefs.getString(KEY_DEVICE_ID, null);
        if (id == null) {
            id = UUID.randomUUID().toString();
            prefs.edit().putString(KEY_DEVICE_ID, id).apply();
        }
        return id;
    }

    /** 이미 등록한 토큰과 같으면 건너뛴다. 부팅할 때마다 같은 요청을 보낼 이유가 없다. */
    static void registerIfChanged(Context context, String token) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        if (token.equals(prefs.getString(KEY_LAST_TOKEN, null))) return;
        register(context, token);
    }

    static void register(Context context, String token) {
        executor.execute(() -> {
            try {
                JSONObject body = new JSONObject();
                body.put("deviceId", deviceId(context));
                body.put("token", token);
                body.put("platform", "android");
                body.put("appVersion", appVersion(context));
                body.put("locale", Locale.getDefault().toLanguageTag());
                body.put("timezone", TimeZone.getDefault().getID());

                int status = send(context, "POST", body.toString());
                if (status >= 200 && status < 300) {
                    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                        .edit().putString(KEY_LAST_TOKEN, token).apply();
                    Log.i(TAG, "푸시 토큰 등록 완료");
                } else if (status == 401 || status == 403 || (status >= 300 && status < 400)) {
                    // 아직 로그인 전이다. 인증 게이트가 401 대신 /login 으로 리다이렉트(307)
                    // 하기도 한다 — 그걸 실패로 시끄럽게 남기면 진짜 오류가 묻힌다.
                    Log.i(TAG, "아직 로그인 전이라 토큰 등록을 미룹니다 (" + status + ")");
                } else {
                    Log.w(TAG, "푸시 토큰 등록 실패 (" + status + ")");
                }
            } catch (Exception e) {
                Log.w(TAG, "푸시 토큰 등록 중 오류", e);
            }
        });
    }

    /** 로그아웃. 세션이 지워지기 전에 불려야 한다(docs/BRIDGE_CONTRACT.md). */
    static void unregister(Context context) {
        executor.execute(() -> {
            try {
                JSONObject body = new JSONObject();
                body.put("deviceId", deviceId(context));
                int status = send(context, "DELETE", body.toString());
                Log.i(TAG, "푸시 토큰 해제 (" + status + ")");
            } catch (Exception e) {
                Log.w(TAG, "푸시 토큰 해제 중 오류", e);
            } finally {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit().remove(KEY_LAST_TOKEN).apply();
            }
        });
    }

    private static int send(Context context, String method, String payload) throws Exception {
        String base = NuplexPreferences.webBaseUrl(context);
        URL url = new URL(base + "/api/app/push/token");

        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod(method);
        conn.setConnectTimeout(10_000);
        conn.setReadTimeout(10_000);
        // 리다이렉트를 따라가면 로그인 화면 HTML 을 200 으로 받고 등록에 성공한 줄 안다.
        // 미인증은 미인증으로 보여야 다음 기회에 다시 시도한다.
        conn.setInstanceFollowRedirects(false);
        conn.setRequestProperty("Content-Type", "application/json");

        // 네이티브 HTTP 는 웹뷰 쿠키를 모른다. 세션 쿠키를 직접 실어야 인증을 통과한다.
        String cookies = CookieManager.getInstance().getCookie(base);
        if (cookies != null && !cookies.isEmpty()) {
            conn.setRequestProperty("Cookie", cookies);
        }

        conn.setDoOutput(true);
        try (OutputStream out = conn.getOutputStream()) {
            out.write(payload.getBytes(StandardCharsets.UTF_8));
        }

        int status = conn.getResponseCode();
        conn.disconnect();
        return status;
    }

    private static String appVersion(Context context) {
        try {
            return context.getPackageManager()
                .getPackageInfo(context.getPackageName(), 0).versionName;
        } catch (Exception e) {
            return Build.VERSION.RELEASE;
        }
    }
}
