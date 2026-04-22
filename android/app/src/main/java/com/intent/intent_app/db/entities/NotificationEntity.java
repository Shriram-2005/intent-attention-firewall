package com.intent.intent_app.db.entities;

import androidx.room.ColumnInfo;
import androidx.room.Entity;
import androidx.room.PrimaryKey;
import androidx.room.Ignore;

/**
 * ML-Intercepted Notification Entity.
 */
@Entity(tableName = "notifications")
public class NotificationEntity {

    @PrimaryKey(autoGenerate = true)
    public long id;

    @ColumnInfo(name = "package_name")
    public String packageName;

    @ColumnInfo(name = "title")
    public String title;

    @ColumnInfo(name = "content")
    public String content;

    @ColumnInfo(name = "timestamp")
    public long timestamp; // Unix epoch ms

    @ColumnInfo(name = "category")
    public int category; // 0=Urgent, 1=Buffer, 2=Spam

    @ColumnInfo(name = "inference_latency")
    public long inferenceLatency; // Inference execution time in ms

    @ColumnInfo(name = "context_multiplier")
    public float contextMultiplier; // 3.0x if driving, 0.5x if late night, else 1.5x

    @ColumnInfo(name = "feedback_score")
    public float feedbackScore; // Phase 1: Explicit user action (+1.0 = click, -1.0 = quick dismiss, 0.0 = passive)

    @ColumnInfo(name = "interaction_time")
    public long interactionTime; // TTD (Time-To-Dismiss) or TTA (Time-To-Action) in ms

    @ColumnInfo(name = "user_confidence")
    public float userConfidence; // ML Confidence tuning

    public NotificationEntity() {}

    @Ignore
    public NotificationEntity(String packageName, String title, String content, long timestamp, int category, long inferenceLatency, float contextMultiplier) { 
        this.packageName = packageName;
        this.title = title;
        this.content = content;
        this.timestamp = timestamp;
        this.category = category;
        this.inferenceLatency = inferenceLatency;
        this.contextMultiplier = contextMultiplier;
        this.feedbackScore = 0.0f; // Default passive
        this.interactionTime = 0; // Default none
        this.userConfidence = 1.0f; // Default baseline
    }
}
