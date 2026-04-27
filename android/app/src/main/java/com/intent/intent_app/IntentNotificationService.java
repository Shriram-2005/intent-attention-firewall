package com.intent.intent_app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.graphics.drawable.Icon;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;

import android.app.usage.UsageEvents;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Iterator;
import java.util.LinkedList;
import android.os.Vibrator;
import android.os.VibrationEffect;
import android.graphics.Color;

public class IntentNotificationService extends NotificationListenerService {

    private static final String TAG = "IntentNotificationSvc";
    private IntentBrain intentBrain;

    // Social Media apps to track Context-Aware Distraction State
    private static final List<String> SOCIAL_MEDIA_PACKAGES = Arrays.asList(
            "com.instagram.android",
            "com.zhiliaoapp.musically", // TikTok
            "com.twitter.android",
            "com.facebook.katana",
            "com.snapchat.android",
            "com.reddit.frontpage",
            "tv.twitch.android",
            "com.pinterest",
            "com.google.android.youtube"
    );

    // High-speed volatility RAM cache to hold Deep Linking Portals
    public static final ConcurrentHashMap<Long, PendingIntent> pendingIntentCache = new ConcurrentHashMap<>();
    private static final int MAX_CACHE_SIZE = 500;
    private final LinkedList<CharSequence> bufferInbox = new LinkedList<>();

    // Ignore core OS noise but allow EVERYTHING else to be analyzed
    private static final List<String> IGNORED_PACKAGES = Arrays.asList(
            "android",
            "com.android.systemui",
            "com.android.phone",
            "com.android.settings",
            "com.google.android.apps.nexuslauncher", // Pixel Launcher
            "com.sec.android.app.launcher" // Samsung Launcher
    );

    @Override
    public void onCreate() {
        super.onCreate();
        Log.i(TAG, "Intent Notification Interceptor Service started. Initializing Brain...");
        intentBrain = new IntentBrain(this);
        
        // Ignite the low-power velocity observer securely in the background
        com.intent.intent_app.DriveSafetyEngine.getInstance(this).startBackgroundTracking();
        
        createBufferChannel();
    }

    private void createBufferChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    "intent_buffer_channel",
                    "Intent Buffer",
                    NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Silently grounds your non-urgent notifications.");
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        if (sbn == null) return;
        
        long interceptTimestamp = System.currentTimeMillis();
        
        try {
            // Read active toggle from Flutter's SharedPreferences bridge
            android.content.SharedPreferences prefs = getApplicationContext().getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE);
            boolean isSmartModeActive = prefs.getBoolean("flutter.smart_mode_active", true);
            if (!isSmartModeActive) {
                return; // Completely skip heuristic logic and allow notification through natively
            }

            String packageName = sbn.getPackageName();

            // 1. Filter out system notifications and self-feedback loops
            if (packageName == null || packageName.equals(getPackageName()) || IGNORED_PACKAGES.contains(packageName) || packageName.startsWith("com.android.providers")) {
                return;
            }

            // 1.5 Safety validation to never interfere with un-clearable core tasks
            if (!sbn.isClearable()) {
                return;
            }

            // 2. Extract Notification Content
            Notification notification = sbn.getNotification();
            if (notification == null || notification.extras == null) return;

            // Filter out ongoing notifications (Music players, timers, foreground connections)
            if ((notification.flags & Notification.FLAG_ONGOING_EVENT) != 0 || 
                (notification.flags & Notification.FLAG_FOREGROUND_SERVICE) != 0) {
                return;
            }

            // Detect if this is a group summary to prevent double-logging into the DB,
            // but DO NOT return early so we can still physically cancel the container!
            boolean isGroupSummary = (notification.flags & Notification.FLAG_GROUP_SUMMARY) != 0;

            Bundle extras = notification.extras;

            // Filter out progress notifications (Downloads, uploads, installations)
            int progressMax = extras.getInt(Notification.EXTRA_PROGRESS_MAX, 0);
            boolean isIndeterminate = extras.getBoolean(Notification.EXTRA_PROGRESS_INDETERMINATE, false);
            if (progressMax > 0 || isIndeterminate) {
                return;
            }

            CharSequence titleChars = extras.getCharSequence(Notification.EXTRA_TITLE);
            CharSequence textChars = extras.getCharSequence(Notification.EXTRA_TEXT);
            CharSequence bigTextChars = extras.getCharSequence(Notification.EXTRA_BIG_TEXT);
            CharSequence subTextChars = extras.getCharSequence(Notification.EXTRA_SUB_TEXT);

            String title = (titleChars != null) ? titleChars.toString().trim() : "";
            String text = "";
            
            // Waterfall extraction to systematically extract available notification metadata within OS constraints
            if (bigTextChars != null && !bigTextChars.toString().isEmpty()) {
                text = bigTextChars.toString().trim();
            } else if (textChars != null && !textChars.toString().isEmpty()) {
                text = textChars.toString().trim();
            } else if (subTextChars != null && !subTextChars.toString().isEmpty()) {
                text = subTextChars.toString().trim();
            }

            if (title.isEmpty() && text.isEmpty()) {
                return; // Nothing to process
            }

            // Deduplicate exact content within 3000ms
            String exactSignature = packageName + "|||" + title + "|||" + text;
            Long lastProcessed = duplicateCache.get(exactSignature);
            if (lastProcessed != null && (interceptTimestamp - lastProcessed) < 3000) {
                return; // Ignore exact duplicate broadcast by the OS
            }
            duplicateCache.put(exactSignature, interceptTimestamp);
            
            // Periodically clean up duplicateCache to avoid memory leaks
            if (duplicateCache.size() > 200) {
                duplicateCache.clear();
            }







            // Explicit textual fail-safes for OEM download managers that don't respect proper Android progress APIs
            String rawContext = (title + " " + text).toLowerCase();
            if (rawContext.contains("downloading") || rawContext.contains("download progress") || rawContext.contains("bytes /")) {
                return;
            }

            // aggressive deep-link snapshot
            if (notification.contentIntent != null) {
                cachePendingIntent(interceptTimestamp, notification.contentIntent);
            }

            String readablePackage = getReadablePackageName(packageName);
            String fullContext = readablePackage + ". " + title + ". " + text;

            // 3. AI Pipeline
            long inferenceStartMs = System.currentTimeMillis();
            int classification = intentBrain.classifyNotification(fullContext);
            long inferenceLatency = System.currentTimeMillis() - inferenceStartMs;

            if (classification == -2) {
                Log.i(TAG, "Absolute VIP Bypass Interception: Handing entirely to OS.");
                return;
            }

            // Compute Cognitive Context Multiplier with Adaptive Weights
            android.content.SharedPreferences weightPrefs = getSharedPreferences("intent_adaptive_weights", android.content.Context.MODE_PRIVATE);
            float contextMultiplier = weightPrefs.getFloat("default_weight", 1.5f); 
            boolean isMovingFast = com.intent.intent_app.DriveSafetyEngine.getInstance(this).isDriving();
            
            if (isMovingFast) {
                contextMultiplier = weightPrefs.getFloat("driving_weight", 3.0f);
            } else {
                java.util.Calendar cal = java.util.Calendar.getInstance();
                int hour = cal.get(java.util.Calendar.HOUR_OF_DAY);
                if (hour >= 22 || hour <= 5) {
                    contextMultiplier = weightPrefs.getFloat("night_weight", 0.5f);
                }
            }

            // TTD / Implicit Feedback Override
            // The adaptive EMA tracks Time-To-Dismiss (TTD) milliseconds mathematically.
            // We read the computed appModifier to dynamically correct baseline ML classification.
            String appModKey = "app_mod_" + packageName;
            float appModifier = weightPrefs.getFloat(appModKey, 1.0f);
            
            if (classification == 1) { // If ML defaulted to Buffer or wasn't absolutely certain
                if (appModifier < 0.7f) {
                    Log.i(TAG, "TTD EMA System overriding " + packageName + " from Buffer to Spam due to low weight (" + appModifier + ")");
                    classification = 2; // Heavily dismissed app -> Spam
                } else if (appModifier > 1.4f) {
                    Log.i(TAG, "TTD EMA System overriding " + packageName + " from Buffer to Urgent due to high weight (" + appModifier + ")");
                    classification = 0; // Instantly opened app -> Urgent
                }
            }
            
            // Apply global context decay threshold
            // If it's night mode and the multiplier is heavily constrained, suppress borderline Urgent apps
            if (classification == 0 && contextMultiplier < 0.7f && appModifier < 1.2f) {
                Log.i(TAG, "TTD EMA System overriding " + packageName + " from Urgent to Buffer (Context Threshold)");
                classification = 1;
            }

            // [DO OR DIE] Velocity Blockade
            if (isMovingFast) { // Wipe EVERYTHING that is not VIP
                cancelNotification(sbn.getKey());
                Log.w(TAG, "VELOCITY SAFETY BLOCKADE -> Instantly vaporized " + packageName);
                if (!isGroupSummary) {
                    logToDatabase(packageName, title, "Velocity Blocked: " + text, classification, interceptTimestamp, inferenceLatency, contextMultiplier);
                }
                return;
            }

            // Update the real-time social media presence check
            EngineState.isUserCurrentlyDistracted = isUserOnSocialMedia();

            // 4. Action Logic Switch (Optimized for aggressive silence)
            switch (classification) {
                case 2: // SPAM
                    cancelNotification(sbn.getKey()); // AGGRESSIVE CANCEL FIRST
                    Log.i(TAG, "BLOCKED (Spam) -> Wiping notification from " + packageName);
                    if (!isGroupSummary) {
                        logToDatabase(packageName, title, text, 2, interceptTimestamp, inferenceLatency, contextMultiplier);
                    }
                    break;
                case 1: // BUFFER
                    if (EngineState.isUserCurrentlyDistracted) {
                        Log.i(TAG, "ALLOWED (Buffer) -> User currently distracted, passing through " + packageName);
                        if (!isGroupSummary) {
                            logToDatabase(packageName, title, text, 1, interceptTimestamp, inferenceLatency, contextMultiplier);
                        }
                    } else {
                        cancelNotification(sbn.getKey()); // AGGRESSIVE CANCEL FIRST
                        Log.i(TAG, "INTERCEPTED (Buffer) -> Muting and saving for later from " + packageName);
                        if (!isGroupSummary) {
                            logToDatabase(packageName, title, text, 1, interceptTimestamp, inferenceLatency, contextMultiplier);
                            // repostSilentBuffer is omitted since it reposts, we might not have it in the snippet, just keeping its call
                            repostSilentBuffer(packageName, title, text, notification.getSmallIcon(), notification.contentIntent);
                        }
                    }
                    break;
                case 0: // URGENT
                    Log.i(TAG, "ALLOWED (Urgent) -> Triggering custom Urgent Ringtone for " + packageName);
                    if (!isGroupSummary) {
                        logToDatabase(packageName, title, text, 0, interceptTimestamp, inferenceLatency, contextMultiplier);
                        playUrgentSound();
                    }
                    // Do nothing, let it bypass
                    break;
                default:
                    Log.w(TAG, "Unknown classification result: " + classification);
                    break;
            }

        } catch (Exception e) {
            // Failsafe: If the extraction logic completely crashes on a malformed payload, 
            // the background service stays alive and doesn't crash the phone UI.
            Log.e(TAG, "CRITICAL ERROR processing intercepted notification.", e);
        }
    }

    // Cooldown map to prevent app feedback spam (PackageName -> LastInteractionTimestamp)
    private static final ConcurrentHashMap<String, Long> appFeedbackCooldown = new ConcurrentHashMap<>();


    private static final long COOLDOWN_MS = 60000; // 1 minute anti-spam cooldown
    private static final java.util.concurrent.ConcurrentHashMap<String, Long> duplicateCache = new java.util.concurrent.ConcurrentHashMap<>();





    @Override
    public void onNotificationRemoved(StatusBarNotification sbn, RankingMap rankingMap, int reason) {
        if (sbn == null) return;
        
        String packageName = sbn.getPackageName();
        if (packageName == null || packageName.equals(getPackageName()) || IGNORED_PACKAGES.contains(packageName)) {
            return; // Ignore internal noise
        }

        // COOLDOWN LOGIC (Anti-overfit / Double click prevention)
        long now = System.currentTimeMillis();
        Long lastInteraction = appFeedbackCooldown.get(packageName);
        if (lastInteraction != null && (now - lastInteraction) < COOLDOWN_MS) {
            return; // Ignoring duplicate rapid feedback from the same app (eg swiping 5 messages)
        }
        appFeedbackCooldown.put(packageName, now);
        
        long interceptTimestamp = sbn.getPostTime();
        long ttd = now - interceptTimestamp; // Time-to-dismiss/action in ms
        float score = 0.0f; // Passive

        // FINER-GRAINED GRADIENT FEEDBACK
        if (reason == REASON_CLICK) {
            if (ttd < 10000) score = 1.0f;         // Opened instantly
            else if (ttd < 60000) score = 0.8f;    // Opened within a minute
            else score = 0.5f;                     // Validated, but delayed
        } else if (reason == REASON_CANCEL || reason == REASON_CANCEL_ALL) {
            if (ttd < 2000) score = -1.0f;         // Instant reactive swipe (High annoyance)
            else if (ttd < 10000) score = -0.8f;   // Quick dismiss
            else if (ttd < 60000) score = -0.5f;   // Short delay before cancel
            else score = 0.0f;                     // Passive bulk clear operations (ignored safely)
        }

        // LOG FEEDBACK: Store the result and process ARRIVAL CONTEXT
        if (score != 0.0f) {
            final float finalScore = score;
            java.util.concurrent.Executors.newSingleThreadExecutor().execute(() -> {
                if (com.intent.intent_app.db.IntentDatabase.isLockedForRestore) {
                    Log.w(TAG, "DB Locked for restore. Skipping feedback score update.");
                    return;
                }
                // Determine context explicitly dynamically or use original context multiplier if needed
                // For now we persist the explicit TTD to the local DB immediately
                com.intent.intent_app.db.IntentDatabase.getInstance(this)
                    .notificationDao().updateFeedbackScore(packageName, interceptTimestamp - 5000, finalScore, ttd);
                
                // Fetch the context multiplier the system assigned AT ARRIVAL (Not the current state)
                // This ensures we only penalize driving rules if the user bypassed during driving
                updateDynamicWeights(finalScore, packageName);
            });
        }

        super.onNotificationRemoved(sbn, rankingMap, reason);
    }

    /**
     * Incrementally adjust the multiplier based on user engagement using an Exponential Moving Average (EMA).
     */
    private void updateDynamicWeights(float score, String packageName) {
        android.content.SharedPreferences prefs = getSharedPreferences("intent_adaptive_weights", android.content.Context.MODE_PRIVATE);
        
        // Use current physical proxy for context if DB query is expensive, ideally this maps strictly
        boolean isDriving = com.intent.intent_app.DriveSafetyEngine.getInstance(this).isDriving();
        String contextKey = "default_weight";
        String countKey = "default_count";
        float baseWeight = 1.5f;

        if (isDriving) {
            contextKey = "driving_weight";
            countKey = "driving_count";
            baseWeight = 3.0f;
        } else {
            java.util.Calendar cal = java.util.Calendar.getInstance();
            int hour = cal.get(java.util.Calendar.HOUR_OF_DAY);
            if (hour >= 22 || hour <= 5) {
                contextKey = "night_weight";
                countKey = "night_count";
                baseWeight = 0.5f;
            }
        }

        // ANTI-OVERFIT interactions tracking
        int interactions = prefs.getInt(countKey, 0) + 1;
        prefs.edit().putInt(countKey, interactions).apply();

        if (interactions < 10) {
            Log.d(TAG, "Adaptive Weights: Gathering baseline for " + contextKey + " (" + interactions + "/10)");
            return; 
        }

        float currentWeight = prefs.getFloat(contextKey, baseWeight);
        
        // NORMALIZED PER APP
        String appModKey = "app_mod_" + packageName;
        float appModifier = prefs.getFloat(appModKey, 1.0f);
        
        // DECREASING LEARNING RATE: Capped Alpha based on interactions up to 100
        float learningDecay = (float)(1.0 / Math.max(1, Math.min(interactions, 100)));
        float adjustment = (score * -0.2f * learningDecay); // Gentler updates over time
        
        // SLOW DECAY EMA (Explicit standard form)
        float alpha = 0.9f; 
        float newWeight = (alpha * currentWeight) + ((1.0f - alpha) * (currentWeight + adjustment));

        // CLAMP WEIGHTS
        if (isDriving) {
            newWeight = Math.max(1.5f, Math.min(newWeight, 5.0f)); 
        } else {
            newWeight = Math.max(0.1f, Math.min(newWeight, 4.0f)); 
        }

        // Apply specific per-app adjustments to help isolate spam apps
        appModifier = Math.max(0.5f, Math.min(2.0f, appModifier + (score * 0.05f)));
        
        prefs.edit()
            .putFloat(contextKey, newWeight)
            .putFloat(appModKey, appModifier)
            .apply();
            
        Log.i(TAG, "Adaptive Weights: Constrained Update [" + contextKey + ": " + newWeight + "] [App Mod " + packageName + ": " + appModifier + "]");
    }

    /**
     * Store processed interception result into Room IntentDatabase
     * Runs on an executor to prevent Room from rejecting main-thread calls
     */
    private void logToDatabase(String packageName, String title, String text, int category, long timestamp, long inferenceLatency, float contextMultiplier) {
        java.util.concurrent.Executors.newSingleThreadExecutor().execute(() -> {
            if (com.intent.intent_app.db.IntentDatabase.isLockedForRestore) {
                Log.w(TAG, "DB Locked for restore. Skipping notification log.");
                return;
            }
            try {
                com.intent.intent_app.db.entities.NotificationEntity entity = new com.intent.intent_app.db.entities.NotificationEntity(
                    packageName, title, text, timestamp, category, inferenceLatency, contextMultiplier
                );
                com.intent.intent_app.db.IntentDatabase.getInstance(this).notificationDao().insert(entity);
                Log.d(TAG, "[DB] Successfully written to Room -> [" + category + "] " + packageName);
            } catch (Exception e) {
                Log.e(TAG, "Failed to write interception log to local db.", e);
            }
        });
    }

    /**
     * Checks UsageStatsManager to see if the current foreground app indicates 
     * the user is actively distracted on social media.
     */
    private boolean isUserOnSocialMedia() {
        UsageStatsManager usm = (UsageStatsManager) getSystemService(Context.USAGE_STATS_SERVICE);
        if (usm == null) return false;

        long endTime = System.currentTimeMillis();
        long startTime = endTime - 1000 * 60; // Look back 60 seconds
        UsageEvents.Event currentEvent = new UsageEvents.Event();
        UsageEvents usageEvents = usm.queryEvents(startTime, endTime);
        String foregroundPackage = null;
        
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(currentEvent);
            if (currentEvent.getEventType() == UsageEvents.Event.ACTIVITY_RESUMED) {
                foregroundPackage = currentEvent.getPackageName();
            } else if (currentEvent.getEventType() == UsageEvents.Event.ACTIVITY_PAUSED) {
                if (currentEvent.getPackageName().equals(foregroundPackage)) {
                    foregroundPackage = null;
                }
            }
        }
        
        if (foregroundPackage != null) {
            return SOCIAL_MEDIA_PACKAGES.contains(foregroundPackage);
        }
        return false;
    }

    /**
     * Repost the notification silently
     */
    private void repostSilentBuffer(String packageName, String title, String text, Icon icon, PendingIntent originalIntent) {
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager == null) return;

        android.content.SharedPreferences prefs = getApplicationContext().getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE);
        // Default to 5 max lines, controlled by user (shared_preferences adds flutter. prefix)
        int maxBufferLines = 5;
        Object maxLinesObj = prefs.getAll().get("flutter.buffer_max_lines");
        if (maxLinesObj instanceof Long) {
            maxBufferLines = ((Long) maxLinesObj).intValue();
        } else if (maxLinesObj instanceof Integer) {
            maxBufferLines = (Integer) maxLinesObj;
        } else if (maxLinesObj instanceof String) {
            try {
                maxBufferLines = Integer.parseInt((String) maxLinesObj);
            } catch (NumberFormatException e) {
                // Ignore and use default 5
            }
        }

        String appName = getReadablePackageName(packageName);
        
        // Clean up title and do NOT truncate the text to allow the OS to wrap it to the next line
        String cleanTitle = title.isEmpty() ? "" : title + " \u2022 ";
        String cleanText = text;

        // Use HTML to bold the App Name so it reads cleanly in the InboxStyle
        CharSequence styledLine;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            styledLine = android.text.Html.fromHtml("<b>" + appName + "</b> &nbsp;" + cleanTitle + cleanText, android.text.Html.FROM_HTML_MODE_COMPACT);
        } else {
            styledLine = android.text.Html.fromHtml("<b>" + appName + "</b> &nbsp;" + cleanTitle + cleanText);
        }

        synchronized (bufferInbox) {
            bufferInbox.addFirst(styledLine);
            while (bufferInbox.size() > maxBufferLines) {
                bufferInbox.removeLast();
            }
        }

        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder = new Notification.Builder(this, "intent_buffer_channel");
        } else {
            builder = new Notification.Builder(this);
        }

        Notification.InboxStyle inboxStyle = new Notification.InboxStyle();
        int totalBuffered;
        synchronized (bufferInbox) {
            totalBuffered = bufferInbox.size();
            for (int i = bufferInbox.size() - 1; i >= 0; i--) {
                inboxStyle.addLine(bufferInbox.get(i));
            }
        }
        inboxStyle.setBigContentTitle("Intent Vault (" + totalBuffered + ")");

        builder.setContentTitle("Intent Vault (" + totalBuffered + ")")
               .setContentText(bufferInbox.getFirst())
               .setSmallIcon(icon != null ? icon : Icon.createWithResource(this, android.R.drawable.sym_def_app_icon))
               .setStyle(inboxStyle)
               .setColor(Color.BLACK)
               .setAutoCancel(true);

        if (originalIntent != null) {
            builder.setContentIntent(originalIntent);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE);
        }

        // Exact same ID to organic in-place update the Inbox list
        manager.notify(1001, builder.build());
    }

    /**
     * Instantly trigger a loud alert for Urgent messages.
     * This allows the user to leave their source apps (WhatsApp) completely silent.
     */
    private void playUrgentSound() {
        try {
            Uri urgentSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
            Ringtone r = RingtoneManager.getRingtone(getApplicationContext(), urgentSound);
            if (r != null) {
                r.play();
            }

            Vibrator vibrator = getSystemService(Vibrator.class);
            if (vibrator != null && vibrator.hasVibrator()) {
                long[] pattern = {0, 150, 100, 150};
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1));
                } else {
                    vibrator.vibrate(pattern, -1);
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to play urgent sound or vibrate.", e);
        }
    }

    /**
     * Convert package name to common app name
     */
    private String getReadablePackageName(String packageName) {
        if (packageName == null) return "";
        String pkg = packageName.toLowerCase();
        if (pkg.contains("whatsapp")) return "WhatsApp";
        if (pkg.contains("telegram")) return "Telegram";
        if (pkg.contains("gm") || pkg.contains("mail")) return "Gmail";
        if (pkg.contains("messaging") || pkg.contains("mms") || pkg.contains("sms")) return "Messages";
        if (pkg.contains("instagram")) return "Instagram";
        if (pkg.contains("discord")) return "Discord";
        if (pkg.contains("twitter") || pkg.contains("x")) return "X (Twitter)";

        // Fallback title-casing
        String[] parts = packageName.split("\\.");
        if (parts.length > 0) {
            String name = parts[parts.length - 1];
            return name.substring(0, 1).toUpperCase() + name.substring(1).toLowerCase();
        }
        return packageName;
    }

    /**
     * Store the PendingIntent safely without exceeding bounds
     */
    private void cachePendingIntent(long timestamp, PendingIntent intent) {
        try {
            if (pendingIntentCache.size() >= MAX_CACHE_SIZE) {
                int dropCount = 50;
                Iterator<Long> it = pendingIntentCache.keySet().iterator();
                while (it.hasNext() && dropCount > 0) {
                    it.next();
                    it.remove();
                    dropCount--;
                }
            }
            pendingIntentCache.put(timestamp, intent);
        } catch (Exception e) {
            Log.w(TAG, "Notice: RAM cache maxed out or unstable", e);
        }
    }
}
