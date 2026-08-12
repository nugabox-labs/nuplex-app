package com.nugabox.nuplex;

import android.util.Log;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;

import com.getcapacitor.Bridge;
import com.getcapacitor.BridgeWebViewClient;

/**
 * 웹 로드 실패를 우리 화면으로 돌린다.
 *
 * 이게 없으면 WebView 기본 에러 페이지("Webpage not available", 흰 배경에 영어)가
 * 그대로 노출된다. 설계 명세 §9.4 가 금지하는 상태다 — 모든 실패 경로에 사용자가
 * 이해할 수 있는 화면이 있어야 한다.
 *
 * 서버가 돌려준 webBaseUrl 에 기기가 닿지 못하는 경우(사내망·도메인 이전·서버 다운)가
 * 실제로 생긴다. 에뮬레이터 테스트에서 이 화면을 만나 추가했다.
 */
public class NuplexWebViewClient extends BridgeWebViewClient {

    private static final String TAG = "Nuplex";
    private static final String OFFLINE_URL = "https://localhost/offline.html";

    private final Bridge bridge;

    public NuplexWebViewClient(Bridge bridge) {
        super(bridge);
        this.bridge = bridge;
    }

    @Override
    public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
        super.onReceivedError(view, request, error);

        // 페이지 안의 이미지 하나가 실패했다고 오프라인 화면으로 보내면 안 된다.
        if (!request.isForMainFrame()) return;

        String failed = request.getUrl() != null ? request.getUrl().toString() : "?";
        if (failed.startsWith(OFFLINE_URL)) return;  // 오프라인 화면 자체가 실패한 경우

        Log.w(TAG, "웹 로드 실패 → 오프라인 화면으로: " + failed);

        // 웹이 죽은 동안 도착한 푸시 라우트를 밀어넣지 않도록 준비 상태를 되돌린다.
        NuplexRouteQueue.reset();
        view.post(() -> view.loadUrl(OFFLINE_URL));
    }

    /** Capacitor 의 기본 클라이언트를 이것으로 바꾼다. */
    static void install(Bridge bridge) {
        bridge.setWebViewClient(new NuplexWebViewClient(bridge));
    }
}
