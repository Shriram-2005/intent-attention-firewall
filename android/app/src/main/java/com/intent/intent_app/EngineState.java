package com.intent.intent_app;

public class EngineState {
    // Global flags for the Focus Locker feature
    public static volatile boolean isFocusTimerActive = false;
    public static volatile boolean isUserCurrentlyDistracted = false;
}
