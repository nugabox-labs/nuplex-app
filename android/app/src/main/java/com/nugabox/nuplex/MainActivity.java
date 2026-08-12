package com.nugabox.nuplex;

import android.os.Bundle;
import android.util.Log;
import android.webkit.WebView;

import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;

import com.getcapacitor.BridgeActivity;

/**
 * 셸 브릿지를 원격 페이지에 주입한다.
 *
 * Capacitor 자체 브릿지는 주입 허용 origin 이 로컬 앱 주소 하나로 고정돼 있어
 * (Bridge.addDocumentStartJavaScript), 웹뷰가 nuplex 웹으로 이동하면 그 페이지에는
 * window.Capacitor 조차 없다. iOS 는 WKUserScript 라 origin 을 안 가리지만 Android 는
 * 가린다 — 두 플랫폼에서 같은 계약을 보장하려고 우리 채널을 따로 놓는다.
 *
 * 주입 스크립트 원본은 shell/public/nuplex-bridge.js 하나이고,
 * 빌드 → cap sync 를 거쳐 assets/public/ 으로 들어온다.
 *
 * 계약: docs/BRIDGE_CONTRACT.md
 */
public class MainActivity extends BridgeActivity {

    private static final String TAG = "Nuplex";

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        WebView webView = getBridge().getWebView();
        NuplexBridgeApi api = new NuplexBridgeApi(this, webView);

        // 네이티브 수신 창구. 이 인터페이스는 origin 을 가리지 않으므로,
        // capacitor.config.ts 의 allowNavigation 이 사실상의 방어선이다.
        // 그 목록에 신뢰할 수 없는 도메인을 넣지 말 것.
        webView.addJavascriptInterface(api, "NuplexShellNative");

        String script = api.buildBridgeScript();
        if (script == null) return;

        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            // Capacitor 가 allowNavigation 도메인까지 포함해 만들어 둔 origin 목록을
            // 그대로 쓴다. 목록을 두 벌로 관리하면 반드시 어긋난다.
            WebViewCompat.addDocumentStartJavaScript(
                webView,
                script,
                getBridge().getAllowedOriginRules()
            );
        } else {
            // WebView 89 미만. 문서 시작 시점에 주입할 방법이 없다. 여기서 억지로
            // 한 번 넣어봐야 첫 페이지에만 붙고 이동하면 사라져, 웹 입장에서는
            // "있다가 없어지는 브릿지" 가 된다 — 아예 없는 편이 낫다.
            // 웹은 브릿지를 optional 로 다루므로 앱은 그대로 동작한다.
            Log.w(TAG, "WebView 가 DOCUMENT_START_SCRIPT 를 지원하지 않아 브릿지를 주입하지 않습니다.");
        }
    }
}
