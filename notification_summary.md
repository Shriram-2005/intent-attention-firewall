# Intent - Notification Posting Summary

The Intent app natively generates and overrides Android notifications to protect the user's attention. To do this, it utilizes a headless Java-based daemon (`IntentNotificationService`) and a background worker (`IntentSummaryWorker`), completely bypassing the Flutter isolate to guarantee zero battery drain and true real-time processing.

Here are the specific types of notifications the app gives to the user and exactly how they work under the hood:

### 1. Reposted "Buffer" Notifications
**What it is:** When a notification is intercepted and classified as "Buffer" (Category 1) but the user is not currently marked as "distracted" by the Engine.
**How it works:**
- The `IntentNotificationService` forcibly intercepts and **vaporizes** the original application's notification (e.g., Instagram, Twitter) from the system tray using `cancelNotification(sbn.getKey())`.
- The service instantly builds a *replica* notification using Android's `Notification.Builder`.
- It copies over the original `Icon`, `PendingIntent` (so clicking it still opens the original app), and the `title`.
- It prefixes the text payload with `[Buffer] ` to clearly label its origins.
- Finally, it reposts the replica on incredibly silent parameters via the native `manager.notify()` targeting `"intent_buffer_channel"`. 
- This ensures the notification waits quietly in the shade without vibrating or buzzing the user.

### 2. Daily Telemetry Summary Notifications
**What it is:** A daily digest report summarizing how much time and attention the Intent app saved the user.
**How it works:**
- Powered by `IntentSummaryWorker` (an Android `WorkManager` job).
- Upon waking, the worker directly queries the Android `Room` Database (`NotificationDao`) to pull the count of `Urgent`, `Buffer`, and `Spam` intercepts since the `startOfDay` (midnight).
- If the counts are zero, the worker sleeps silently to save battery.
- If notifications were blocked, it calculates exactly which app was the biggest offender (`topBufferPackage`) and structures a human-readable telemetry payload:
  *"Intent Digital Sanctuary: Intercepted 14 Buffer messages (mostly from Instagram) and wiped 3 Spam alerts."*
- It posts this notification onto the `"intent_summary"` channel (with `IMPORTANCE_DEFAULT`).
- It intentionally uses a hardcoded integer notification ID (`24680`) so that subsequent summary notifications automatically overwrite each other, preventing "spamming the user about spam."

### 3. Artificial Auditory Overrides for "Urgent" Messages
**What it is:** Though not a *new* visual notification, Intent hijacks the Android OS auditory framework to ensure you hear `Urgent` notifications (Category 0) even if the source app is muted.
**How it works:**
- When an `Urgent` classification is made by `IntentBrain`, the system allows the original notification to pass through completely organically.
- However, to ensure the user actually grabs their phone for the emergency or vital text, the `IntentNotificationService` explicitly fires `playUrgentSound()`.
- This function bypasses standard application-level mutes by grabbing the `RingtoneManager.TYPE_NOTIFICATION` default URI and forcing the `Ringtone` class to `play()` directly.
- **Why?** This architectural decision allows users to leave apps like WhatsApp natively turned onto silent, trusting Intent to manually ring the phone *only* when the AI detects the message is actually important.

--- 

### TL;DR Flow
1. **Spam** -> Erased permanently (logged selectively in DB). No notification.
2. **Buffer** -> Erased organically, repackaged with a `[Buffer]` tag, and delivered silently.
3. **Urgent** -> Passed through flawlessly with a forced system-level ringtone ping.
4. **End of Day** -> Background worker wakes up and tallies the score into a single Telemetry Summary Notification.