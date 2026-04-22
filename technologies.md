# Intent App - Technologies Used

## Technology Stack Summary

1. **Flutter & Dart**
2. **Android Native (Java) & OS APIs**
3. **Local Machine Learning (LSTM Neural Network)**
4. **Android Room Database (SQLite)**
5. **Riverpod & Freezed**
6. **Google Generative AI (Gemini)**
7. **Hardware Sensor Capabilities (Telemetry)**
8. **Native Bridge & Utility Packages (`share_plus`, `file_picker`, `fl_chart`)**

---

## Detailed Explanations

### 1. Flutter & Dart
The primary framework used for the beautifully crafted, high-performance user interface. Dart powers the reactive front-end logic, smooth 60fps+ animations, and intricate UI elements like the Apple-inspired Glassmorphism (`BackdropFilter`) and True OLED dark themes.

### 2. Android Native (Java) & OS APIs
Because Intent requires profound system-level access, the core notification engine is written in native Java. It specifically uses Android's `NotificationListenerService` to intercept, analyze, and selectively mute or buffer incoming notifications in the background before they ever reach the user's screen. Dart and Java communicate seamlessly via `MethodChannel`.

### 3. Local Machine Learning (LSTM Neural Network)
To maintain pure privacy, the app uses an on-device LSTM (Long Short-Term Memory) neural network. This allows the application to perform local Natural Language Processing (NLP) to read incoming message streams, detect temporal dependencies, and accurately classify notifications into Urgent, Buffer, or Spam tiers without relying on cloud computation.

### 4. Android Room Database (SQLite)
Instead of using a Flutter-side database, data persistence is maintained natively via Android's Room Persistence Library. This is a highly strategic choice, allowing the background `NotificationListenerService` to write thousands of log entries at high speed directly into SQLite without waking up the Flutter isolate, preserving battery life and RAM.

### 5. Riverpod & Freezed
For scalable, immutable state management within the Flutter frontend, the project utilizes `flutter_riverpod` paired with `freezed`. This combination ensures rock-solid data binding and reactive UI updates while completely avoiding "Spaghetti Code" or unnecessary widget rebuilds.

### 6. Google Generative AI (Gemini)
The app integrates the `google_generative_ai` SDK to power the "AI Coach" feature inside the Analytics and Insights engine. When triggered by the user, it processes metadata (anonymized) to generate high-level coaching advice on digital well-being and distraction vulnerabilities.

### 7. Hardware Sensor Capabilities (Telemetry)
The "Do-or-Die" Driving Safety Matrix feature connects directly to the device's hardware sensors. By actively querying raw GPS velocity and compass trajectory, the app constructs a dynamic profile of the user's physical motion, automatically shifting into a hyper-strict notification filtration mode when driving is detected.

### 8. Native Bridge & Utility Packages
To connect the robust backend with the sleek UI, several key packages are utilized:
- **`share_plus` & `file_picker`:** Used for the radical privacy features, allowing users to safely export their `.db` files and CSV audits or import database backups directly from their device storage.
- **`fl_chart`:** Renders the complex, beautiful Temporal, Contextual, and ROI data visualizations in the Analytics dashboard.
- **`pdf`:** Generates formatted export reports natively on the device.
