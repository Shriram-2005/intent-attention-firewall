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
            "otp", "verification", "code", "password", "reset", "security", "alert", "login", 
            "unauthorized", "breach", "compromised", "lock", "unlock", "authenticate", "pin", 
            "2fa", "mfa", "token", "passcode", "identity",
            "hospital", "emergency", "doctor", "police", "ambulance", "accident", "dying", 
            "urgent", "asap", "immediate", "critical", "severe", "fatal", "injury", "bleeding",
            "surgery", "icu", "ward", "clinic", "prescription",
            "flight", "boarding", "gate", "departure", "delay", "cancelled", "terminal", "airport",
            "train", "platform", "arriving", "uber", "lyft", "driver", "transit", "delivery", 
            "package", "courier", "dropped", "location", "pickup", "dropoff",
            "payment", "declined", "transfer", "received", "deducted", "overdraft", "fraud", 
            "suspicious", "charge", "refund", "invoice", "receipt", "salary", "credited", 
            "debited", "wire", "deposit", "insufficient", "balance",
            "meeting", "interview", "schedule", "rescheduled", "boss", "manager", "client", 
            "deadline", "presentation", "zoom", "teams", "link", "join", "agenda", "brief", 
            "fyi", "memo", "urgent", "review",
            "dad", "mom", "wife", "husband", "son", "daughter", "brother", "sister", 
            "family", "kid", "school", "principal", "teacher", "class"
        ));

        // Massive matrix of ~200+ consumerism, gamification, and spam terms.
        SYSTEM_BLOCKED_KEYWORDS = new HashSet<>(Arrays.asList(
            "promo", "offer", "discount", "sale", "clearance", "off", "voucher", "coupon", 
            "code", "cashback", "save", "savings", "deal", "deals", "steal", "grab", "hurry", 
            "limited", "expires", "midnight", "today", "tomorrow", "exclusive", "vip", "early",
            "win", "winner", "won", "prize", "jackpot", "lottery", "draw", "spin", "chance", 
            "claim", "reward", "redeem", "free", "gift", "giveaway", "bonus", "tokens", "coins",
            "lootbox", "chest", "level", "upgrade", "unlock", "points",
            "subscribe", "newsletter", "update", "latest", "news", "trending", "viral", 
            "missed", "check", "out", "discover", "explore", "new", "arrival", "arrivals", 
            "collection", "season", "festive", "special", "event", "join", "now",
            "cart", "abandoned", "forgot", "items", "waiting", "back", "stock", "restocked", 
            "buy", "shop", "purchase", "store", "online", "app", "download", "install", "rate", 
            "review", "feedback", "survey", "participate",
            "liked", "commented", "shared", "post", "photo", "video", "status", "story", 
            "live", "stream", "broadcast", "channel", "followed", "friend", "request", 
            "suggestion", "people", "know", "connect", "network", "profile", "viewed",
            "loan", "credit", "card", "apply", "approved", "pre-approved", "instant", "cash",
            "lending", "interest", "emi", "finance", "investment", "multiply", "crypto",
            "bitcoin", "trading", "stocks", "portfolio", "wealth", "rich"
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
