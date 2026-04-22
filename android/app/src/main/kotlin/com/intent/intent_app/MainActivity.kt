package com.intent.intent_app

import com.intent.intent_app.channels.DbMethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.provider.Settings
import android.content.Intent
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit
import android.app.AppOpsManager

class MainActivity : FlutterActivity() {

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(android.content.Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        } else {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        }
        if (mode == AppOpsManager.MODE_DEFAULT) {
            return checkCallingOrSelfPermission(android.Manifest.permission.PACKAGE_USAGE_STATS) == android.content.pm.PackageManager.PERMISSION_GRANTED
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private lateinit var dbChannel: DbMethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Ensure Buffer Scheduled Delivery is immediately enqueued on startup
        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
        val defaultIntervalObj = prefs.all["flutter.buffer_interval"]
        val intervalHours = if (defaultIntervalObj is Number) {
            defaultIntervalObj.toInt()
        } else if (defaultIntervalObj is String) {
            defaultIntervalObj.toIntOrNull() ?: 24
        } else {
            24
        }

        val requestBuilder = if (intervalHours == 1) {
            PeriodicWorkRequestBuilder<IntentSummaryWorker>(15, TimeUnit.MINUTES)
        } else {
            PeriodicWorkRequestBuilder<IntentSummaryWorker>(intervalHours.toLong(), TimeUnit.HOURS)
        }

        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
            "IntentSummaryWork",
            ExistingPeriodicWorkPolicy.KEEP,
            requestBuilder.build()
        )

        // Register the Flutter ↔ Room DB method channel bridge
        dbChannel = DbMethodChannel(applicationContext)
        dbChannel.register(flutterEngine)

        // Register the Flutter permissions bridge
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.intent.intent_app/permissions")
                .setMethodCallHandler { call, result ->
                    val isGranted = androidx.core.app.NotificationManagerCompat.getEnabledListenerPackages(context).contains(packageName)

                    if (call.method == "permissions.check") {
                        val hasUsage = hasUsageStatsPermission()
                        val hasOverlay = Settings.canDrawOverlays(context)
                        result.success(mapOf("notification" to isGranted, "usage" to hasUsage, "overlay" to hasOverlay))
                    } else if (call.method == "permissions.request") {
                        if (!isGranted) {
                            try {
                                val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                            } catch (e: Exception) {
                                val intent = Intent(Settings.ACTION_SETTINGS)
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                            }
                        }
                        result.success(isGranted)
                    } else if (call.method == "permissions.requestUsage") {
                         val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                         intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                         startActivity(intent)
                         result.success(true)
                    } else if (call.method == "permissions.requestOverlay") {
                         val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, android.net.Uri.parse("package:$packageName"))
                         intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                         startActivity(intent)
                         result.success(true)
                    } else {
                        result.notImplemented()
                    }
                }



        // Register the Flutter Settings / WorkManager bridge
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.intent.intent_app/settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "settings.updateSummaryInterval") {
                    val intervalHours = call.argument<Int>("intervalHours") ?: 24
                    
                    val requestBuilder = if (intervalHours == 1) {
                        // 1 Hour UI selection maps to the 15-minute aggressive test mode
                        PeriodicWorkRequestBuilder<IntentSummaryWorker>(15, TimeUnit.MINUTES)
                    } else {
                        PeriodicWorkRequestBuilder<IntentSummaryWorker>(intervalHours.toLong(), TimeUnit.HOURS)
                    }

                    WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
                        "IntentSummaryWork",
                        ExistingPeriodicWorkPolicy.REPLACE,
                        requestBuilder.build()
                    )
                    
                    result.success(true)
                } else if (call.method == "settings.updateEndOfDay") {
                    val hour = call.argument<Int>("hour") ?: 21
                    val minute = call.argument<Int>("minute") ?: 0

                    val now = java.util.Calendar.getInstance()
                    val target = java.util.Calendar.getInstance().apply {
                        set(java.util.Calendar.HOUR_OF_DAY, hour)
                        set(java.util.Calendar.MINUTE, minute)
                        set(java.util.Calendar.SECOND, 0)
                        set(java.util.Calendar.MILLISECOND, 0)
                    }

                    if (target.before(now)) {
                        target.add(java.util.Calendar.DAY_OF_YEAR, 1)
                    }

                    val delay = target.timeInMillis - now.timeInMillis
                    val requestBuilder = PeriodicWorkRequestBuilder<EndOfDayWorker>(24, TimeUnit.HOURS)
                        .setInitialDelay(delay, TimeUnit.MILLISECONDS)

                    WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
                        "EndOfDayWork",
                        ExistingPeriodicWorkPolicy.REPLACE,
                        requestBuilder.build()
                    )
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }

        // Register the Telemetry EventChannel for DriveSafety Engine
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.intent.intent_app/telemetry")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (events != null) {
                        com.intent.intent_app.DriveSafetyEngine.getInstance(applicationContext).startTelemetryTracking(events)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    com.intent.intent_app.DriveSafetyEngine.getInstance(applicationContext).stopTelemetryTracking()
                }
            })
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        com.intent.intent_app.DriveSafetyEngine.getInstance(applicationContext).stopTelemetryTracking()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
