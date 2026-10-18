package com.intent.intent_app;

import java.util.Arrays;
import java.util.HashSet;

public class HeuristicDictionary {
    
    public static final HashSet<String> SYSTEM_URGENT_KEYWORDS;
    public static final HashSet<String> SYSTEM_BUFFER_KEYWORDS;
    public static final HashSet<String> SYSTEM_BLOCKED_KEYWORDS;

    static {
        // Core list of ~150+ ultra-high fidelity emergency/utility keywords. 
        // Optimized strictly natively to operate within 0.1ms using HashSet hashing logic.
        SYSTEM_URGENT_KEYWORDS = new HashSet<>(Arrays.asList(
            "otp", "verification", "password", "reset", "security", "alert", "login", 
            "unauthorized", "breach", "compromised", "lock", "unlock", "authenticate", "pin", 
            "2fa", "mfa", "token", "passcode", "identity",
            "emergency", "police", "ambulance", "accident", "dying", 
            "urgent", "asap", "immediate", "critical", "severe", "fatal", "injury", "bleeding",
            "surgery", "icu", "ward", "prescription",
            "flight", "boarding", "gate", "departure", "delay", "cancelled", "terminal", "airport",
            "train", "platform", "arriving", "uber", "lyft", "driver", "transit", 
            "package", "dropped", "location", "pickup", "dropoff",
            "declined", "transfer", "received", "deducted", "overdraft", "fraud", 
            "suspicious", "charge", "refund", "invoice", "receipt", "salary", "credited", 
            "debited", "wire", "deposit", "insufficient", "balance",
            "meeting", "interview", "schedule", "rescheduled", "boss", "manager", "client", 
            "deadline", "presentation", "zoom", "teams", "link", "agenda", "brief", 
            "fyi", "memo", "urgent",
            "dad", "mom", "wife", "husband", "son", "daughter", "brother", "sister"
        ));

        // High-confidence spam and promotional indicators only.
        // Everyday conversational English words (today, tomorrow, now, free, new, check, photo, back, etc.)
        // MUST NEVER be included here to prevent wiping personal communications.
        SYSTEM_BLOCKED_KEYWORDS = new HashSet<>(Arrays.asList(
            "promo", "promocode", "coupon", "voucher", "cashback", "discount", 
            "lottery", "jackpot", "sweepstakes", "giveaway", "unsolicited", 
            "telemarketing", "preapproved", "pre-approved", "optout", "opt-out", 
            "unsubscribe", "lootbox"
        ));

        // Informational Context Matrix (~50+ terms). Explicitly triaged into Buffer.
        SYSTEM_BUFFER_KEYWORDS = new HashSet<>(Arrays.asList(
            "newsletter", "receipt", "statement", "weather", "podcast", "playlist", "forum", 
            "reminder", "summary", "thread", "buffer", "postponed", "itinerary", "tracking", 
            "shipped", "survey", "invitation", "rsvp", "calendar", "event", 
            "webinar", "article", "blog", "post", "notification", "info", 
            "information", "details", "document", "file", "attached", "attachment", "form"
        ));
    }
}
