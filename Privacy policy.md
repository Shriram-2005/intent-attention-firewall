# Privacy Policy — Intent

**Last updated:** April 24, 2026
**Developer:** Shriram A U — Intent Labs
**App name:** Intent — Attention Firewall
**Package name:** com.intentlabs.intent

---

## Overview

Intent is built on a single non-negotiable principle: **your notification data is yours alone.**

The core functionality of Intent — notification interception, AI classification, VIP bypass, driving detection, and analytics — operates entirely on your device. No raw notification content is ever transmitted to any server, under any circumstance.

---

## 1. Information We Collect

### 1.1 Data Collected and Stored Locally (On Your Device Only)

Intent collects and stores the following data exclusively in a local SQLite database on your device:

| Data Type | Purpose | Stored Where |
|---|---|---|
| Notification metadata | Classification and triage | Local Room DB only |
| App package names | Identifying notification source | Local Room DB only |
| Classification result (Urgent/Buffer/Spam) | Analytics dashboard | Local Room DB only |
| Timestamp of notification | Timeline analytics | Local Room DB only |
| TFLite inference latency (ms) | Performance tracking | Local Room DB only |
| Focus Time Saved metrics | Dashboard display | Local Room DB only |
| VIP contact identifiers | Bypass logic | Local device only |
| GPS speed readings | Driving mode detection | Never stored — real-time only |

**Raw notification content (message text, sender names, notification body) is processed in memory only and is never written to any database or transmitted anywhere.**

### 1.2 Data Sent to External Services (Optional — User Initiated Only)

Intent has one optional cloud feature — the AI Cognitive Coach. This feature is:
- Disabled by default
- Requires explicit user activation via toggle
- Can be disabled at any time

When enabled, Intent sends **only the following anonymized aggregate statistics** to Google Gemini 2.5 Flash API:

| Data Sent | Example |
|---|---|
| Total urgent count | 38 |
| Total buffered count | 42 |
| Total blocked count | 42 |
| Focus time saved (minutes) | 91.5 |
| Date range of report | 2026-04-16 to 2026-04-17 |

**What is never sent:**
- Notification content or text
- Sender names or contact information
- App-specific notification details
- Device identifiers
- Location data
- Any personally identifiable information (PII)

### 1.3 Data We Do Not Collect

Intent does not collect, store, or transmit:

- Your name, email address, or any account information
- Notification message content or body text
- Contact names or phone numbers
- Photos, files, or media
- Precise or approximate location (GPS data is processed in real-time and immediately discarded)
- Device identifiers (IMEI, advertising ID, Android ID)
- Crash reports to external servers
- Usage analytics to third-party services
- Any data for advertising purposes

---

## 2. Permissions

Intent requires the following Android permissions. Each permission is used exclusively for the stated purpose:

### BIND_NOTIFICATION_LISTENER_SERVICE
**Why required:** This is the core permission that allows Intent to intercept incoming notifications at the Android OS level for classification.

**What we do with it:** Read notification metadata for real-time triage. Raw content is processed in memory only and never stored or transmitted.

**What we don't do:** Read your personal messages, access notification content for any purpose other than classification, or share this data with anyone.

### ACCESS_FINE_LOCATION
**Why required:** Detecting device speed via GPS sensor to activate driving safety mode.

**What we do with it:** Calculate real-time speed only. When speed exceeds 20 km/h, driving lockdown mode is activated.

**What we don't do:** Store your location, track your movements, log GPS coordinates, or transmit location data anywhere. Speed readings are processed in real-time and immediately discarded.

### FOREGROUND_SERVICE
**Why required:** Keeps the notification classification engine running reliably in the background.

**What we do with it:** Maintain a persistent background service for real-time notification interception.

### READ_CONTACTS (Optional)
**Why required:** VIP Contact matching — allows you to designate specific contacts whose notifications always bypass AI filtering.

**What we do with it:** Match incoming notification senders against your VIP list stored locally on your device.

**What we don't do:** Upload, sync, or transmit your contacts anywhere.

### INTERNET
**Why required:** Optional AI Cognitive Coach feature only.

**What we do with it:** Send anonymized aggregate statistics to Gemini API when the AI Coach feature is explicitly enabled by the user.

---

## 3. How We Use Your Data

| Purpose | Data Used | Sent Externally? |
|---|---|---|
| Real-time notification classification | Notification metadata | Never |
| VIP contact bypass | Contact identifiers | Never |
| Driving safety mode | GPS speed reading | Never |
| Dashboard analytics | Aggregate counts | Never |
| AI Cognitive Coach report | Anonymized totals only | Yes — Gemini API only when enabled |
| Focus streak tracking | Daily focus metrics | Never |

---

## 4. Data Storage and Security

### Local Storage
All data is stored in an Android Room Database (SQLite) on your device. This database is:
- Protected by Android's application sandbox
- Not accessible to other applications
- Not backed up to cloud services unless you explicitly enable Android's backup service

### Data Retention
You have full control over your data:
- Clear all data at any time via Settings → Data Management → Clear All Data
- Export your data as CSV via Settings → Data Management → Export to CSV
- Uninstalling the app permanently deletes all locally stored data

### No External Servers
Intent Labs does not operate any servers, databases, or backend infrastructure. There is no Intent Labs server that receives, stores, or processes your data.

---

## 5. Third-Party Services

### Google Gemini 2.5 Flash API
Used exclusively for the optional AI Cognitive Coach feature.

- **Provider:** Google LLC
- **Data sent:** Anonymized aggregate statistics only (see Section 1.2)
- **Google's Privacy Policy:** https://policies.google.com/privacy
- **When active:** Only when user explicitly enables AI Coach toggle
- **Can be disabled:** Yes — toggle off in Insights screen at any time

### Google Play Billing (In-App Purchases)
Used for the optional "Support Intent Labs" donation feature.

- **Provider:** Google LLC
- **Data handled:** Payment processing only — handled entirely by Google Play
- **Intent Labs receives:** No payment data — only confirmation of successful transaction
- **Google's Privacy Policy:** https://policies.google.com/privacy

### No Other Third-Party Services
Intent does not integrate with:
- Analytics platforms (Firebase Analytics, Mixpanel, etc.)
- Advertising networks (AdMob, Meta Audience Network, etc.)
- Crash reporting services (Crashlytics, Sentry, etc.)
- Social media SDKs
- Any other third-party data collection service

---

## 6. Children's Privacy

Intent is not directed at children under the age of 13. We do not knowingly collect any personal information from children under 13. If you are a parent or guardian and believe your child has provided personal information through Intent, please contact us at the email below and we will delete such information immediately.

---

## 7. Your Rights and Choices

### Access and Deletion
Since all data is stored locally on your device, you have complete control:
- **View your data:** All data is visible in the Intent dashboard and audit log
- **Export your data:** Settings → Data Management → Export to CSV
- **Delete your data:** Settings → Data Management → Clear All Data
- **Delete everything:** Uninstall the app

### Opt-Out of AI Coach
The AI Cognitive Coach feature that sends data to Gemini API can be disabled at any time:
- Open Intent → Insights tab → Toggle "AI Coach Enabled" to OFF

Once disabled, no data is sent externally.

### Notification Permission
You can revoke Intent's notification listener permission at any time:
- Settings → Apps → Intent → Permissions → Notifications

Revoking this permission will disable the core classification functionality.

---

## 8. Data Breach Notification

In the unlikely event of a security incident affecting Intent's local data processing, we will notify affected users through an app update and Play Store communication within 72 hours of becoming aware of the incident.

Given Intent's offline-first architecture, the attack surface for data breaches is extremely limited — there are no external servers holding your data that could be compromised.

---

## 9. Changes to This Privacy Policy

We may update this Privacy Policy from time to time. When we do:
- The "Last updated" date at the top will be revised
- Significant changes will be communicated via an in-app notification
- Continued use of Intent after changes constitutes acceptance of the updated policy

---

## 10. Contact Us

If you have any questions, concerns, or requests regarding this Privacy Policy or Intent's data practices, please contact:

**Developer:** Shriram A U
**Studio:** Intent Labs
**Email:** intentlabs.dev@gmail.com
**GitHub:** https://github.com/Shriram-2005/intent-attention-firewall

We aim to respond to all privacy-related inquiries within 48 hours.

---

## 11. Governing Law

This Privacy Policy is governed by the laws of India. Any disputes arising from this policy shall be subject to the jurisdiction of courts in India.

---

*Intent was built on the belief that your attention is yours to protect — and so is your data.*
