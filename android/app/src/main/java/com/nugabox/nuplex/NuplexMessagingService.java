package com.nugabox.nuplex;

import android.app.Notification;
import android.app.PendingIntent;
import android.content.Intent;
import android.util.Log;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * FCM 수신 (docs/PUSH_PAYLOAD.md).
 *
 * 알림을 여기서 직접 그린다. 서버가 `notification` 필드를 함께 보내면 앱이 백그라운드일
 * 때 시스템이 대신 그려주지만, 그러면 **탭했을 때 route 를 실을 수 없다** — 시스템이
 * 만든 알림은 그냥 런처 인텐트로 앱을 열 뿐이다. 그래서 우리가 만든다.
 */
public class NuplexMessagingService extends FirebaseMessagingService {

    private static final String TAG = "Nuplex";

    /** 알림마다 다른 requestCode 를 줘야 PendingIntent 가 서로 덮어쓰지 않는다. */
    private static final AtomicInteger requestCodeSeq = new AtomicInteger(1);

    @Override
    public void onNewToken(String token) {
        super.onNewToken(token);
        Log.i(TAG, "FCM 토큰이 갱신되었습니다.");
        // 로그인 상태가 아니면 등록이 401 로 실패한다. 그건 정상이다 —
        // 다음 부팅에서 웹 준비 신호와 함께 다시 시도한다.
        NuplexTokenRegistrar.register(getApplicationContext(), token);
    }

    @Override
    public void onMessageReceived(RemoteMessage message) {
        Map<String, String> data = message.getData();

        // 라우팅 값은 전부 data 에 담기로 계약돼 있다(docs/PUSH_PAYLOAD.md §설계 원칙).
        String route = data.get("route");
        if (route == null || route.isEmpty()) {
            Log.w(TAG, "route 없는 알림입니다. 홈으로 보냅니다.");
            route = "/";
        }

        String title = value(message, data, "title");
        String body = value(message, data, "body");
        if (title == null && body == null) {
            // 표시할 내용이 없는 사일런트 푸시. 알림을 만들지 않는다.
            Log.i(TAG, "표시 내용이 없는 메시지입니다.");
            return;
        }

        show(route, title, body, data.get("type"), data.get("collapseKey"));
    }

    private String value(RemoteMessage message, Map<String, String> data, String key) {
        RemoteMessage.Notification notification = message.getNotification();
        if (notification != null) {
            String fromNotification = "title".equals(key) ? notification.getTitle() : notification.getBody();
            if (fromNotification != null) return fromNotification;
        }
        return data.get(key);
    }

    private void show(String route, String title, String body, String type, String collapseKey) {
        Intent intent = new Intent(this, MainActivity.class);
        // singleTask 라 이미 떠 있으면 onNewIntent 로, 아니면 콜드 스타트로 들어간다.
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        intent.putExtra(MainActivity.EXTRA_ROUTE, route);

        PendingIntent pending = PendingIntent.getActivity(
            this,
            requestCodeSeq.getAndIncrement(),
            intent,
            // FLAG_IMMUTABLE 은 Android 12+ 필수. UPDATE_CURRENT 를 함께 줘야 새 route 가 반영된다.
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        NotificationCompat.Builder builder =
            new NotificationCompat.Builder(this, NuplexPush.Channel.resolve(type))
                // 흰색 실루엣 아이콘. 앱 아이콘을 쓰면 회색 사각형으로 뭉개진다.
                .setSmallIcon(R.drawable.ic_stat_nuplex)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setDefaults(Notification.DEFAULT_ALL)
                .setContentIntent(pending);

        // 같은 종류의 알림은 하나로 묶는다. 라이브러리 동기화 후 알림이 우수수
        // 쌓이는 것을 막는다.
        int notificationId = collapseKey != null ? collapseKey.hashCode() : requestCodeSeq.get();

        try {
            NotificationManagerCompat.from(this).notify(notificationId, builder.build());
        } catch (SecurityException e) {
            // POST_NOTIFICATIONS 권한이 없다. 사용자가 거절한 상태이므로 조용히 넘어간다.
            Log.i(TAG, "알림 권한이 없어 표시하지 않습니다.");
        }
    }
}
