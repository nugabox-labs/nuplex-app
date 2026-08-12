package com.nugabox.nuplex;

import android.util.Log;
import android.webkit.WebView;

/**
 * 푸시 라우트 대기열.
 *
 * 앱이 완전히 종료된 상태에서 알림을 탭하면, 라우트가 **웹뷰가 준비되기 전에**
 * 도착한다. 그대로 loadUrl 을 부르면 부팅 시퀀스가 그 위를 덮어써서 알림이 홈으로
 * 가버린다 — 이 기능에서 가장 자주 깨지는 지점이다.
 *
 * 그래서 라우트를 하나 들고 있다가, 웹이 notifyWebReady() 를 부른 뒤에 이동시킨다.
 */
public final class NuplexRouteQueue {

    private static final String TAG = "Nuplex";

    /** 마지막 라우트 하나만 들고 있는다. 알림을 연달아 탭하면 마지막 것이 의도다. */
    private static String pendingRoute;
    private static boolean webReady;

    private NuplexRouteQueue() {}

    /** 알림 탭으로 라우트가 도착했다. */
    public static synchronized void offer(String route, WebView webView, String webBaseUrl) {
        if (route == null || route.isEmpty()) return;

        if (webReady && webView != null) {
            navigate(webView, webBaseUrl, route);
            return;
        }
        Log.i(TAG, "웹 준비 전이라 라우트를 대기열에 넣습니다: " + route);
        pendingRoute = route;
    }

    /** 웹이 라우팅 준비를 마쳤다(notifyWebReady). */
    public static synchronized void flush(WebView webView, String webBaseUrl) {
        webReady = true;
        if (pendingRoute == null || webView == null) return;

        String route = pendingRoute;
        pendingRoute = null;
        navigate(webView, webBaseUrl, route);
    }

    /**
     * 웹뷰가 웹 도메인을 벗어났다(로그아웃 등). 다음 준비 신호를 기다린다.
     * 이걸 안 하면 로그인 화면 위로 라우트를 밀어넣게 된다.
     */
    public static synchronized void reset() {
        webReady = false;
    }

    private static void navigate(WebView webView, String webBaseUrl, String route) {
        // route 는 경로 문자열이다. 도메인은 셸이 붙인다 — 도메인이 바뀌어도 과거에
        // 발송된 알림이 깨지지 않게 하기 위함이다(docs/PUSH_PAYLOAD.md).
        final String url = webBaseUrl + route;
        Log.i(TAG, "푸시 라우트로 이동: " + url);
        webView.post(() -> webView.loadUrl(url));
    }
}
