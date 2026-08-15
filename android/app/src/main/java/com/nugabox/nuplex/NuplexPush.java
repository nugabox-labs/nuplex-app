package com.nugabox.nuplex;

import android.Manifest;
import android.app.Activity;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;

import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

/**
 * 알림 권한과 채널 (docs/PUSH_PAYLOAD.md).
 *
 * 푸시 수신·라우팅은 네이티브에서 한다. 웹뷰의 JS 로는 처리할 수 없다 — 앱이 종료된
 * 상태에서 알림을 탭하면 웹뷰가 뜨기도 전에 이벤트가 도착하기 때문이다.
 */
public class NuplexPush {

    private static final String TAG = "Nuplex";
    static final int PERMISSION_REQUEST_CODE = 4001;

    /** docs/PUSH_PAYLOAD.md 의 채널 표와 일치시킬 것. */
    enum Channel {
        NEW_ITEM("new_item", "새 작품"),
        AVAILABLE("available", "시청 가능"),
        // 웹이 android.notification.channel_id 로 "chat" 을 실어 보낸다
        // (nuplex/lib/push/fcm.ts 의 ANDROID_CHANNELS). 앱이 백그라운드일 때는
        // 시스템이 그 채널로 알림을 그리는데, 없는 채널이면 Android 8+ 가 알림을
        // 조용히 버린다. 여기에 없으면 채팅 푸시가 아예 안 뜬다.
        CHAT("chat", "메시지"),
        GENERAL("general", "일반");

        final String id;
        final String label;

        Channel(String id, String label) {
            this.id = id;
            this.label = label;
        }

        static String resolve(String type) {
            if (type == null) return GENERAL.id;
            for (Channel c : values()) {
                if (c.id.equals(type)) return c.id;
            }
            // 구버전 셸이 모르는 type 이 오면 일반 채널로 보낸다. 알림을 버리지 않는다.
            return GENERAL.id;
        }
    }

    /**
     * 채널은 앱 설치 후 한 번만 만들면 되지만, 만드는 것 자체가 멱등이라 매번 부른다.
     * 종류별로 나눠야 사용자가 "새 작품 알림만 끄기" 를 할 수 있다 — 한 채널에 몰면
     * 하나라도 거슬리는 순간 전부 꺼진다.
     */
    static void createChannels(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;

        NotificationManager manager = context.getSystemService(NotificationManager.class);
        if (manager == null) return;

        for (Channel channel : Channel.values()) {
            manager.createNotificationChannel(
                new NotificationChannel(channel.id, channel.label, NotificationManager.IMPORTANCE_DEFAULT)
            );
        }
    }

    /**
     * 'granted' | 'denied' | 'prompt'.
     *
     * Android 12 이하에는 런타임 권한이 없어 항상 허용으로 나온다. 그래서 "설정에서
     * 껐는지" 는 알 수 없고, areNotificationsEnabled() 로 한 번 더 확인한다.
     */
    static String permissionState(Context context) {
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        boolean enabled = manager == null || manager.areNotificationsEnabled();

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return enabled ? "granted" : "denied";
        }

        int status = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS);
        if (status == PackageManager.PERMISSION_GRANTED) {
            return enabled ? "granted" : "denied";
        }
        // 한 번도 묻지 않았는지, 사용자가 거절했는지는 구분할 수 없다.
        // shouldShowRequestPermissionRationale 이 false 라고 "안 물어봤다" 는 뜻은 아니다
        // (영구 거절도 false 다). 물어봐도 되는 상태면 prompt 로 본다.
        return "prompt";
    }

    /** 권한 다이얼로그는 온보딩에서 사용자가 동의를 누른 뒤에만 띄운다. */
    static void requestPermission(Activity activity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            // 요청할 권한 자체가 없다. 시스템 설정에서 껐다면 앱이 할 수 있는 일이 없다.
            Log.i(TAG, "Android 12 이하 — POST_NOTIFICATIONS 요청이 필요 없습니다.");
            return;
        }
        ActivityCompat.requestPermissions(
            activity, new String[] { Manifest.permission.POST_NOTIFICATIONS }, PERMISSION_REQUEST_CODE);
    }
}
