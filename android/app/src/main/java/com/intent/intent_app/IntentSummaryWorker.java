package com.intent.intent_app;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.graphics.Color;
import android.content.Context;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import com.intent.intent_app.db.IntentDatabase;
import com.intent.intent_app.db.dao.NotificationDao;

import java.util.Calendar;

public class IntentSummaryWorker extends Worker {

    public IntentSummaryWorker(@NonNull Context context, @NonNull WorkerParameters workerParams) {
        super(context, workerParams);
    }

    @NonNull
    @Override
    public Result doWork() {
        Context context = getApplicationContext();
        NotificationDao dao = IntentDatabase.getInstance(context).notificationDao();

        // --- Data Sovereignty Auto-Prune ---
        android.content.SharedPreferences prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
        // Default 0 means 'Never auto-delete'
        long retentionDays = 0L;
        Object retObj = prefs.getAll().get("flutter.history_retention_days");
        if (retObj == null) {
            retObj = prefs.getAll().get("history_retention_days");
        }
        if (retObj instanceof Number) {
            retentionDays = ((Number) retObj).longValue();
        } else if (retObj instanceof String) {
            try {
                retentionDays = Long.parseLong((String) retObj);
            } catch (Exception ignored) {}
        }
        if (retentionDays > 0) {
            long thresholdMillis = System.currentTimeMillis() - (retentionDays * 24L * 60L * 60L * 1000L);
            dao.deleteHistoryBefore(thresholdMillis);
        }
        // -----------------------------------

        // Determine time window for this batch summary
        long windowStart = prefs.getLong("intent_internal.last_summary_run", 0);
        long now = System.currentTimeMillis();

        // If it's the very first run ever, or if the last run was over 24 hours ago, just fallback to start of day
        Calendar cal = Calendar.getInstance();
        cal.set(Calendar.HOUR_OF_DAY, 0);
        cal.set(Calendar.MINUTE, 0);
        cal.set(Calendar.SECOND, 0);
        long startOfDay = cal.getTimeInMillis();

        if (windowStart == 0 || windowStart < startOfDay) {
            windowStart = startOfDay;
        }

        // We use the between query to only sum the specific batched window
        int urgentCount = dao.getCountByCategoryBetween(0, windowStart, now);
        int bufferCount = dao.getCountByCategoryBetween(1, windowStart, now);
        int spamCount = dao.getCountByCategoryBetween(2, windowStart, now);

        if (urgentCount == 0 && bufferCount == 0 && spamCount == 0) {
            prefs.edit().putLong("intent_internal.last_summary_run", now).apply();
            return Result.success();
        }

        // Technically we can still pull the top package for the whole day if we want, 
        // or just bound it. For accuracy, let's just keep the Top Package calculation to today so it's consistent.
        String topBufferPackage = dao.getTopPackageByCategoryForToday(1, startOfDay);
        String readablePackageName = getReadablePackageName(topBufferPackage);

        String textMessage = "Intent Digital Sanctuary: Intercepted " + bufferCount + " Buffer messages";
        if (!readablePackageName.isEmpty()) {
            textMessage += " (mostly from " + readablePackageName + ")";
        }
        textMessage += " and wiped " + spamCount + " Spam alerts.";

        java.util.List<com.intent.intent_app.db.entities.NotificationEntity> bufferedMessages = 
            dao.getInterceptedBetween(windowStart, now);
        
        java.util.ArrayList<String> bufferLines = new java.util.ArrayList<>();
        for (com.intent.intent_app.db.entities.NotificationEntity msg : bufferedMessages) {
            if (msg.category == 1) { // Buffer
                String line = getReadablePackageName(msg.packageName) + ": " + (msg.title != null ? msg.title : "") + " - " + (msg.content != null ? msg.content : "");
                bufferLines.add(line);
            }
        }

        postNotification(context, "Delivery Batch Summary", textMessage, bufferLines);

        prefs.edit().putLong("intent_internal.last_summary_run", now).apply();

        return Result.success();
    }

    private String getReadablePackageName(String packageName) {
        if (packageName == null) return "";
        try {
            android.content.pm.PackageManager pm = getApplicationContext().getPackageManager();
            android.content.pm.ApplicationInfo info = pm.getApplicationInfo(packageName, 0);
            CharSequence label = pm.getApplicationLabel(info);
            if (label != null) {
                return label.toString();
            }
        } catch (android.content.pm.PackageManager.NameNotFoundException e) {
            // Ignore and fallback
        }
        
        // Fallback title-casing
        String[] parts = packageName.split("\\.");
        if (parts.length > 0) {
            String name = parts[parts.length - 1];
            return name.substring(0, 1).toUpperCase() + name.substring(1).toLowerCase();
        }
        return packageName;
    }

    private void postNotification(Context context, String title, String text, java.util.List<String> messages) {
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        if (manager == null) return;

        String channelId = "intent_summary";
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    channelId,
                    "Summary Notifications",
                    NotificationManager.IMPORTANCE_DEFAULT
            );
            channel.setDescription("Periodic summaries of intercepted notifications.");
            manager.createNotificationChannel(channel);
        }

        android.content.SharedPreferences prefs = context.getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE);
        Object maxLinesObj = prefs.getAll().get("flutter.buffer_max_lines");
        int maxBufferLines = 5;
        if (maxLinesObj instanceof Long) {
            maxBufferLines = ((Long) maxLinesObj).intValue();
        } else if (maxLinesObj instanceof Integer) {
            maxBufferLines = (Integer) maxLinesObj;
        } else if (maxLinesObj instanceof String) {
            try {
                maxBufferLines = Integer.parseInt((String) maxLinesObj);
            } catch (Exception e) {}
        }

        StringBuilder sb = new StringBuilder();
        int limit = Math.min(messages.size(), maxBufferLines);
        for (int i = 0; i < limit; i++) {
            sb.append(messages.get(i)).append("\n\n");
        }
        if (messages.size() > limit) {
            sb.append("... and ").append(messages.size() - limit).append(" more.");
        }

        NotificationCompat.BigTextStyle bigTextStyle = new NotificationCompat.BigTextStyle();
        bigTextStyle.setBigContentTitle(title);
        bigTextStyle.setSummaryText(text);
        bigTextStyle.bigText(sb.toString().trim());

        Intent launchIntent = new Intent(context, MainActivity.class);
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent pendingIntent = PendingIntent.getActivity(
                context,
                24680,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, channelId)
                .setSmallIcon(android.R.drawable.sym_def_app_icon)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(bigTextStyle)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT);

        manager.notify(24680, builder.build()); // fixed ID so they overwrite each other rather than pile up
    }
}
