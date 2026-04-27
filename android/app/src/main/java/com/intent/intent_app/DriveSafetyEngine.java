package com.intent.intent_app;

import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;

import org.json.JSONObject;

import io.flutter.plugin.common.EventChannel;

public class DriveSafetyEngine implements LocationListener, SensorEventListener {

    private static final String TAG = "DriveSafetyEngine";
    private static DriveSafetyEngine instance;

    private final Context context;
    private final LocationManager locationManager;
    private final SensorManager sensorManager;

    private Sensor accelerometer;
    private Sensor magnetometer;

    private final float[] gravity = new float[3];
    private final float[] geomagnetic = new float[3];

    private double currentHeading = 0.0;
    private int currentSpeedKmh = 0;

    private boolean isDriving = false;
    private long lastLocationTimestamp = 0;
    private EventChannel.EventSink activeEventSink;

    private boolean isTelemetryMode = false;

    private DriveSafetyEngine(Context context) {
        this.context = context.getApplicationContext();
        this.locationManager = (LocationManager) this.context.getSystemService(Context.LOCATION_SERVICE);
        this.sensorManager = (SensorManager) this.context.getSystemService(Context.SENSOR_SERVICE);

        if (sensorManager != null) {
            accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
            magnetometer = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD);
        }
    }

    public static synchronized DriveSafetyEngine getInstance(Context context) {
        if (instance == null) {
            instance = new DriveSafetyEngine(context);
        }
        return instance;
    }

    /**
     * Boot the Background-Tier protocol (Low Power).
     * Used by IntentNotificationService to protect battery.
     */
    public void startBackgroundTracking() {
        if (isTelemetryMode) return; // Prevent downgrading if UI is open

        try {
            locationManager.removeUpdates(this);
            // Distance threshold: 50 meters. Interval: 30 seconds.
            locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 30000, 50, this);
            locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 30000, 50, this);
            Log.i(TAG, "[DriveEngine] Locked-Screen Background Tracking Engaged.");
        } catch (SecurityException e) {
            Log.e(TAG, "Missing Background Location Permission.", e);
        }
    }

    /**
     * Boot the Telemetry-Tier protocol (High Power).
     * Binds sensors and aggressive precision.
     */
    public void startTelemetryTracking(EventChannel.EventSink sink) {
        this.activeEventSink = sink;
        this.isTelemetryMode = true;

        try {
            locationManager.removeUpdates(this);
            // Distance threshold: 0 meters. Interval: 500 ms.
            locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 500, 0, this);
            locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 500, 0, this);
            
            if (sensorManager != null && accelerometer != null && magnetometer != null) {
                sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_UI);
                sensorManager.registerListener(this, magnetometer, SensorManager.SENSOR_DELAY_UI);
            }
            Log.i(TAG, "[DriveEngine] Ultra-Precision Telemetry Engaged.");
        } catch (SecurityException e) {
            Log.e(TAG, "Missing Location Permission.", e);
        }
    }

    /**
     * Return explicitly to Low Power background matrix.
     */
    public void stopTelemetryTracking() {
        this.activeEventSink = null;
        this.isTelemetryMode = false;
        if (sensorManager != null) {
            sensorManager.unregisterListener(this);
        }
        startBackgroundTracking(); 
    }

    public boolean isDriving() {
        // Fail-safe: If we haven't received a GPS update in 2 minutes (120,000ms), 
        // assume we are no longer driving to prevent indefinitely locking the device 
        // if the user goes into a tunnel or underground garage.
        if (System.currentTimeMillis() - lastLocationTimestamp > 120000) {
            setDrivingState(false);
        }
        return isDriving;
    }

    private void setDrivingState(boolean newState) {
        if (this.isDriving == newState) return;
        this.isDriving = newState;
        
        android.app.NotificationManager nm = (android.app.NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null) return;

        if (this.isDriving) {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                android.app.NotificationChannel channel = new android.app.NotificationChannel(
                        "driving_mode_channel",
                        "Driving Mode Alerts",
                        android.app.NotificationManager.IMPORTANCE_DEFAULT);
                nm.createNotificationChannel(channel);
            }
            
            android.app.Notification.Builder builder;
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                builder = new android.app.Notification.Builder(context, "driving_mode_channel");
            } else {
                builder = new android.app.Notification.Builder(context);
            }
            
            android.app.Notification notif = builder
                    .setContentTitle("Driving Mode Enabled")
                    .setContentText("Do-Or-Die engine active. Only VIP contacts allowed.")
                    .setSmallIcon(android.R.drawable.ic_dialog_map)
                    .setOngoing(true)
                    .build();
            nm.notify(9999, notif);
        } else {
            nm.cancel(9999);
        }
    }

    // --- LOCATION LISTENER ---

    @Override
    public void onLocationChanged(@NonNull Location location) {
        lastLocationTimestamp = System.currentTimeMillis();
        
        if (location.hasSpeed()) {
            float speedMs = location.getSpeed();
            this.currentSpeedKmh = (int) (speedMs * 3.6f);

            android.content.SharedPreferences prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
            long thresholdLong = prefs.getLong("flutter.driving_speed_threshold", 20L);
            int threshold = (int) thresholdLong;

            setDrivingState(this.currentSpeedKmh >= threshold);

            pushTelemetrySlice();
        } else {
            // If GPS regains signal but cannot calculate vector speed yet, gracefully decay
            setDrivingState(false);
        }
    }

    @Override public void onStatusChanged(String provider, int status, Bundle extras) {}
    @Override public void onProviderEnabled(@NonNull String provider) {}
    @Override public void onProviderDisabled(@NonNull String provider) {}


    // --- SENSOR LISTENER ---

    @Override
    public void onSensorChanged(SensorEvent event) {
        if (event.sensor.getType() == Sensor.TYPE_ACCELEROMETER) {
            System.arraycopy(event.values, 0, gravity, 0, event.values.length);
        } else if (event.sensor.getType() == Sensor.TYPE_MAGNETIC_FIELD) {
            System.arraycopy(event.values, 0, geomagnetic, 0, event.values.length);
        }

        if (gravity != null && geomagnetic != null) {
            float[] R = new float[9];
            float[] I = new float[9];
            if (SensorManager.getRotationMatrix(R, I, gravity, geomagnetic)) {
                float[] orientation = new float[3];
                SensorManager.getOrientation(R, orientation);
                
                // Convert azimuth to degrees
                double rawHeading = Math.toDegrees(orientation[0]);
                this.currentHeading = (rawHeading >= 0) ? rawHeading : (360 + rawHeading);
                
                pushTelemetrySlice();
            }
        }
    }

    @Override public void onAccuracyChanged(Sensor sensor, int accuracy) {}

    private long lastTelemetryPush = 0;

    private void pushTelemetrySlice() {
        if (activeEventSink == null) return;
        
        long now = System.currentTimeMillis();
        // Throttle flutter stream to max ~200ms ticks to prevent overloading UI thread
        if (now - lastTelemetryPush < 200) return;
        lastTelemetryPush = now;

        try {
            JSONObject slice = new JSONObject();
            slice.put("speed", currentSpeedKmh);
            slice.put("heading", currentHeading);

            // Stream must fire to main thread
            new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> {
                if (activeEventSink != null) {
                    try {
                        activeEventSink.success(slice.toString());
                    } catch (Exception e) {
                        Log.w(TAG, "Flutter JNI Detached (Likely Hot Reload). Safely terminating zombie telemetry sink.");
                        activeEventSink = null;
                        isTelemetryMode = false;
                    }
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "JSON Math failed", e);
        }
    }
}
