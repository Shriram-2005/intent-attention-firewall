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
import com.intent.intent_app.db.entities.NotificationEntity;

import java.util.Calendar;
import java.util.List;

public class EndOfDayWorker extends Worker {

    public EndOfDayWorker(@NonNull Context context, @NonNull WorkerParameters workerParams) {
        super(context, workerParams);
    }

    @NonNull
    @Override
    public Result doWork() {
        Context context = getApplicationContext();

        IntentDatabase db = IntentDatabase.getInstance(context);
        NotificationDao dao = db.notificationDao();

        Calendar cal = Calendar.getInstance();
        cal.set(Calendar.HOUR_OF_DAY, 0);
        cal.set(Calendar.MINUTE, 0);

        cal.set(Calendar.SECOND, 0);
        cal.set(Calendar.MILLISECOND, 0);
        
        long startTime = cal.getTimeInMillis();
        long endTime = System.currentTimeMillis();

        int urgentCount = dao.getCountByCategoryBetween(0, startTime, endTime);
        int bufferCount = dao.getCountByCategoryBetween(1, startTime, endTime);
        int spamCount = dao.getCountByCategoryBetween(2, startTime, endTime);

        List<NotificationEntity> intercepted = dao.getInterceptedBetween(startTime, endTime);
        double cognitiveMins = 0.0;
        long lastBurstTimestamp = 0;

        for (NotificationEntity n : intercepted) {
            if (lastBurstTimestamp == 0 || (n.timestamp - lastBurstTimestamp) > 120000) {
                // New burst
                cognitiveMins += (1.5 * n.contextMultiplier);
                lastBurstTimestamp = n.timestamp;
            }
        }

        int minsSaved = (int) cognitiveMins;
        String contentText = "You saved " + minsSaved + " mins of deep focus today.";

        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        String channelId = "EndOfDayReport";
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(channelId, "End Of Day Report", NotificationManager.IMPORTANCE_DEFAULT);
            manager.createNotificationChannel(channel);
        }

        Intent launchIntent = new Intent(context, MainActivity.class);
        launchIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        PendingIntent pendingIntent = PendingIntent.getActivity(context, 1001, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        NotificationCompat.InboxStyle inboxStyle = new NotificationCompat.InboxStyle()
                .setBigContentTitle("Intent Daily Summary")
                .addLine("You reclaimed " + minsSaved + " mins of deep focus.")
                .addLine("Urgent: " + urgentCount)
                .addLine("Buffered: " + bufferCount)
                .addLine("Spam Blocked: " + spamCount)
                .setSummaryText("Tap to view full insights");

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, channelId)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Daily Focus Analyzed")
                .setContentText(contentText)
                .setStyle(inboxStyle)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true);

        manager.notify(2002, builder.build());

        return Result.success();
    }
}


