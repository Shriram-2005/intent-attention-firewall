# Intent App - Future Deployments & Roadmap

While the current build of Intent is highly optimized as a robust, native-Android solution with a focus on immediate privacy and hardware-level interception, the following milestones outline the strategic roadmap for future scaling, deployments, and feature expansions.

---

## Phase 1: Architecture Simplification & Global Reach

### 1. Dart-Native Database Migration
- **Current State:** The app relies on Android's `Room` database natively (accessed via Java) to ensure zero-latency notification sorting in the background without waking the Flutter isolate.
- **Future Deployment:** Transitioning to a high-performance Dart-native database (like Isar or FFI SQLite) combined with Flutter background isolates. This will unify the codebase, making the core heuristic engine fully cross-platform.

### 2. Internationalization (i18n) & Localization
- **Current State:** The UI and engine are hardcoded for English.
- **Future Deployment:** Implement full `flutter_localizations`. The AI engine's NLP (Natural Language Processing) tokenizer will need to be upgraded to recognize urgency structures, spam patterns, and sentiment in multiple languages (e.g., Spanish, Hindi, Mandarin).

### 3. iOS Feasibility & Expansion
- **Current State:** Locked to Android because iOS strictly prohibits raw OS-level notification interception (`NotificationListenerService`).
- **Future Deployment:** Develop an iOS-specific module leveraging Apple's ScreenTime API, Focus Filters, and PushKit to simulate the Buffer/Urgent system within Apple's walled garden, allowing for a future App Store deployment.

---

## Phase 2: Advanced Engine Capabilities

### 4. Local On-Device Transformer Models
- **Current State:** Notification category sorting is actively powered by a local LSTM (Long Short-Term Memory) neural network.
- **Future Deployment:** Upgrade the NLP engine to a lightweight, quantized transformer model such as MobileBERT or DistilBERT. This will allow the app to achieve much deeper bidirectional semantic understanding of messages without ever sending data to a cloud server, drastically improving zero-day spam blocking and contextual priority routing instead of relying strictly on sequential word dependencies.

### 5. Context-Aware Smart Profiles
- **Current State:** Buffer rules and VIP lists are manually toggled or statically scheduled.
- **Future Deployment:** The app will use Wi-Fi SSIDs, geofencing, and calendar events to automatically shift profiles. (e.g., Switching from "Work Mode" where Slack is buffered, to "Home Mode" where Slack is blocked entirely but family texts become Urgent).

---

## Phase 3: Ecosystem Integrations

### 6. Wearable Integration (Wear OS)
- **Current State:** Wearables receive whatever the phone pushes out.
- **Future Deployment:** A companion Wear OS app that syncs directly with the Intent engine. Buffered notifications will be silently queued on the watch without vibrating the user's wrist, while Urgent pings bypass the watch's DND settings to ensure immediate hardware feedback.

### 7. End-to-End Encrypted (E2EE) Cloud Sync
- **Current State:** Database backups are strictly local/manual (exporting SQLite `.db` payload) to guarantee 100% privacy.
- **Future Deployment:** Introduce a completely opt-in, zero-knowledge encrypted cloud sync. Using the user's own Google Drive (via limited-scope tokens) combined with local AES-256 encryption, allowing users to seamlessly transition between devices without manual file sharing, while retaining mathematical guarantees that nobody else can read their notification history.
