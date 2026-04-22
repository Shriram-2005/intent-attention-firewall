# Intent App - Features & Capabilities

## Feature Summary

1. AI-Powered Notification Interception & Sorting
2. VIP Contacts & Keyword Detection (Whitelist)
3. Buffer Delivery System
4. Spam & Distraction Blocking
5. "Do-or-Die" Driving Safety Matrix (Hardware Telemetry)
6. Pure OLED Dark Mode UI & Glassmorphism Design
7. Local Data Privacy & Manual Export/Import
8. Live Analytics & Insights

---

## Detailed Explanations

### 1. AI-Powered Notification Interception & Sorting
The core engine of Intent intercepts incoming Android notifications in real-time. Using an intelligent heuristic model, it categorizes every notification into three tiers:
- **Urgent:** Allowed to ping you immediately.
- **Buffer:** Held back silently and delivered in batches during scheduled intervals.
- **Blocked/Spam:** Completely muted and hidden from your daily view.

### 2. VIP Contacts & Keyword Detection (Whitelist)
You have total control over who can break through your focus. 
- **VIP Contacts:** Add specific people (like family members or your boss) whose messages will always bypass the buffer and notify you immediately.
- **Keywords:** Set up critical keywords (e.g., "OTP", "Emergency", "Flight") that trigger an immediate alert regardless of the app or sender.

### 3. Buffer Delivery System
Instead of being interrupted 100 times a day, Intent groups non-urgent messages (like social media likes, group chat chatter, or newsletters) and delivers them at intervals you choose. You can also configure the maximum number of buffered messages shown on the lock screen to prevent visual clutter.

### 4. Spam & Distraction Blocking
Constant promotional messages and algorithmic spam are automatically caught by the engine and muted. You can review these blocked notifications securely in the "Notification History" log to ensure nothing important was missed, and easily train the engine to be more accurate over time.

### 5. "Do-or-Die" Driving Safety Matrix (Hardware Telemetry)
Intent actively monitors live hardware sensor streams (like raw GPS and compass data) to calculate a "Driving Safety Matrix". When the app detects you are operating a moving vehicle, it seamlessly transitions into a hyper-strict filtering mode to prevent fatal distractions.

### 6. Pure OLED Dark Mode UI & Glassmorphism Design
Built with a sleek, minimalist aesthetic, Intent features a "True OLED" black background (`#000000`) paired with smooth animations and Apple-inspired glassmorphism effects (blurred backdrops and translucent panels), offering a premium, distraction-free visual experience.

### 7. Local Data Privacy & Manual Export/Import
Intent is built with radical privacy. Your notification data never leaves your device and is never uploaded to the cloud. Google Drive auto-backups are aggressively disabled (`allowBackup="false"`) by default. If you switch phones, you can manually backup your local `.db` SQLite database via a secure native file exporter and import it to your new device to retain your customized AI heuristic weights.

### 8. Live Analytics & Insights
The app provides a beautiful, data-rich Insights dashboard to track your digital well-being.
- **Cognitive Focus Retained:** Calculates the exact amount of uninterrupted time the app gave back to you.
- **Literal Screen Time Avoided:** Measures the minutes saved by not picking up your phone.
- **Visual Charts:** Includes temporal data graphs, contextual radar charts, and source pie charts to help you understand your notification habits. Use the "AI Coach" to generate automated evaluations of your distraction vulnerabilities.
