package com.nugabox.nuplex;

import android.app.Activity;
import android.content.Intent;
import android.provider.Settings;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

/**
 * TV 로 쏘기 — Plex Companion (Android).
 *
 * 근거와 함정은 `docs/PLEX_CAST.md`. 코드에 직접 걸리는 것만 옮겨 적는다.
 *
 * · **플레이어와 같은 WiFi 에 있을 때만 된다.** Plex 가 광고하는 플레이어 주소는
 *   사설 IP 하나뿐이고 relay 가 없다. 그래서 목록은 실제로 닿아 본 것만 담는다.
 * · **X-Plex-Target-Client-Identifier 는 맨 뒤에 붙인다.** 중간에 두면 값이 같아도
 *   "don't match" 로 거절당한다. 순서를 바꾸지 말 것.
 * · **TV 에서 Plex 앱이 떠 있어야 한다.** Companion 서버가 그 앱 안에 있어서
 *   깨울 방법이 없다.
 *
 * **AirPlay 는 Android 에 없다.** 유튜브 같은 앱의 캐스트 버튼은 Google Cast
 * (크롬캐스트)이고 Apple TV 는 그 수신기가 아니다. 여기서 여는 것은 시스템 화면
 * 미러링 패널이며, 목록에 뜨는 것도 Cast 계열뿐이다. Apple TV 로 보내려면
 * 이 클래스의 Companion 캐스트를 써야 한다.
 *
 * 토큰은 보관하지 않는다. 매 호출마다 웹에서 받아 쓰고 버린다.
 */
final class NuplexCast {

    private static final String TAG = "Nuplex";

    /** 같은 랜이라 넉넉하다. 못 닿는 후보를 오래 붙들지 않는 것이 더 중요하다. */
    private static final int TIMEOUT_MS = 2500;

    /** 이 앱을 식별하는 컨트롤러 ID. 플레이어가 세션을 구분하는 데만 쓴다. */
    private static final String CONTROLLER_ID = "nuplex-shell-android";

    /** Plex 는 컨트롤러마다 증가하는 commandID 를 기대한다. */
    private static int commandSeq = 0;

    private static final ExecutorService POOL = Executors.newCachedThreadPool();

    private NuplexCast() {}

    private static synchronized int nextCommandId() {
        return ++commandSeq;
    }

    // --- 후보 확인 -----------------------------------------------------------

    /**
     * 웹이 준 후보 중 **지금 닿는 것만** 골라 돌려준다.
     *
     * 후보 목록은 웹이 plex.tv 에서 받아 넘긴다. 셸이 직접 plex.tv 를 부르지 않는
     * 이유는 계정 토큰을 셸에 두지 않기 위함이다 — 조회는 서버 몫이다.
     *
     * 전부 병렬로 찔러 보고 응답한 것만 남긴다. 느린 후보가 나머지를 붙들지 않는다.
     */
    static void listTargets(JSONArray candidates, String token, Callback callback) {
        if (token == null || token.isEmpty() || candidates == null || candidates.length() == 0) {
            callback.done("{\"targets\":[]}");
            return;
        }

        POOL.execute(() -> {
            List<java.util.concurrent.Future<JSONObject>> futures = new ArrayList<>();

            for (int i = 0; i < candidates.length(); i++) {
                JSONObject candidate = candidates.optJSONObject(i);
                if (candidate == null) continue;
                final String id = candidate.optString("id", "");
                final String uri = candidate.optString("uri", "");
                final String name = candidate.optString("name", "TV");
                if (id.isEmpty() || uri.isEmpty()) continue;

                futures.add(POOL.submit(() -> probe(uri, id, name, token)));
            }

            JSONArray reachable = new JSONArray();
            for (java.util.concurrent.Future<JSONObject> future : futures) {
                try {
                    JSONObject found = future.get(TIMEOUT_MS + 500L, TimeUnit.MILLISECONDS);
                    if (found != null) reachable.put(found);
                } catch (Exception ignored) {
                    // 못 닿는 후보다. 목록에서 빠지는 것이 곧 정답이다.
                }
            }

            Log.i(TAG, "캐스트 후보 " + candidates.length() + "개 중 " + reachable.length() + "개가 닿습니다.");
            JSONObject out = new JSONObject();
            try {
                out.put("targets", reachable);
            } catch (Exception ignored) {
            }
            callback.done(out.toString());
        });
    }

    /** 플레이어에 /resources 를 물어 살아 있는지 본다. 재생은 건드리지 않는다. */
    private static JSONObject probe(String uri, String fallbackId, String name, String token) {
        HttpURLConnection conn = null;
        try {
            URL url = new URL(uri + "/resources?X-Plex-Token=" + enc(token));
            conn = (HttpURLConnection) url.openConnection();
            conn.setConnectTimeout(TIMEOUT_MS);
            conn.setReadTimeout(TIMEOUT_MS);
            conn.setRequestMethod("GET");

            if (conn.getResponseCode() != 200) return null;
            String body = read(conn.getInputStream());
            if (!body.contains("<Player")) return null;

            JSONObject target = new JSONObject();
            // 플레이어가 스스로 보고하는 ID 가 진짜다. plex.tv 등록값과 다를 수 있다.
            target.put("id", machineIdentifier(body, fallbackId));
            target.put("name", name);
            target.put("uri", uri);
            return target;
        } catch (Exception e) {
            return null;
        } finally {
            if (conn != null) conn.disconnect();
        }
    }

    private static String machineIdentifier(String xml, String fallback) {
        final String key = "machineIdentifier=\"";
        int start = xml.indexOf(key);
        if (start < 0) return fallback;
        start += key.length();
        int end = xml.indexOf('"', start);
        if (end <= start) return fallback;
        return xml.substring(start, end);
    }

    // --- 재생 명령 -----------------------------------------------------------

    /**
     * 플레이어에 재생을 시킨다.
     *
     * 형식은 실기기로 검증한 것이다(docs/PLEX_CAST.md §6). **파라미터 순서를 지킬 것** —
     * 대상 식별자가 마지막이어야 한다.
     */
    static void play(JSONObject args, Callback callback) {
        final String uri = args.optString("uri", "");
        final String targetId = args.optString("targetId", "");
        final String token = args.optString("token", "");
        final String machineIdentifier = args.optString("machineIdentifier", "");
        final String ratingKey = args.optString("ratingKey", "");

        if (uri.isEmpty() || targetId.isEmpty() || token.isEmpty()
                || machineIdentifier.isEmpty() || ratingKey.isEmpty()) {
            callback.done("{\"ok\":false,\"error\":\"missing-params\"}");
            return;
        }

        final String address = args.optString("serverAddress", "");
        final int port = args.optInt("serverPort", 443);
        final String proto = args.optString("serverProtocol", "https");
        final int offset = args.optInt("offset", 0);

        POOL.execute(() -> {
            HttpURLConnection conn = null;
            try {
                // 순서가 곧 사양이다 — 대상 식별자를 맨 뒤에 둔다.
                String query = "address=" + enc(address)
                    + "&port=" + port
                    + "&protocol=" + enc(proto)
                    + "&machineIdentifier=" + enc(machineIdentifier)
                    + "&key=" + enc("/library/metadata/" + ratingKey)
                    + "&offset=" + offset
                    + "&commandID=" + nextCommandId()
                    + "&X-Plex-Client-Identifier=" + CONTROLLER_ID
                    + "&X-Plex-Token=" + enc(token)
                    + "&X-Plex-Target-Client-Identifier=" + enc(targetId);

                URL url = new URL(uri + "/player/playback/playMedia?" + query);
                conn = (HttpURLConnection) url.openConnection();
                conn.setConnectTimeout(TIMEOUT_MS);
                conn.setReadTimeout(TIMEOUT_MS);
                conn.setRequestMethod("GET");
                // 헤더로도 함께 보낸다. 쿼리만으로 되는 것을 확인했지만 플레이어 구현이
                // 헤더만 보는 경우를 대비한 것이다. 같은 값이라 충돌하지 않는다.
                conn.setRequestProperty("X-Plex-Target-Client-Identifier", targetId);
                conn.setRequestProperty("X-Plex-Client-Identifier", CONTROLLER_ID);

                int status = conn.getResponseCode();
                if (status == 200) {
                    Log.i(TAG, "캐스트 성공: " + ratingKey + " → " + targetId);
                    callback.done("{\"ok\":true}");
                    return;
                }

                // Plex 는 실패 이유를 본문에 적어 준다. 그대로 넘겨 웹이 안내하게 한다.
                String body = read(conn.getErrorStream());
                Log.w(TAG, "캐스트 실패(" + status + "): " + body);
                JSONObject out = new JSONObject();
                out.put("ok", false);
                out.put("error", "rejected");
                out.put("status", status);
                out.put("detail", body.length() > 300 ? body.substring(0, 300) : body);
                callback.done(out.toString());
            } catch (Exception e) {
                // 폰이 그 랜을 떠났거나 TV 가 꺼졌다.
                Log.w(TAG, "캐스트 실패(연결): " + e.getMessage());
                callback.done("{\"ok\":false,\"error\":\"unreachable\"}");
            } finally {
                if (conn != null) conn.disconnect();
            }
        });
    }

    // --- 미러링 패널 ---------------------------------------------------------

    /**
     * 시스템 화면 미러링(캐스트) 패널을 연다.
     *
     * **iOS 의 AirPlay 피커와 같은 것이 아니다.** Android 에는 앱이 부를 수 있는
     * 미러링 피커 API 가 없어서, 할 수 있는 최선이 시스템 설정의 캐스트 패널을
     * 여는 것이다. 여기 뜨는 기기는 Google Cast 계열이라 **Apple TV 는 안 나온다.**
     * 기기에 따라 이 화면 자체가 없을 수도 있어 실패를 정상 경로로 다룬다.
     */
    static void showRoutePicker(Activity activity, Callback callback) {
        try {
            Intent intent = new Intent(Settings.ACTION_CAST_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
            callback.done("{\"shown\":true}");
        } catch (Exception e) {
            Log.w(TAG, "캐스트 설정 화면을 열지 못했습니다: " + e.getMessage());
            callback.done("{\"shown\":false}");
        }
    }

    // --- 잡동사니 -----------------------------------------------------------

    private static String enc(String value) {
        try {
            return URLEncoder.encode(value, "UTF-8");
        } catch (Exception e) {
            return value;
        }
    }

    private static String read(InputStream stream) {
        if (stream == null) return "";
        try (java.io.BufferedReader reader = new java.io.BufferedReader(
                new java.io.InputStreamReader(stream, StandardCharsets.UTF_8))) {
            StringBuilder out = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) out.append(line);
            return out.toString();
        } catch (Exception e) {
            return "";
        }
    }

    /** 결과를 JS 리터럴 문자열로 넘긴다. NuplexBridgeApi.resolve 가 그대로 삽입한다. */
    interface Callback {
        void done(String jsonLiteral);
    }
}
