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
                int limit = 50;
                int offset = 0;
                Object limitObj = call.argument("limit");
                Object offsetObj = call.argument("offset");
                if (limitObj instanceof Number) limit = ((Number) limitObj).intValue();
                if (offsetObj instanceof Number) offset = ((Number) offsetObj).intValue();

                Integer category = null;
                Object catObj = call.argument("category");
                if (catObj instanceof Number) category = ((Number) catObj).intValue();

                String packageName = call.argument("packageName");

                List<NotificationEntity> list;
                if (category != null && category == 3) {
                    list = dao.getOtpHistoryFiltered(packageName, limit, offset);
                } else {
                    list = dao.getHistoryFiltered(category, packageName, limit, offset);
                }
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
                
                int limit = 50;
                int offset = 0;
                Object limitObj = call.argument("limit");
                Object offsetObj = call.argument("offset");
                if (limitObj instanceof Number) limit = ((Number) limitObj).intValue();
                if (offsetObj instanceof Number) offset = ((Number) offsetObj).intValue();

                Integer category = null;
                Object catObj = call.argument("category");
                if (catObj instanceof Number) category = ((Number) catObj).intValue();

                String packageName = call.argument("packageName");

                if (startObj instanceof Number && endObj instanceof Number) {
                    long start = ((Number) startObj).longValue();
                    long end = ((Number) endObj).longValue();
                    List<NotificationEntity> list;
                    if (category != null && category == 3) {
                        list = dao.getOtpHistoryBetweenFiltered(start, end, packageName, limit, offset);
                    } else {
                        list = dao.getHistoryBetweenFiltered(start, end, category, packageName, limit, offset);
                    }
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

            case "notifications.getFocusStreak": {
                double requiredMins = 60.0;
                int daysToCheck = 28;
                Object reqObj = call.argument("requiredMins");
                Object daysObj = call.argument("daysToCheck");
                if (reqObj instanceof Number) requiredMins = ((Number) reqObj).doubleValue();
                if (daysObj instanceof Number) daysToCheck = ((Number) daysObj).intValue();

                int streak = 0;
                long now = System.currentTimeMillis();
                Calendar cal = Calendar.getInstance();
                cal.setTimeInMillis(now);
                cal.set(Calendar.HOUR_OF_DAY, 0);
                cal.set(Calendar.MINUTE, 0);
                cal.set(Calendar.SECOND, 0);
                cal.set(Calendar.MILLISECOND, 0);
                long todayMidnight = cal.getTimeInMillis();

                for (int i = 0; i < daysToCheck; i++) {
                    long dayStart = todayMidnight - (i * 86400000L);
                    long dayEnd = (i == 0) ? now : (dayStart + 86400000L - 1L);

                    List<NotificationEntity> intercepted = dao.getInterceptedBetween(dayStart, dayEnd);
                    double cognitiveMins = 0.0;
                    long lastBurstTimestamp = 0;
                    for (NotificationEntity n : intercepted) {
                        if (lastBurstTimestamp == 0 || (n.timestamp - lastBurstTimestamp) > 120000) {
                            cognitiveMins += (1.5 * n.contextMultiplier);
                            lastBurstTimestamp = n.timestamp;
                        }
                    }

                    if (cognitiveMins >= requiredMins) {
                        streak++;
                    } else {
                        if (i == 0) continue; // Keep today's streak alive while day is in progress
                        break;
                    }
                }
                return streak;
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
                // Safely close the database to force a WAL checkpoint and merge all data into the main file
                android.database.Cursor c = com.intent.intent_app.db.IntentDatabase.getInstance(context)
                        .query("PRAGMA wal_checkpoint(TRUNCATE)", null);
                if (c != null) {
                    c.moveToFirst();
                    c.close();
                }
                com.intent.intent_app.db.IntentDatabase.resetInstance();
                
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
                
                java.io.File sourceFile = new java.io.File(sourcePath);
                if (!sourceFile.exists() || sourceFile.length() < 100) {
                    throw new IllegalArgumentException("Invalid database backup source file.");
                }

                // Verify SQLite header bytes
                byte[] header = new byte[16];
                try (java.io.FileInputStream hFis = new java.io.FileInputStream(sourceFile)) {
                    int read = hFis.read(header);
                    if (read < 16 || !new String(header).startsWith("SQLite format 3")) {
                        throw new IllegalArgumentException("Provided file is not a valid SQLite database.");
                    }
                }

                // Block the IntentNotificationService from touching the database
                com.intent.intent_app.db.IntentDatabase.isLockedForRestore = true;
                com.intent.intent_app.db.IntentDatabase.resetInstance();
                
                java.io.File dbPath = context.getDatabasePath("intent_database");
                java.io.File walPath = context.getDatabasePath("intent_database-wal");
                java.io.File shmPath = context.getDatabasePath("intent_database-shm");
                
                java.io.File rollbackBackup = new java.io.File(context.getCacheDir(), "intent_db_rollback.bak");
                if (dbPath.exists()) {
                    copyFileAtomic(dbPath, rollbackBackup);
                }

                java.io.File tmpDest = new java.io.File(dbPath.getParentFile(), "intent_database.tmp");

                try {
                    copyFileAtomic(sourceFile, tmpDest);

                    if (walPath.exists()) walPath.delete();
                    if (shmPath.exists()) shmPath.delete();

                    if (dbPath.exists()) dbPath.delete();
                    if (!tmpDest.renameTo(dbPath)) {
                        copyFileAtomic(tmpDest, dbPath);
                        tmpDest.delete();
                    }

                    if (rollbackBackup.exists()) rollbackBackup.delete();
                    return true;
                } catch (Exception e) {
                    Log.e(TAG, "DB Import Error, attempting rollback", e);
                    if (rollbackBackup.exists()) {
                        try {
                            copyFileAtomic(rollbackBackup, dbPath);
                            rollbackBackup.delete();
                        } catch (Exception ignored) {}
                    }
                    throw new RuntimeException("DB Import Failed (Rolled Back): " + e.getMessage(), e);
                } finally {
                    com.intent.intent_app.db.IntentDatabase.isLockedForRestore = false;
                }
            }

            case "requestPermissions": {
                // To do: implement permission requests
                return true;
            }

            default:
                throw new UnsupportedOperationException("Unknown optimized method: " + call.method);
        }
    }

    private static void copyFileAtomic(java.io.File src, java.io.File dst) throws java.io.IOException {
        try (java.io.FileInputStream fis = new java.io.FileInputStream(src);
             java.io.FileOutputStream fos = new java.io.FileOutputStream(dst)) {
            byte[] buffer = new byte[1024 * 8];
            int len;
            while ((len = fis.read(buffer)) > 0) {
                fos.write(buffer, 0, len);
            }
            fos.flush();
            fos.getFD().sync();
        }
    }
}
