package com.nugabox.nuplex;

import android.content.Context;
import android.content.SharedPreferences;

/**
 * 셸 JS 가 남긴 값을 네이티브에서 읽는다.
 *
 * @capacitor/preferences 는 SharedPreferences 파일 "CapacitorStorage" 에 키를 그대로
 * 저장한다. 여기에 기대는 것은 Capacitor 의 내부 구현에 기대는 것이므로,
 * 키 이름은 src/config/constants.ts 의 STORAGE_KEYS 와 반드시 함께 고친다.
 */
final class NuplexPreferences {

    private static final String FILE = "CapacitorStorage";
    private static final String KEY_WEB_BASE_URL = "nuplex.webBaseUrl.v1";

    /** 원격 설정을 아직 한 번도 못 받았을 때 쓰는 값. constants.ts 와 같아야 한다. */
    private static final String DEFAULT_WEB_BASE_URL = "https://nuplex.nugabox.com";

    private NuplexPreferences() {}

    static String webBaseUrl(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE);
        String value = prefs.getString(KEY_WEB_BASE_URL, null);
        if (value == null || value.isEmpty()) return DEFAULT_WEB_BASE_URL;
        // 끝의 슬래시가 남아 있으면 route 를 붙일 때 // 가 된다.
        return value.replaceAll("/+$", "");
    }
}
