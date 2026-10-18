package com.intent.intent_app.constants;

/**
 * Centralized, type-safe constants for SharedPreferences keys and system IDs.
 * Automatically resolves Flutter SharedPreferences naming conventions.
 */
public final class IntentConstants {
    private IntentConstants() {}

    // ── SharedPreferences File Names ──
    public static final String PREFS_FLUTTER = "FlutterSharedPreferences";
    public static final String PREFS_ADAPTIVE_WEIGHTS = "intent_adaptive_weights";

    // ── Preference Keys (Flutter Prefix: "flutter.") ──
    public static final String KEY_SMART_MODE = "smart_mode_active";
    public static final String KEY_ENGINE_TYPE = "engine_type"; // 0 = Heuristic, 1 = Neural
    public static final String KEY_BUFFER_INTERVAL_MINS = "buffer_interval_minutes";
    public static final String KEY_BUFFER_INTERVAL_HOURS = "buffer_interval";
    public static final String KEY_BUFFER_MAX_LINES = "buffer_max_lines";
    public static final String KEY_HISTORY_RETENTION_DAYS = "history_retention_days";
    public static final String KEY_ABSOLUTE_VIP = "absolute_vip_keywords";
    public static final String KEY_URGENT_KEYWORDS = "urgent_keywords";
    public static final String KEY_BUFFER_KEYWORDS = "buffer_keywords";
    public static final String KEY_BLOCK_KEYWORDS = "block_keywords";
    public static final String KEY_SOCIAL_MEDIA_PACKAGES = "social_media_packages";
    public static final String KEY_IGNORED_PACKAGES = "ignored_packages";
    public static final String KEY_DRIVE_SPEED_THRESHOLD = "drive_speed_threshold";

    // ── Notification Channel IDs ──
    public static final String CHANNEL_BUFFER = "intent_buffer_channel";
    public static final String CHANNEL_DRIVING = "driving_mode_channel";
    public static final String CHANNEL_SUMMARY = "intent_summary_channel";

    // ── Notification System IDs ──
    public static final int NOTIFICATION_ID_BUFFER_INBOX = 1001;
    public static final int NOTIFICATION_ID_DRIVING = 9999;
    public static final int NOTIFICATION_ID_SUMMARY = 24680;
    public static final int NOTIFICATION_ID_EOD = 24681;

    // ── Broadcast Actions ──
    public static final String ACTION_SYNC_KEYWORDS = "com.intent.intent_app.SYNC_KEYWORDS";

    /**
     * Resolves a key by checking the "flutter." prefixed key first, then fallback to raw key.
     */
    public static Object getFlutterPref(android.content.SharedPreferences prefs, String baseKey) {
        if (prefs == null) return null;
        Object val = prefs.getAll().get("flutter." + baseKey);
        if (val != null) return val;
        return prefs.getAll().get(baseKey);
    }
}
