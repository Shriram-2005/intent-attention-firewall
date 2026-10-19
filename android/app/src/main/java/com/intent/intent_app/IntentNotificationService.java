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
    private List<String> getSocialMediaPackages() {
        android.content.SharedPreferences prefs = getApplicationContext().getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE);
        Object raw = prefs.getAll().get("flutter.social_media_packages");
        if (raw != null) {
            java.util.List<String> list = com.intent.intent_app.IntentBrain.parseFlutterListSafely(raw);
            if (!list.isEmpty()) return list;
        }
        return Arrays.asList(
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
    }

    // High-speed volatility RAM cache to hold Deep Linking Portals
    public static final ConcurrentHashMap<Long, PendingIntent> pendingIntentCache = new ConcurrentHashMap<>();
    private static final int MAX_CACHE_SIZE = 500;
    private final java.util.concurrent.ExecutorService dbExecutor = java.util.concurrent.Executors.newSingleThreadExecutor();
    private final ConcurrentHashMap<String, String> appLabelCache = new ConcurrentHashMap<>();

    // Ignore core OS noise but allow EVERYTHING else to be analyzed
    private List<String> getIgnoredPackages() {
        android.content.SharedPreferences prefs = getApplicationContext().getSharedPreferences(
            com.intent.intent_app.constants.IntentConstants.PREFS_FLUTTER, android.content.Context.MODE_PRIVATE);
        Object raw = com.intent.intent_app.constants.IntentConstants.getFlutterPref(
            prefs, com.intent.intent_app.constants.IntentConstants.KEY_IGNORED_PACKAGES);
        return IntentBrain.parseFlutterListSafely(raw);
    }

    private String getAppLabel(String packageName) {
        if (packageName == null || packageName.isEmpty()) return "";
        String cached = appLabelCache.get(packageName);
        if (cached != null) return cached;
        try {
            android.content.pm.PackageManager pm = getApplicationContext().getPackageManager();
            android.content.pm.ApplicationInfo info = pm.getApplicationInfo(packageName, 0);
            CharSequence label = pm.getApplicationLabel(info);
            if (label != null) {
                String result = label.toString().toLowerCase().trim();
                appLabelCache.put(packageName, result);
                return result;
            }
        } catch (Exception ignored) {}
        appLabelCache.put(packageName, "");
        return "";
    }


    @Override
    public void onCreate() {
        super.onCreate();
        Log.i(TAG, "Intent Notification Interceptor Service started. Initializing Brain...");
        intentBrain = new IntentBrain(this);
        
        // Ignite the low-power velocity observer securely in the background
        com.intent.intent_app.DriveSafetyEngine.getInstance(this).startBackgroundTracking();
        
        createBufferChannel();

        // Listen for instant keyword updates from Flutter UI
        android.content.IntentFilter filter = new android.content.IntentFilter("com.intent.intent_app.SYNC_KEYWORDS");
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(keywordSyncReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(keywordSyncReceiver, filter);
        }
    }

    private final android.content.BroadcastReceiver keywordSyncReceiver = new android.content.BroadcastReceiver() {
        @Override
        public void onReceive(android.content.Context context, android.content.Intent intent) {
            Log.i(TAG, "Received SYNC_KEYWORDS broadcast. Forcing IntentBrain to reload memory cache.");
            if (intentBrain != null) {
                intentBrain.forceReloadKeywords(intent);
            }
        }
    };

    @Override
    public void onDestroy() {
        super.onDestroy();
        try {
            unregisterReceiver(keywordSyncReceiver);
        } catch (Exception e) {}
        try {
            dbExecutor.shutdown();
        } catch (Exception e) {}
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
            String appLabel = getAppLabel(packageName);

            // 1. Filter out system notifications and self-feedback loops
            List<String> ignored = getIgnoredPackages();
            if (packageName == null || packageName.equals(getPackageName()) || ignored.contains(packageName) || (!appLabel.isEmpty() && ignored.contains(appLabel)) || packageName.startsWith("com.android.providers")) {
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

            // Deduplicate exact content within 20000ms (20 seconds) for heavy network bursting
            String exactSignature = packageName + "|||" + title + "|||" + text;
            synchronized (duplicateCache) {
                Long lastProcessed = duplicateCache.get(exactSignature);
                if (lastProcessed != null && (interceptTimestamp - lastProcessed) < 20000) {
                    return; // Ignore exact duplicate broadcast by the OS
                }
                duplicateCache.put(exactSignature, interceptTimestamp);
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

            // 1. Direct Peer-to-Peer Message vs Group Conversation Detection
            boolean isGroupConversation = extras.getBoolean(Notification.EXTRA_IS_GROUP_CONVERSATION, false) ||
                                          extras.containsKey("android.conversationTitle") ||
                                          (extras.containsKey(Notification.EXTRA_CONVERSATION_TITLE) &&
                                           extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE) != null);

            boolean isMessaging = Notification.CATEGORY_MESSAGE.equals(notification.category) ||
                                  Notification.CATEGORY_CALL.equals(notification.category) ||
                                  extras.containsKey(Notification.EXTRA_MESSAGING_PERSON) ||
                                  extras.containsKey("android.people.list") ||
                                  hasInlineReplyAction(notification);

            // Direct 1-on-1 communication strictly excludes group chats (e.g. "Mom Friends", "Dad Jokes")
            boolean isDirect1to1Message = isMessaging && !isGroupConversation;

            // 3. AI Pipeline
            long inferenceStartMs = System.currentTimeMillis();
            IntentBrain.ClassificationResult result = intentBrain.classify(fullContext, title, isDirect1to1Message);
            int classification = result.category;
            long inferenceLatency = System.currentTimeMillis() - inferenceStartMs;

            if (classification == -2) {
                Log.i(TAG, "Absolute VIP Bypass Interception: Handing entirely to OS.");
                return;
            }

            // User's Explicit Block / Spam Rules MUST BE HONORED!
            // If the user explicitly added this sender/phrase to their Block list in settings,
            // cancel and wipe it immediately, EVEN IF it is a direct message or group chat!
            if (classification == 2 && result.isUserExplicitRule) {
                cancelNotification(sbn.getKey());
                Log.i(TAG, "USER EXPLICIT BLOCK -> Wiping notification from " + packageName + " (User Block Rule Honored)");
                if (!isGroupSummary) {
                    logToDatabase(packageName, title, text, 2, interceptTimestamp, inferenceLatency, 1.0f);
                }
                return;
            }

            // Peer-to-peer personal and group messages MUST NEVER be auto-cancelled as SPAM (2) by ML or generic heuristics!
            // Legitimate communications are downgraded to Buffer (1) / Vault so they are never wiped!
            if (isMessaging && classification == 2) {
                Log.i(TAG, "Messaging communication detected for " + packageName + " -> Downgrading ML/Heuristic Spam to Buffer (never wipe chats).");
                classification = 1;
            }

            // Non-Chat / Generic Spam Cancellation
            if (classification == 2) {
                cancelNotification(sbn.getKey());
                Log.i(TAG, "BLOCKED (Spam) -> Wiping notification from " + packageName);
                if (!isGroupSummary) {
                    logToDatabase(packageName, title, text, 2, interceptTimestamp, inferenceLatency, 1.0f);
                }
                return;
            }

            // Compute Cognitive Context Multiplier with Adaptive Weights
            android.content.SharedPreferences weightPrefs = getSharedPreferences(
                com.intent.intent_app.constants.IntentConstants.PREFS_ADAPTIVE_WEIGHTS, android.content.Context.MODE_PRIVATE);
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

            // 3. Driving Blockade: While driving, ONLY critical Urgent / OTP / Emergency alerts bypass.
            // Non-urgent contact messages MUST be grounded safely into Vault, NEVER shown while driving!
            if (isMovingFast) {
                if (classification == 0) {
                    Log.i(TAG, "VELOCITY PASS-THROUGH -> Preserved Critical Urgent alert while moving from " + packageName);
                    if (!isGroupSummary) {
                        logToDatabase(packageName, title, text, 0, interceptTimestamp, inferenceLatency, contextMultiplier);
                        playUrgentSound();
                    }
                    return;
                } else {
                    cancelNotification(sbn.getKey());
                    Log.i(TAG, "VELOCITY SAFETY BLOCKADE -> Muted non-urgent alert while moving from " + packageName);
                    if (!isGroupSummary) {
                        logToDatabase(packageName, title, text, classification, interceptTimestamp, inferenceLatency, contextMultiplier);
                        repostSilentBuffer(packageName, title, text, notification.getSmallIcon(), notification.contentIntent);
                    }
                    return;
                }
            }

            // 4. Saved Contact Pass-Through (Not driving, not blocked by user)
            if (!title.isEmpty() && isSavedContact(title)) {
                Log.i(TAG, "SAVED CONTACT PASS-THROUGH -> Allowed message from contact: " + title);
                if (!isGroupSummary) {
                    // Accurately log as Buffer/Normal communication (1), NOT Urgent (0), to prevent inflating urgent analytics!
                    logToDatabase(packageName, title, text, classification == 0 ? 0 : 1, interceptTimestamp, inferenceLatency, contextMultiplier);
                }
                return; // Direct pass-through to user!
            }

            // TTD / Implicit Feedback Override
            String appModKey = "app_mod_" + packageName;
            float appModifier = weightPrefs.getFloat(appModKey, 1.0f);
            
            if (classification == 1) { // If ML defaulted to Buffer or wasn't absolutely certain
                if (appModifier < 0.7f && !isMessaging) { // Do not override personal messaging apps to Spam!
                    Log.i(TAG, "TTD EMA System overriding " + packageName + " from Buffer to Spam due to low weight");
                    classification = 2; // Heavily dismissed app -> Spam
                } else if (appModifier > 1.4f) {
                    Log.i(TAG, "TTD EMA System overriding " + packageName + " from Buffer to Urgent due to high weight");
                    classification = 0; // Instantly opened app -> Urgent
                }
            }
            
            // Apply global context decay threshold
            if (classification == 0 && contextMultiplier < 0.7f && appModifier < 1.2f) {
                Log.i(TAG, "TTD EMA System overriding " + packageName + " from Urgent to Buffer (Context Threshold)");
                classification = 1;
            }

            // Update the real-time social media presence check (throttled)
            EngineState.isUserCurrentlyDistracted = isUserOnSocialMediaThrottled();

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
                        Log.i(TAG, "INTERCEPTED (Buffer) -> Muting and saving to Vault from " + packageName);
                        if (!isGroupSummary) {
                            logToDatabase(packageName, title, text, 1, interceptTimestamp, inferenceLatency, contextMultiplier);
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
            Log.e(TAG, "CRITICAL ERROR processing intercepted notification.", e);
        }
    }

    // Cooldown map to prevent app feedback spam (PackageName -> LastInteractionTimestamp)
    private static final ConcurrentHashMap<String, Long> appFeedbackCooldown = new ConcurrentHashMap<>();
    private static final long COOLDOWN_MS = 60000; // 1 minute anti-spam cooldown

    // High-performance bounded deduplication cache with sliding TTL window
    private static final int MAX_DEDUP_SIZE = 1000;
    private static final long DEDUP_TTL_MS = 20000; // 20s window
    private static final java.util.Map<String, Long> duplicateCache = 
        java.util.Collections.synchronizedMap(new java.util.LinkedHashMap<String, Long>(128, 0.75f, true) {
            @Override
            protected boolean removeEldestEntry(java.util.Map.Entry<String, Long> eldest) {
                return size() > MAX_DEDUP_SIZE || (System.currentTimeMillis() - eldest.getValue()) > DEDUP_TTL_MS;
            }
        });





    @Override
    public void onNotificationRemoved(StatusBarNotification sbn, RankingMap rankingMap, int reason) {
        if (sbn == null) return;
        
        String packageName = sbn.getPackageName();
        String appLabel = getAppLabel(packageName);
        List<String> ignored = getIgnoredPackages();
        if (packageName == null || packageName.equals(getPackageName()) || ignored.contains(packageName) || (!appLabel.isEmpty() && ignored.contains(appLabel))) {
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
            dbExecutor.execute(() -> {
                if (com.intent.intent_app.db.IntentDatabase.isLockedForRestore) {
                    Log.w(TAG, "DB Locked for restore. Skipping feedback score update.");
                    return;
                }
                // Determine context explicitly dynamically or use original context multiplier if needed
                // For now we persist the explicit TTD to the local DB immediately
                com.intent.intent_app.db.IntentDatabase.getInstance(this)
                    .notificationDao().updateFeedbackScore(packageName, interceptTimestamp, finalScore, ttd);
                
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

        float currentWeight = prefs.getFloat(contextKey, baseWeight);
        
        // NORMALIZED PER APP
        String appModKey = "app_mod_" + packageName;
        float appModifier = prefs.getFloat(appModKey, 1.0f);
        
        // Apply specific per-app adjustments to help isolate spam apps quickly
        // Learning rate increased to 0.2f so user intent overrides AI in ~2 to 3 actions
        appModifier = Math.max(0.5f, Math.min(2.0f, appModifier + (score * 0.2f)));
        prefs.edit().putFloat(appModKey, appModifier).apply();
        
        // ANTI-OVERFIT interactions tracking for GLOBAL CONTEXT
        int interactions = prefs.getInt(countKey, 0) + 1;
        prefs.edit().putInt(countKey, interactions).apply();

        if (interactions < 10) {
            Log.d(TAG, "Adaptive Weights: Gathering baseline for " + contextKey + " (" + interactions + "/10). App Modifier updated to " + appModifier);
            return; 
        }
        
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

        prefs.edit()
            .putFloat(contextKey, newWeight)
            .apply();
            
        Log.i(TAG, "Adaptive Weights: Constrained Update [" + contextKey + ": " + newWeight + "] [App Mod " + packageName + ": " + appModifier + "]");
    }

    /**
     * Store processed interception result into Room IntentDatabase
     * Runs on an executor to prevent Room from rejecting main-thread calls
     */
    private void logToDatabase(String packageName, String title, String text, int category, long timestamp, long inferenceLatency, float contextMultiplier) {
        dbExecutor.execute(() -> {
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

    private volatile long lastSocialCheckTime = 0;
    private volatile boolean cachedSocialDistraction = false;

    private boolean isUserOnSocialMediaThrottled() {
        long now = System.currentTimeMillis();
        if (now - lastSocialCheckTime > 5000) {
            lastSocialCheckTime = now;
            // Offload to background executor so listener callback thread NEVER stalls on UsageStats IPC
            dbExecutor.execute(() -> {
                try {
                    cachedSocialDistraction = isUserOnSocialMedia();
                } catch (Exception ignored) {}
            });
        }
        return cachedSocialDistraction;
    }

    /**
     * Checks UsageStatsManager to see if the current foreground app indicates 
     * the user is actively distracted on social media.
     */
    private boolean isUserOnSocialMedia() {
        android.app.usage.UsageStatsManager usm = (android.app.usage.UsageStatsManager) getSystemService(Context.USAGE_STATS_SERVICE);
        if (usm == null) return false;

        long endTime = System.currentTimeMillis();
        long startTime = endTime - 1000 * 60; // Look back 60 seconds
        android.app.usage.UsageEvents.Event currentEvent = new android.app.usage.UsageEvents.Event();
        android.app.usage.UsageEvents usageEvents = usm.queryEvents(startTime, endTime);
        String lastResumed = null;
        
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(currentEvent);
            if (currentEvent.getEventType() == android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED) {
                lastResumed = currentEvent.getPackageName();
            }
        }
        
        if (lastResumed != null) {
            List<String> social = getSocialMediaPackages();
            if (social.contains(lastResumed)) return true;
            String appLabel = getAppLabel(lastResumed);
            if (!appLabel.isEmpty() && social.contains(appLabel)) return true;
        }
        return false;
    }

    /**
     * Repost the notification silently, synchronized with Room database history.
     */
    private void repostSilentBuffer(String packageName, String title, String text, Icon icon, PendingIntent originalIntent) {
        dbExecutor.execute(() -> {
            try {
                NotificationManager manager = getSystemService(NotificationManager.class);
                if (manager == null) return;

                android.content.SharedPreferences prefs = getApplicationContext().getSharedPreferences(
                    com.intent.intent_app.constants.IntentConstants.PREFS_FLUTTER, android.content.Context.MODE_PRIVATE);
                
                int maxBufferLines = 5;
                Object maxLinesObj = com.intent.intent_app.constants.IntentConstants.getFlutterPref(
                    prefs, com.intent.intent_app.constants.IntentConstants.KEY_BUFFER_MAX_LINES);
                if (maxLinesObj instanceof Number) {
                    maxBufferLines = ((Number) maxLinesObj).intValue();
                } else if (maxLinesObj instanceof String) {
                    try { maxBufferLines = Integer.parseInt((String) maxLinesObj); } catch (Exception ignored) {}
                }

                java.util.Calendar cal = java.util.Calendar.getInstance();
                cal.set(java.util.Calendar.HOUR_OF_DAY, 0);
                cal.set(java.util.Calendar.MINUTE, 0);
                cal.set(java.util.Calendar.SECOND, 0);
                long startOfDay = cal.getTimeInMillis();

                int totalToday = 0;
                java.util.List<com.intent.intent_app.db.entities.NotificationEntity> recentBuffered = null;
                if (!com.intent.intent_app.db.IntentDatabase.isLockedForRestore) {
                    try {
                        com.intent.intent_app.db.dao.NotificationDao dao = com.intent.intent_app.db.IntentDatabase.getInstance(this).notificationDao();
                        totalToday = dao.getCountByCategoryForToday(1, startOfDay);
                        recentBuffered = dao.getHistoryFiltered(1, null, maxBufferLines, 0);
                    } catch (Exception ignored) {}
                }

                if (totalToday <= 0) totalToday = 1;

                Notification.Builder builder;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    builder = new Notification.Builder(this, com.intent.intent_app.constants.IntentConstants.CHANNEL_BUFFER);
                } else {
                    builder = new Notification.Builder(this);
                }

                Notification.InboxStyle inboxStyle = new Notification.InboxStyle();
                String latestSnippet = title + (text.isEmpty() ? "" : " - " + text);

                if (recentBuffered != null && !recentBuffered.isEmpty()) {
                    for (int i = recentBuffered.size() - 1; i >= 0; i--) {
                        com.intent.intent_app.db.entities.NotificationEntity entity = recentBuffered.get(i);
                        String app = getReadablePackageName(entity.packageName);
                        String lineText = (entity.title != null ? entity.title : "") + " " + (entity.content != null ? entity.content : "");
                        CharSequence styled;
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            styled = android.text.Html.fromHtml("<b>" + app + "</b> &nbsp;" + lineText, android.text.Html.FROM_HTML_MODE_COMPACT);
                        } else {
                            styled = android.text.Html.fromHtml("<b>" + app + "</b> &nbsp;" + lineText);
                        }
                        inboxStyle.addLine(styled);
                    }
                    com.intent.intent_app.db.entities.NotificationEntity latest = recentBuffered.get(0);
                    latestSnippet = (latest.title != null ? latest.title : "") + " " + (latest.content != null ? latest.content : "");
                } else {
                    String app = getReadablePackageName(packageName);
                    CharSequence styled;
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        styled = android.text.Html.fromHtml("<b>" + app + "</b> &nbsp;" + title + " " + text, android.text.Html.FROM_HTML_MODE_COMPACT);
                    } else {
                        styled = android.text.Html.fromHtml("<b>" + app + "</b> &nbsp;" + title + " " + text);
                    }
                    inboxStyle.addLine(styled);
                }

                inboxStyle.setBigContentTitle("Intent Vault (" + totalToday + ")");

                builder.setContentTitle("Intent Vault (" + totalToday + ")")
                       .setContentText(latestSnippet)
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

                manager.notify(com.intent.intent_app.constants.IntentConstants.NOTIFICATION_ID_BUFFER_INBOX, builder.build());
            } catch (Exception e) {
                Log.e(TAG, "Error posting buffer aggregate notification", e);
            }
        });
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

    private boolean hasInlineReplyAction(Notification notification) {
        if (notification == null || notification.actions == null) return false;
        for (Notification.Action action : notification.actions) {
            if (action != null && action.getRemoteInputs() != null && action.getRemoteInputs().length > 0) {
                return true;
            }
        }
        return false;
    }

    private final java.util.Map<String, Boolean> contactCheckCache = new java.util.concurrent.ConcurrentHashMap<>();

    private boolean isSavedContact(String contactName) {
        if (contactName == null || contactName.trim().isEmpty()) return false;
        String trimmed = contactName.trim();
        Boolean cached = contactCheckCache.get(trimmed.toLowerCase());
        if (cached != null) return cached;

        if (androidx.core.content.ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_CONTACTS)
                != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            return false;
        }

        android.database.Cursor cursor = null;
        try {
            android.net.Uri uri = android.net.Uri.withAppendedPath(
                android.provider.ContactsContract.Contacts.CONTENT_FILTER_URI,
                android.net.Uri.encode(trimmed)
            );
            cursor = getContentResolver().query(
                uri,
                new String[]{android.provider.ContactsContract.Contacts._ID},
                null,
                null,
                null
            );
            boolean exists = cursor != null && cursor.moveToFirst();
            if (contactCheckCache.size() > 500) contactCheckCache.clear();
            contactCheckCache.put(trimmed.toLowerCase(), exists);
            return exists;
        } catch (Exception e) {
            return false;
        } finally {
            if (cursor != null) cursor.close();
        }
    }
}
