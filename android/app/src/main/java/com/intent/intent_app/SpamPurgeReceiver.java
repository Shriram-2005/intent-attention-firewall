package com.intent.intent_app;

import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import com.intent.intent_app.db.IntentDatabase;

import java.util.concurrent.Executors;

public class SpamPurgeReceiver extends BroadcastReceiver {
    private static final String TAG = "SpamPurgeReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        Log.i(TAG, "Spam Purge Triggered in Background!");

        // Cancel Summary Notification
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        if (manager != null) {
            manager.cancel(24680); // Exact ID from IntentSummaryWorker
        }

        // Silent Delete via Room Database
        Executors.newSingleThreadExecutor().execute(() -> {
            try {
                IntentDatabase.getInstance(context).notificationDao().deleteAllSpam();
                Log.i(TAG, "Spam successfully annihilated.");
            } catch (Exception e) {
                Log.e(TAG, "Failed to purge spam DB.", e);
            }
        });
    }
}
