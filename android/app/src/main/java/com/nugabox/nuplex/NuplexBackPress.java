package com.nugabox.nuplex;

import android.webkit.WebView;
import android.widget.Toast;

import androidx.activity.OnBackPressedCallback;
import androidx.appcompat.app.AppCompatActivity;

/**
 * 하드웨어 · 제스처 뒤로가기.
 *
 * 기본 동작은 "앱 종료" 다. 웹뷰 앱에서 그대로 두면 목록에서 상세로 들어갔다가
 * 뒤로 가려는 순간 앱이 꺼진다.
 *
 * 웹뷰의 JS 로 처리할 수 없다 — 원격 페이지에는 Capacitor App 플러그인의 backButton
 * 이벤트가 도달하지 않는다(ADR-004 와 같은 이유). 그래서 네이티브에서 처리한다.
 *
 * 루트에서는 곧바로 끄지 않고 "한 번 더 누르면 종료" 로 한 번 막는다. 다이얼로그를
 * 띄우는 방법도 있지만, 뒤로가기 한 번에 모달이 뜨는 것은 성가시다.
 */
final class NuplexBackPress {

    /** 이 시간 안에 다시 누르면 종료한다. */
    private static final long EXIT_WINDOW_MS = 2000;

    private NuplexBackPress() {}

    static void install(AppCompatActivity activity, WebView webView) {
        activity.getOnBackPressedDispatcher().addCallback(activity, new OnBackPressedCallback(true) {
            private long lastPressedAt = 0;

            @Override
            public void handleOnBackPressed() {
                if (webView.canGoBack()) {
                    webView.goBack();
                    return;
                }

                long now = System.currentTimeMillis();
                if (now - lastPressedAt < EXIT_WINDOW_MS) {
                    // 콜백을 끄고 다시 dispatcher 에 넘기는 방법은 통하지 않는다.
                    // Capacitor 가 등록해 둔 콜백이 그걸 받아 삼켜버려서 앱이 안 꺼진다.
                    // 직접 끝내는 편이 동작도 의도도 분명하다.
                    activity.finish();
                    return;
                }

                lastPressedAt = now;
                Toast.makeText(activity, "한 번 더 누르면 종료됩니다", Toast.LENGTH_SHORT).show();
            }
        });
    }
}
