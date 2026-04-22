package com.intent.intent_app.channels;

import android.content.Context;
import android.app.PendingIntent;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import com.intent.intent_app.db.IntentDatabase;
import com.intent.intent_app.db.dao.NotificationDao;
import com.intent.intent_app.db.entities.NotificationEntity;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Flutter ↔ Android Method Channel Bridge.
 * Channel name: "com.intent.intent_app/db"
 *
 * Highly optimized native DB wrapper exclusively serving
 * the OLED analytics and audit log frontends.
 */
public class DbMethodChannel {

    private static final String TAG = "DbMethodChannel";
    public static final String CHANNEL = "com.intent.intent_app/db";

    private final NotificationDao dao;
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final Context context;

    public DbMethodChannel(Context context) {
        this.context = context;
        this.dao = IntentDatabase.getInstance(context).notificationDao();
    }

    public void register(FlutterEngine engine) {
        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler(this::handleCall);
        Log.i(TAG, "Fast DbMethodChannel registered.");
    }

    private void handleCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        executor.execute(() -> {
            try {
                Object value = dispatch(call);
                mainHandler.post(() -> result.success(value));
            } catch (Exception e) {
                Log.e(TAG, "Method error on " + call.method, e);
                mainHandler.post(() -> result.error("DB_ERROR", e.getMessage(), null));
            }
        });
    }

    private Object dispatch(@NonNull MethodCall call) throws Exception {
        switch (call.method) {
            case "notifications.getHistory": {
                List<NotificationEntity> list = dao.getAllHistory();
                List<Map<String, Object>> mappedList = new ArrayList<>();
                for (NotificationEntity n : list) {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", n.id);
                    m.put("packageName", n.packageName);
                    m.put("title", n.title);
                    m.put("content", n.content);
                    m.put("timestamp", n.timestamp);
                    m.put("category", n.category);
                    mappedList.add(m);
                }
                return mappedList;
            }

            case "notifications.getHistoryBetween": {
                Object startObj = call.argument("startTime");
                Object endObj = call.argument("endTime");
                if (startObj instanceof Number && endObj instanceof Number) {
                    long start = ((Number) startObj).longValue();
                    long end = ((Number) endObj).longValue();
                    List<NotificationEntity> list = dao.getHistoryBetween(start, end);
                    List<Map<String, Object>> mappedList = new ArrayList<>();
                    for (NotificationEntity n : list) {
                        Map<String, Object> m = new HashMap<>();
                        m.put("id", n.id);
                        m.put("packageName", n.packageName);
                        m.put("title", n.title);
                        m.put("content", n.content);
                        m.put("timestamp", n.timestamp);
                        m.put("category", n.category);
                        mappedList.add(m);
                    }
                    return mappedList;
                }
                return new ArrayList<>();
            }

            case "notifications.deleteHistoryBefore": {
                Object timestampObj = call.argument("timestamp");
                if (timestampObj instanceof Number) {
                    long timestamp = ((Number) timestampObj).longValue();
                    dao.deleteHistoryBefore(timestamp);
                    return true;
                }
                return false;
            }

            case "notifications.deleteHistoryBetween": {
                Object startObj = call.argument("startTime");
                Object endObj = call.argument("endTime");
                if (startObj instanceof Number && endObj instanceof Number) {
                    long start = ((Number) startObj).longValue();
                    long end = ((Number) endObj).longValue();
                    dao.deleteHistoryBetween(start, end);
                    return true;
                }
                return false;
            }

            case "notifications.deleteAllHistory": {
                dao.deleteAllHistory();
                return true;
            }

            case "notifications.getCounts": {
                Object startObj = call.argument("startTime");
                Object endObj = call.argument("endTime");
                
                long startTime;
                long endTime;
                
                if (startObj instanceof Number && endObj instanceof Number) {
                    startTime = ((Number) startObj).longValue();
                    endTime = ((Number) endObj).longValue();
                } else {
                    Calendar cal = Calendar.getInstance();
                    cal.set(Calendar.HOUR_OF_DAY, 0);
                    cal.set(Calendar.MINUTE, 0);
                    cal.set(Calendar.SECOND, 0);
                    startTime = cal.getTimeInMillis();
                    endTime = System.currentTimeMillis();
                }

                int urgentCount = dao.getCountByCategoryBetween(0, startTime, endTime);
                int bufferCount = dao.getCountByCategoryBetween(1, startTime, endTime);
                int spamCount = dao.getCountByCategoryBetween(2, startTime, endTime);

                // Cluster algorithms for exact minutes
                List<NotificationEntity> intercepted = dao.getInterceptedBetween(startTime, endTime);
                double literalMins = 0.0;
                double cognitiveMins = 0.0;
                long lastBurstTimestamp = 0;

                for (NotificationEntity n : intercepted) {
                    if (lastBurstTimestamp == 0 || (n.timestamp - lastBurstTimestamp) > 120000) {
                        // New burst
                        literalMins += 0.25;
                        cognitiveMins += (1.5 * n.contextMultiplier);
                        lastBurstTimestamp = n.timestamp;
                    } else {
                        // Same burst, ignore
                    }
                }

                Map<String, Number> counts = new HashMap<>();
                counts.put("urgent", urgentCount);
                counts.put("buffer", bufferCount);
                counts.put("spam", spamCount);
                float avgLatency = dao.getAverageLatencyBetween(startTime, endTime);
                counts.put("latency", avgLatency);
                counts.put("literal_mins", literalMins);
                counts.put("cognitive_mins", cognitiveMins);

                return counts;
            }

            case "notifications.launchApp": {
                String pkg = call.argument("packageName");
                if (pkg != null) {
                    android.content.Intent launchIntent = context.getPackageManager().getLaunchIntentForPackage(pkg);
                    if (launchIntent != null) {
                        launchIntent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK);
                        context.startActivity(launchIntent);
                        return true;
                    }
                }
                return false;
            }

            case "notifications.launchMessage": {
                Object timestampObj = call.argument("timestamp");
                if (timestampObj instanceof Number) {
                    long timestamp = ((Number) timestampObj).longValue();
                    PendingIntent pi = com.intent.intent_app.IntentNotificationService.pendingIntentCache.get(timestamp);
                    if (pi != null) {
                        try {
                            pi.send();
                            return true;
                        } catch (PendingIntent.CanceledException e) {
                            Log.w(TAG, "Cached PendingIntent explicitly canceled by the Android OS.", e);
                        }
                    }
                }
                return false;
            }

            case "notifications.exportDatabase": {
                // Ensure recent writes are moved to the main database file
                com.intent.intent_app.db.IntentDatabase.getInstance(context).getOpenHelper().getWritableDatabase().query("PRAGMA wal_checkpoint(TRUNCATE)");
                
                java.io.File dbPath = context.getDatabasePath("intent_database");
                java.io.File backupDir = new java.io.File(context.getCacheDir(), "intent_backups");
                if (!backupDir.exists()) backupDir.mkdirs();
                
                java.io.File backupFile = new java.io.File(backupDir, "intent_database_backup.db");
                try (java.io.FileInputStream fis = new java.io.FileInputStream(dbPath);
                     java.io.FileOutputStream fos = new java.io.FileOutputStream(backupFile)) {
                    byte[] buffer = new byte[1024 * 4];
                    int len;
                    while ((len = fis.read(buffer)) > 0) {
                        fos.write(buffer, 0, len);
                    }
                }
                return backupFile.getAbsolutePath();
            }

            case "notifications.importDatabase": {
                String sourcePath = call.argument("filePath");
                if (sourcePath == null) return false;
                
                // Close the DB before overwriting
                com.intent.intent_app.db.IntentDatabase.getInstance(context).close();
                
                java.io.File sourceFile = new java.io.File(sourcePath);
                java.io.File dbPath = context.getDatabasePath("intent_database");
                java.io.File walPath = context.getDatabasePath("intent_database-wal");
                java.io.File shmPath = context.getDatabasePath("intent_database-shm");
                
                // Delete WAL and SHM as we are restoring a fully checkpointed database
                if (walPath.exists()) walPath.delete();
                if (shmPath.exists()) shmPath.delete();
                
                try (java.io.FileInputStream fis = new java.io.FileInputStream(sourceFile);
                     java.io.FileOutputStream fos = new java.io.FileOutputStream(dbPath)) {
                    byte[] buffer = new byte[1024 * 4];
                    int len;
                    while ((len = fis.read(buffer)) > 0) {
                        fos.write(buffer, 0, len);
                    }
                }
                // Force process kill so the app fully restarts with the new database
                System.exit(0);
                return true;
            }

            case "requestPermissions": {
                // To do: implement permission requests
                return true;
            }

            default:
                throw new UnsupportedOperationException("Unknown optimized method: " + call.method);
        }
    }
}
