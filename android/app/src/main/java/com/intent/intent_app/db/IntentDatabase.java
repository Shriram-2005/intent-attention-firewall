package com.intent.intent_app.db;

import android.content.Context;

import androidx.room.Database;
import androidx.room.Room;
import androidx.room.RoomDatabase;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;

import com.intent.intent_app.db.dao.NotificationDao;
import com.intent.intent_app.db.entities.NotificationEntity;

/**
 * Singleton configuration for the Intent fallback database.
 * Destructively replaces the legacy architecture on version 2 upgrade.
 */
@Database(entities = {NotificationEntity.class}, version = 6, exportSchema = false)
public abstract class IntentDatabase extends RoomDatabase {

    private static final String DB_NAME = "intent_database";
    private static volatile IntentDatabase INSTANCE;
    public static volatile boolean isLockedForRestore = false;

    public abstract NotificationDao notificationDao();

    static final Migration MIGRATION_2_3 = new Migration(2, 3) {
        @Override
        public void migrate(SupportSQLiteDatabase database) {
            database.execSQL("ALTER TABLE notifications ADD COLUMN inference_latency INTEGER NOT NULL DEFAULT 0");
        }
    };

    static final Migration MIGRATION_3_4 = new Migration(3, 4) {
        @Override
        public void migrate(SupportSQLiteDatabase database) {
            database.execSQL("ALTER TABLE notifications ADD COLUMN context_multiplier REAL NOT NULL DEFAULT 1.5");
        }
    };

    static final Migration MIGRATION_4_5 = new Migration(4, 5) {
        @Override
        public void migrate(SupportSQLiteDatabase database) {
            database.execSQL("ALTER TABLE notifications ADD COLUMN feedback_score REAL NOT NULL DEFAULT 0.0");
            database.execSQL("ALTER TABLE notifications ADD COLUMN interaction_time INTEGER NOT NULL DEFAULT 0");
        }
    };

    static final Migration MIGRATION_5_6 = new Migration(5, 6) {
        @Override
        public void migrate(SupportSQLiteDatabase database) {
            database.execSQL("ALTER TABLE notifications ADD COLUMN user_confidence REAL NOT NULL DEFAULT 1.0");
        }
    };

    public static IntentDatabase getInstance(Context context) {
        if (INSTANCE == null) {
            synchronized (IntentDatabase.class) {
                if (INSTANCE == null) {
                    INSTANCE = Room.databaseBuilder(
                            context.getApplicationContext(),
                            IntentDatabase.class,
                            DB_NAME
                    )
                    .addMigrations(MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5, MIGRATION_5_6)
                    .fallbackToDestructiveMigration() // Wipe the legacy V1 format safely
                    .build();
                }
            }
        }
        return INSTANCE;
    }

    public static void resetInstance() {
        if (INSTANCE != null) {
            INSTANCE.close();
            INSTANCE = null;
        }
    }
}
