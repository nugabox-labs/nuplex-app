/**
 * 원격 페이지(nuplex 웹)에 주입되는 브릿지 스크립트.
 *
 * ── 왜 이 파일이 따로 있는가 ────────────────────────────────────────────────
 * 셸은 로컬 www/index.html 로 부팅한 뒤 웹뷰를 원격 도메인으로 보낸다(ADR-001).
 * 그 순간 로컬 페이지의 JS 컨텍스트는 사라지므로, src/bridge/expose.ts 가 만든
 * window.NuplexNative 도 함께 사라진다. 원격 페이지에 브릿지를 두려면 네이티브가
 * 문서 시작 시점에 직접 주입하는 수밖에 없다.
 *
 * Capacitor 자체 브릿지에 얹지 않은 이유: iOS 는 WKUserScript 라 origin 과 무관하게
 * 주입되지만, Android 는 주입 허용 origin 이 로컬 앱 주소 하나로 고정돼 있어
 * (Bridge.java 의 addDocumentStartJavaScript) 원격 페이지에는 window.Capacitor 가
 * 아예 없다. 두 플랫폼에서 같은 계약을 보장하려면 우리 채널을 쓰는 편이 확실하다.
 *
 * ── 규칙 ──────────────────────────────────────────────────────────────────
 * · 이 파일은 빌드하지 않는다. 네이티브가 문자열로 읽어 그대로 주입한다.
 *   ES5 문법만 쓰고, import/export 를 쓰지 않는다.
 * · __NUPLEX_*__ 자리표시자는 주입 직전에 네이티브가 치환한다.
 * · 계약: docs/BRIDGE_CONTRACT.md — 메서드를 지우지 않는다.
 * · 이 파일은 shell/public/ 에 있어 www/ 로 그대로 복사되고, cap sync 가 다시
 *   ios/App/App/public/ 와 android/.../assets/public/ 로 옮긴다. 네이티브는 거기서
 *   읽는다. 덕분에 원본이 하나로 유지되고 플랫폼별 사본이 어긋날 일이 없다.
 */
(function () {
  'use strict';

  if (window.NuplexNative) return;

  var PLATFORM = '__NUPLEX_PLATFORM__';
  var pending = {};
  var seq = 0;

  function post(message) {
    if (PLATFORM === 'ios') {
      window.webkit.messageHandlers.nuplexShell.postMessage(message);
    } else {
      window.NuplexShellNative.postMessage(JSON.stringify(message));
    }
  }

  /**
   * 네이티브 호출. 계약상 브릿지 메서드는 웹 화면을 죽이지 않아야 하므로,
   * 채널 자체가 없을 때도 reject 하지 않고 기본값으로 조용히 물러난다.
   */
  function call(method, args, fallback) {
    return new Promise(function (resolve) {
      var id = ++seq;
      pending[id] = resolve;
      try {
        post({ id: id, method: method, args: args || {} });
      } catch (e) {
        delete pending[id];
        resolve(fallback);
      }
    });
  }

  // 네이티브가 결과를 돌려줄 때 부르는 창구.
  window.__nuplexBridgeResolve = function (id, payload) {
    var resolve = pending[id];
    if (!resolve) return;
    delete pending[id];
    resolve(payload);
  };

  window.NuplexNative = {
    bridgeVersion: __NUPLEX_BRIDGE_VERSION__,
    appVersion: '__NUPLEX_APP_VERSION__',
    platform: PLATFORM,

    openInPlex: function (params) {
      return call('openInPlex', params, { opened: 'browser' });
    },

    getPushPermission: function () {
      return call('getPushPermission', {}, 'prompt');
    },
    requestPushPermission: function () {
      return call('requestPushPermission', {}, 'denied');
    },
    getPushToken: function () {
      return call('getPushToken', {}, null);
    },
    clearPushRegistration: function () {
      return call('clearPushRegistration', {}, undefined);
    },

    openExternal: function (url) {
      return call('openExternal', { url: url }, undefined);
    },
    setBadgeCount: function (n) {
      return call('setBadgeCount', { count: n }, undefined);
    },

    // 웹이 라우팅 준비를 마쳤다는 신호. 셸은 이걸 받고서야 대기 중인 푸시 라우트를
    // 흘려보낸다. 응답을 기다릴 필요가 없어 fire-and-forget 이다.
    notifyWebReady: function () {
      try {
        post({ id: 0, method: 'notifyWebReady', args: {} });
      } catch (e) {
        /* 채널이 없으면 할 수 있는 일이 없다 */
      }
    },
  };

  // 네이티브에 주입 사실을 남긴다. 브릿지가 "왜 안 붙었는지" 는 원격 페이지라
  // 웹 로그에 아무것도 남지 않아 추적이 어렵다 — 로그 한 줄이 진단을 좌우한다.
  try {
    post({ id: 0, method: 'bridgeReady', args: { href: String(location.href) } });
  } catch (e) {
    /* 채널이 없으면 어차피 브릿지도 못 쓴다 */
  }

  // 웹이 스크립트 로드 순서에 상관없이 준비 시점을 잡을 수 있게 알린다.
  try {
    window.dispatchEvent(new Event('nuplexnativeready'));
  } catch (e) {
    /* 구형 엔진 대비 — 없어도 window.NuplexNative 는 이미 존재한다 */
  }
})();
