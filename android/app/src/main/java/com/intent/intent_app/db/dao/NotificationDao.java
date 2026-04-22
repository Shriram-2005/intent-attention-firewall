package com.intent.intent_app.db.dao;

import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.OnConflictStrategy;
import androidx.room.Query;

import com.intent.intent_app.db.entities.NotificationEntity;

import java.util.List;

/**
 * Access interface for intercepted notifications.
 */
@Dao
public interface NotificationDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insert(NotificationEntity notification);

    @Query("SELECT * FROM notifications ORDER BY timestamp DESC")
    List<NotificationEntity> getAllHistory();

    @Query("SELECT * FROM notifications WHERE timestamp BETWEEN :start AND :end ORDER BY timestamp DESC")
    List<NotificationEntity> getHistoryBetween(long start, long end);

    @Query("DELETE FROM notifications WHERE timestamp < :timestamp")
    void deleteHistoryBefore(long timestamp);

    @Query("DELETE FROM notifications WHERE timestamp BETWEEN :start AND :end")
    void deleteHistoryBetween(long start, long end);

    @Query("DELETE FROM notifications")
    void deleteAllHistory();

    @Query("DELETE FROM notifications WHERE category = 2")
    void deleteAllSpam();
    @Query("SELECT COUNT(*) FROM notifications WHERE category = :category AND timestamp >= :startOfDay")
    int getCountByCategoryForToday(int category, long startOfDay);

    @Query("SELECT COUNT(*) FROM notifications WHERE category = :category AND timestamp BETWEEN :startTime AND :endTime")
    int getCountByCategoryBetween(int category, long startTime, long endTime);

    @Query("SELECT package_name FROM notifications WHERE category = :category AND timestamp >= :startOfDay GROUP BY package_name ORDER BY COUNT(*) DESC LIMIT 1")
    String getTopPackageByCategoryForToday(int category, long startOfDay);      

    @Query("SELECT AVG(inference_latency) FROM notifications WHERE timestamp >= :startOfDay AND inference_latency > 0")
    float getAverageLatencyToday(long startOfDay);

    @Query("SELECT AVG(inference_latency) FROM notifications WHERE timestamp BETWEEN :startTime AND :endTime AND inference_latency > 0")
    float getAverageLatencyBetween(long startTime, long endTime);

    @Query("SELECT * FROM notifications WHERE timestamp >= :startOfDay AND category IN (1, 2) ORDER BY timestamp ASC")
    List<NotificationEntity> getInterceptedForToday(long startOfDay);

    @Query("SELECT * FROM notifications WHERE timestamp BETWEEN :startTime AND :endTime AND category IN (1, 2) ORDER BY timestamp ASC")
    List<NotificationEntity> getInterceptedBetween(long startTime, long endTime);

    @Query("UPDATE notifications SET feedback_score = :newScore, interaction_time = :ttd WHERE package_name = :packageName AND timestamp > :timestamp")
    void updateFeedbackScore(String packageName, long timestamp, float newScore, long ttd);
}
