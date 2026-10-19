package com.intent.intent_app;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

/**
 * Production unit tests invoking real IntentBrain production methods directly.
 * Verifies that promotional copy and year numbers are NEVER falsely classified as Urgent,
 * that true OTP/financial/emergency alerts are protected, and that user block rules take precedence.
 */
public class IntentBrainTest {

    // ── 1. REAL PRODUCTION TEST: Prevent False Urgent Classifications ──────
    @Test
    public void testProductionClassifier_RejectsPromotionsAndGenericPhrases() {
        // Sample notifications reported as false positives:
        String promo1 = "Flash sale! Use code 2025 for 20% off";
        String promo2 = "Your membership is 2024 renewed";
        String order1 = "Your order is 1234 on the way";
        String promo3 = "Book your appointment today and save";
        String review1 = "Doctor Strange 2 review: the hospital scene";

        // Must NOT match strict OTP
        assertFalse("Promo code 2025 must not be considered OTP", IntentBrain.isOtp(promo1));
        assertFalse("Year 'is 2024' must not be considered OTP", IntentBrain.isOtp(promo2));
        assertFalse("Order id 'is 1234' must not be considered OTP", IntentBrain.isOtp(order1));
        assertFalse("Appointment promo must not be considered OTP", IntentBrain.isOtp(promo3));
        assertFalse("Movie review must not be considered OTP", IntentBrain.isOtp(review1));

        // Must NOT match critical service
        assertFalse(IntentBrain.isCriticalService(promo1));
        assertFalse(IntentBrain.isCriticalService(promo2));
        assertFalse(IntentBrain.isCriticalService(order1));
        assertFalse("Generic 'appointment' must not be critical service", IntentBrain.isCriticalService(promo3));
        assertFalse("Doctor Strange review must not be critical service", IntentBrain.isCriticalService(review1));

        // Under heuristic evaluation without user rules, none of these should evaluate to 0 (Urgent)
        assertNotEquals("Promo 1 must not evaluate to Urgent (0)", 0, IntentBrain.evaluateHeuristics(promo1, null, null, null, null));
        assertNotEquals("Promo 2 must not evaluate to Urgent (0)", 0, IntentBrain.evaluateHeuristics(promo2, null, null, null, null));
        assertNotEquals("Order 1 must not evaluate to Urgent (0)", 0, IntentBrain.evaluateHeuristics(order1, null, null, null, null));
        assertNotEquals("Promo 3 must not evaluate to Urgent (0)", 0, IntentBrain.evaluateHeuristics(promo3, null, null, null, null));
        assertNotEquals("Review 1 must not evaluate to Urgent (0)", 0, IntentBrain.evaluateHeuristics(review1, null, null, null, null));
    }

    // ── 2. REAL PRODUCTION TEST: True OTP Alerts Detection ────────────────
    @Test
    public void testProductionClassifier_DetectsTrueOtpAlerts() {
        assertTrue(IntentBrain.isOtp("Your one-time password is 482913"));
        assertTrue(IntentBrain.isOtp("Your one-time password is 482913. Do not share."));
        assertTrue(IntentBrain.isOtp("482913 is your verification code to log in. Do not share it."));
        assertTrue(IntentBrain.isOtp("Your Google verification code is 849201"));
        assertTrue(IntentBrain.isOtp("Your verification code is: 849201"));
        assertTrue(IntentBrain.isOtp("Your WhatsApp code: 849201"));
        assertTrue(IntentBrain.isOtp("Your login OTP is 392810. Valid for 5 minutes."));
        assertTrue(IntentBrain.isOtp("Use 948123 as your authentication code"));
        assertTrue(IntentBrain.isOtp("Your OTP is: 123456"));
        assertTrue(IntentBrain.isOtp("Your code is 123456"));
        assertTrue(IntentBrain.isOtp("Your Uber code: 5821"));

        // Evaluate heuristics directly
        assertEquals(0, IntentBrain.evaluateHeuristics("Your one-time password is 482913", null, null, null, null));
        assertEquals(0, IntentBrain.evaluateHeuristics("482913 is your verification code to log in. Do not share it.", null, null, null, null));
        assertEquals(0, IntentBrain.evaluateHeuristics("Your Google verification code is: 849201", null, null, null, null));
        assertEquals(0, IntentBrain.evaluateHeuristics("Your WhatsApp code: 849201", null, null, null, null));
    }

    // ── 3. REAL PRODUCTION TEST: True Financial & Emergency Alerts ─────────
    @Test
    public void testProductionClassifier_DetectsTrueFinancialAndEmergencyAlerts() {
        String bankDebit = "Acct XX1234 debited by INR 450.00 at Starbucks via UPI";
        String cardCharge = "Card ending in 4091 was charged $42.50";
        String ambulance = "Ambulance dispatched to your location";
        String driver = "Your driver is arriving in a White Toyota Prius";
        String packageDelivery = "Your Amazon package is out for delivery";

        assertTrue(IntentBrain.isFinancial(bankDebit));
        assertTrue(IntentBrain.isFinancial(cardCharge));
        assertTrue(IntentBrain.isCriticalService(ambulance));
        assertTrue(IntentBrain.isCriticalService(driver));
        assertTrue(IntentBrain.isCriticalService(packageDelivery));

        assertEquals(0, IntentBrain.evaluateHeuristics(bankDebit, null, null, null, null));
        assertEquals(0, IntentBrain.evaluateHeuristics(cardCharge, null, null, null, null));
        assertEquals(0, IntentBrain.evaluateHeuristics(ambulance, null, null, null, null));
        assertEquals(0, IntentBrain.evaluateHeuristics(driver, null, null, null, null));
        assertEquals(0, IntentBrain.evaluateHeuristics(packageDelivery, null, null, null, null));
    }

    // ── 4. REAL PRODUCTION TEST: User Explicit Block/Buffer Precedence ──────
    @Test
    public void testProductionClassifier_UserBlockRulesTakePrecedence() {
        List<String> blockList = Arrays.asList("flash sale", "swiggy", "discount");
        List<String> bufferList = Collections.singletonList("newsletter");

        // Even if a promotional message mentions "code 2025" or numbers, user's explicit block rule MUST return 2 (Spam)
        String blockedMsg = "Flash sale! Use code 2025 for 20% off";
        assertEquals(2, IntentBrain.evaluateHeuristics(blockedMsg, null, null, null, blockList));

        // Buffer rule precedence over system dictionary
        String bufferMsg = "Your weekly tech newsletter is ready";
        assertEquals(1, IntentBrain.evaluateHeuristics(bufferMsg, null, null, bufferList, null));

        // VIP strictly overrides everything
        List<String> vipList = Collections.singletonList("alice");
        String vipMsg = "Alice: Flash sale at the bookstore!";
        assertEquals(-2, IntentBrain.evaluateHeuristics(vipMsg, vipList, null, null, blockList));
    }

    // ── 5. REAL PRODUCTION TEST: Whole Word Boundary & Short Keywords ──────
    @Test
    public void testProductionClassifier_WordBoundaryAndShortKeywords() {
        // Full word matches
        assertTrue(IntentBrain.containsWord("Hey Ram, how are you?", "ram"));
        assertTrue(IntentBrain.containsWord("RAM is high", "ram"));

        // Substrings inside other words MUST NOT match
        assertFalse(IntentBrain.containsWord("Running a Python program", "ram"));
        assertFalse(IntentBrain.containsWord("Check your grammar", "ram"));
        assertFalse(IntentBrain.containsWord("Message sent via Telegram", "ram"));

        // Short 2-character keywords supported via whole-word boundaries
        assertTrue(IntentBrain.containsWord("Urgent email from HR department", "hr"));
        assertFalse(IntentBrain.containsWord("Will finish in three hours", "hr")); // 'hours' contains 'hr', but not as a word

        assertTrue(IntentBrain.containsWord("Discussion on AI safety", "ai"));
        assertFalse(IntentBrain.containsWord("Wait for train to arrive", "ai")); // 'train' contains 'ai'
    }

    // ── 6. REAL PRODUCTION TEST: Flutter SharedPreferences List Parser ──────
    @Test
    public void testParseFlutterListSafely_HandlesAllEncodings() {
        // 1. Empty Flutter List represented as "!"
        ArrayList<String> emptyList = IntentBrain.parseFlutterListSafely("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!");
        assertTrue(emptyList.isEmpty());

        // 2. Flutter Delimiter Format: "!item1!item2"
        ArrayList<String> delimitedList = IntentBrain.parseFlutterListSafely("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!whatsapp!instagram");
        assertEquals(2, delimitedList.size());
        assertEquals("whatsapp", delimitedList.get(0));
        assertEquals("instagram", delimitedList.get(1));

        // 3. JSON Array Format: '["com.slack", "com.teams"]'
        ArrayList<String> jsonList = IntentBrain.parseFlutterListSafely("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu[\"com.slack\", \"com.teams\"]");
        assertEquals(2, jsonList.size());
        assertEquals("com.slack", jsonList.get(0));

        // 4. Java Collection
        ArrayList<String> collectionList = IntentBrain.parseFlutterListSafely(Arrays.asList("com.signal", "com.telegram"));
        assertEquals(2, collectionList.size());
        assertEquals("com.signal", collectionList.get(0));

        // 5. Null or Empty String
        assertTrue(IntentBrain.parseFlutterListSafely(null).isEmpty());
        assertTrue(IntentBrain.parseFlutterListSafely("").isEmpty());
    }

    // ── 7. REAL PRODUCTION TEST: Friends & Personal Messages Never Classified As Spam ─
    @Test
    public void testProductionClassifier_PersonalMessagesMustNeverBeSpam() {
        String msg1 = "Priya: check out this photo from yesterday";
        String msg2 = "Amit: I’m free tomorrow, want to grab coffee?";
        String msg3 = "Friend: new restaurant opened near us, let’s try it";
        String msg4 = "Sara: thanks for the help with the project";
        String msg5 = "Hey, are you back home yet?";
        String msg6 = "Alex: sent you a video from the concert";
        String msg7 = "Can we meet up today?";

        // Under heuristic evaluation without explicit user block rules, personal messages MUST NOT be Spam (2)
        assertNotEquals("Priya photo message must never be classified as Spam (2)", 2, IntentBrain.evaluateHeuristics(msg1, null, null, null, null));
        assertNotEquals("Amit coffee message must never be classified as Spam (2)", 2, IntentBrain.evaluateHeuristics(msg2, null, null, null, null));
        assertNotEquals("Friend restaurant message must never be classified as Spam (2)", 2, IntentBrain.evaluateHeuristics(msg3, null, null, null, null));
        assertNotEquals("Sara project message must never be classified as Spam (2)", 2, IntentBrain.evaluateHeuristics(msg4, null, null, null, null));
        assertNotEquals("Back home message must never be classified as Spam (2)", 2, IntentBrain.evaluateHeuristics(msg5, null, null, null, null));
        assertNotEquals("Alex video message must never be classified as Spam (2)", 2, IntentBrain.evaluateHeuristics(msg6, null, null, null, null));
        assertNotEquals("Meet today message must never be classified as Spam (2)", 2, IntentBrain.evaluateHeuristics(msg7, null, null, null, null));

        // Friend planning dinner asking to save money must NOT be classified as Spam (2) or buried
        String friendPlan = "WhatsApp. Ravi. can you book a table, we can save money tonight?";
        assertFalse("Friend plan message must not be tagged as promo", IntentBrain.isPromotional(friendPlan));
        assertNotEquals("Friend plan message must never be classified as Spam (2)", 2, IntentBrain.evaluateHeuristics(friendPlan, null, null, null, null));
    }

    // ── 8. REAL PRODUCTION TEST: Promos Safely Routed to Buffer (1) ───────────
    @Test
    public void testProductionClassifier_PromosRoutedToBuffer() {
        String promo1 = "Flash sale! Use code 2025 for 20% off";
        String promo2 = "Your membership is 2024 renewed";
        String promo3 = "Book your appointment today and save";
        String promo4 = "Limited time offer: Flat 30% off with promo code SAVE30";
        String promo5 = "Buy 1 get 1 free today only! Free shipping on orders";

        assertTrue(IntentBrain.isPromotional(promo1));
        assertTrue(IntentBrain.isPromotional(promo2));
        assertTrue(IntentBrain.isPromotional(promo3));
        assertTrue(IntentBrain.isPromotional(promo4));
        assertTrue(IntentBrain.isPromotional(promo5));

        // Promos MUST evaluate to Buffer (1) - neither Urgent (0) nor Spam (2)
        assertEquals(1, IntentBrain.evaluateHeuristics(promo1, null, null, null, null));
        assertEquals(1, IntentBrain.evaluateHeuristics(promo2, null, null, null, null));
        assertEquals(1, IntentBrain.evaluateHeuristics(promo3, null, null, null, null));
        assertEquals(1, IntentBrain.evaluateHeuristics(promo4, null, null, null, null));
        assertEquals(1, IntentBrain.evaluateHeuristics(promo5, null, null, null, null));
    }

    // ── 9. REAL PRODUCTION TEST: Deliberate Family Urgency ─────────────────────
    @Test
    public void testProductionClassifier_FamilySenderDeliberateUrgency() {
        // Real production format inputs generated by IntentNotificationService (appName + ". " + title + ". " + text)
        String prodMom1 = "WhatsApp. Mom. did you eat?";
        String prodMom2 = "Messages. Mom. Call me when you land";
        String prodDad1 = "WhatsApp. Dad. are you back home now?";
        String prodWife = "WhatsApp. Wife. please call me";

        // Raw formats
        String rawMom = "Mom: did you eat?";
        String rawDad = "Dad - are you back home?";
        String promoMentioningMom = "Mother's Day sale! Buy a gift for your mom with code LOVE";

        // Promotional notifications mentioning "Mom" or "Son" in body or title must NEVER be Urgent (0)
        String flipkartPromo = "Flipkart. Sale. Mom. Shop today and save big";
        String cultPromo = "Cult. Cult. Son: this week's new arrivals, shop now";

        // Group chats with family words in their name must NEVER be Urgent (0)
        String momFriendsGroup = "WhatsApp. Mom Friends. meet at 6?";
        String dadJokesGroup = "WhatsApp. Dad Jokes. why did the chicken cross the road?";
        String sisterContact = "WhatsApp. Sister Mary. praying for you";

        // Family senders must be Urgent (0) by deliberate product design ONLY on exact match in BOTH production format and raw format
        assertTrue(IntentBrain.isFamilySender(prodMom1));
        assertTrue(IntentBrain.isFamilySender(prodMom2));
        assertTrue(IntentBrain.isFamilySender(prodDad1));
        assertTrue(IntentBrain.isFamilySender(prodWife));
        assertTrue(IntentBrain.isFamilySender(rawMom));
        assertTrue(IntentBrain.isFamilySender(rawDad));

        // Group chats, contact nicknames, and promos MUST NOT match family sender
        assertFalse(IntentBrain.isFamilySender(promoMentioningMom));
        assertFalse(IntentBrain.isFamilySender(flipkartPromo));
        assertFalse(IntentBrain.isFamilySender(cultPromo));
        assertFalse("Group chat 'Mom Friends' must not be classified as a family sender", IntentBrain.isFamilySender(momFriendsGroup));
        assertFalse("Group chat 'Dad Jokes' must not be classified as a family sender", IntentBrain.isFamilySender(dadJokesGroup));
        assertFalse("Full name 'Sister Mary' must not be classified as exact family relation", IntentBrain.isFamilySender(sisterContact));

        assertEquals(0, IntentBrain.evaluateHeuristics(prodMom1, null, null, null, null));
        assertEquals(0, IntentBrain.evaluateHeuristics(prodMom2, null, null, null, null));
        assertEquals(0, IntentBrain.evaluateHeuristics(prodDad1, null, null, null, null));
        assertEquals(0, IntentBrain.evaluateHeuristics(prodWife, null, null, null, null));
        assertEquals(0, IntentBrain.evaluateHeuristics(rawMom, null, null, null, null));
        assertEquals(0, IntentBrain.evaluateHeuristics(rawDad, null, null, null, null));

        // Promo mentioning "mom" in body or title MUST NOT be Urgent (0)
        assertNotEquals(0, IntentBrain.evaluateHeuristics(promoMentioningMom, null, null, null, null));
        assertNotEquals(0, IntentBrain.evaluateHeuristics(flipkartPromo, null, null, null, null));
        assertNotEquals(0, IntentBrain.evaluateHeuristics(cultPromo, null, null, null, null));
        assertNotEquals("Group chat 'Mom Friends' must never evaluate to Urgent (0)", 0, IntentBrain.evaluateHeuristics(momFriendsGroup, null, null, null, null));
        assertNotEquals("Group chat 'Dad Jokes' must never evaluate to Urgent (0)", 0, IntentBrain.evaluateHeuristics(dadJokesGroup, null, null, null, null));

        // Detailed classification checks
        IntentBrain.ClassificationResult resFlipkart = IntentBrain.evaluateHeuristicsDetailed(flipkartPromo, "Sale", false, null, null, null, null);
        assertNotEquals(0, resFlipkart.category);
        assertNotEquals("FAMILY", resFlipkart.source);

        IntentBrain.ClassificationResult resCult = IntentBrain.evaluateHeuristicsDetailed(cultPromo, "Cult", false, null, null, null, null);
        assertNotEquals(0, resCult.category);
        assertNotEquals("FAMILY", resCult.source);

        // Group conversation 'Mom Friends' is NOT a 1-to-1 direct message (isDirectMessage = false)
        IntentBrain.ClassificationResult resMomFriends = IntentBrain.evaluateHeuristicsDetailed(momFriendsGroup, "Mom Friends", false, null, null, null, null);
        assertNotEquals(0, resMomFriends.category);
        assertNotEquals("FAMILY", resMomFriends.source);

        // Even if passed as direct message, 'Mom Friends' does not exactly match 'mom'
        IntentBrain.ClassificationResult resMomFriendsDm = IntentBrain.evaluateHeuristicsDetailed(momFriendsGroup, "Mom Friends", true, null, null, null, null);
        assertNotEquals("Non-exact family name match must not trigger FAMILY urgency", 0, resMomFriendsDm.category);
        assertNotEquals("FAMILY", resMomFriendsDm.source);

        // Exact match 'Mom' on a 1-to-1 direct message triggers FAMILY urgency
        IntentBrain.ClassificationResult resMom = IntentBrain.evaluateHeuristicsDetailed(prodMom1, "Mom", true, null, null, null, null);
        assertEquals(0, resMom.category);
        assertEquals("FAMILY", resMom.source);
    }

    // ── 10. REAL PRODUCTION TEST: User Explicit Block Honored in Direct Messages
    @Test
    public void testProductionClassifier_UserBlockHonoredEvenInDirectMessages() {
        java.util.List<String> blockList = java.util.Arrays.asList("spambot", "cryptocurrency");

        // WhatsApp direct message from a user-blocked sender
        String blockedChat = "WhatsApp. SpamBot. Join our cryptocurrency pump now";
        IntentBrain.ClassificationResult blockedRes = IntentBrain.evaluateHeuristicsDetailed(
            blockedChat, "SpamBot", true, null, null, null, blockList
        );

        // MUST be Spam (2), with source "USER_BLOCK", and isUserExplicitRule == true
        assertEquals(2, blockedRes.category);
        assertEquals("USER_BLOCK", blockedRes.source);
        assertTrue("User explicit block rule must be marked as explicit rule", blockedRes.isUserExplicitRule);

        // A legitimate chat without user block must NOT be marked as an explicit user block rule
        String regularChat = "WhatsApp. Ravi. Can you book a table, we can save money tonight?";
        IntentBrain.ClassificationResult regularRes = IntentBrain.evaluateHeuristicsDetailed(
            regularChat, "Ravi", true, null, null, null, blockList
        );
        assertFalse("Regular chat is not a user explicit block rule", regularRes.isUserExplicitRule);
        assertNotEquals("Regular chat must not be Spam (2)", 2, regularRes.category);
    }

    // ── 11. REAL PRODUCTION TEST: ML Model & Vocab Asset Integrity ───────────
    @Test
    public void testProductionClassifier_MlAssetsIntegrity() {
        java.io.File tfliteFile = new java.io.File("src/main/assets/lstm.tflite");
        java.io.File vocabFile = new java.io.File("src/main/assets/vocab.json");

        assertTrue("lstm.tflite model file must exist in assets", tfliteFile.exists());
        assertTrue("vocab.json vocabulary file must exist in assets", vocabFile.exists());
        assertTrue("lstm.tflite model must not be empty", tfliteFile.length() > 1000000L); // ~3.5MB
        assertTrue("vocab.json must not be empty", vocabFile.length() > 1000L);
    }

    // ── 12. REAL PRODUCTION TEST: Family 1:1 Messages with Colons & Group Distinction ──
    @Test
    public void testProductionClassifier_FamilyMessagesWithColons_PreserveUrgency() {
        // Real-world 1:1 messages from Mom containing colons (time, notes, addresses, etc.)
        String msg1 = "WhatsApp. Mom. did you eat?";
        String msg2 = "WhatsApp. Mom. Dinner at 8: bring wine";
        String msg3 = "WhatsApp. Mom. Note: call me when you land";
        String msg4 = "WhatsApp. Mom. Time: 6pm, don’t be late";
        String msg5 = "WhatsApp. Mom. Address: 12 MG Road, come soon";

        // All confirmed 1:1 direct messages from Mom MUST be classified as Urgent (0) with source "FAMILY"
        IntentBrain.ClassificationResult r1 = IntentBrain.evaluateHeuristicsDetailed(msg1, "Mom", true, null, null, null, null);
        IntentBrain.ClassificationResult r2 = IntentBrain.evaluateHeuristicsDetailed(msg2, "Mom", true, null, null, null, null);
        IntentBrain.ClassificationResult r3 = IntentBrain.evaluateHeuristicsDetailed(msg3, "Mom", true, null, null, null, null);
        IntentBrain.ClassificationResult r4 = IntentBrain.evaluateHeuristicsDetailed(msg4, "Mom", true, null, null, null, null);
        IntentBrain.ClassificationResult r5 = IntentBrain.evaluateHeuristicsDetailed(msg5, "Mom", true, null, null, null, null);

        assertEquals("Simple message from Mom must be Urgent (0)", 0, r1.category);
        assertEquals("FAMILY", r1.source);
        assertEquals("Message with 'Dinner at 8:' must preserve Urgent (0)", 0, r2.category);
        assertEquals("FAMILY", r2.source);
        assertEquals("Message with 'Note:' must preserve Urgent (0)", 0, r3.category);
        assertEquals("FAMILY", r3.source);
        assertEquals("Message with 'Time:' must preserve Urgent (0)", 0, r4.category);
        assertEquals("FAMILY", r4.source);
        assertEquals("Message with 'Address:' must preserve Urgent (0)", 0, r5.category);
        assertEquals("FAMILY", r5.source);

        // However, if the notification comes from a group chat named "Mom" (isDirectMessage == false),
        // it MUST NOT trigger family urgency:
        String groupNamedMom = "WhatsApp. Mom. Ravi: did you buy it?";
        IntentBrain.ClassificationResult resGroupMom = IntentBrain.evaluateHeuristicsDetailed(
            groupNamedMom, "Mom", false, null, null, null, null
        );
        assertNotEquals("Group chat named 'Mom' must never be Urgent (0)", 0, resGroupMom.category);
        assertNotEquals("Group chat named 'Mom' must not have source 'FAMILY'", "FAMILY", resGroupMom.source);
    }

    // ── 13. REAL PRODUCTION TEST: Personal Messages from Friends ────────────
    @Test
    public void testProductionClassifier_PersonalMessages_NeverFalseUrgentAndNeverSpam() {
        String friend1 = "WhatsApp. Ravi. lunch today?";
        String friend2 = "WhatsApp. Priya. I'm free tomorrow, want to grab coffee?";
        String friend3 = "WhatsApp. Amit. check out this photo from yesterday";
        String friend4 = "WhatsApp. Friend. new restaurant opened near us, let's try it";
        String friend5 = "Messages. Sarah. see you at the cafe";

        // Under heuristic evaluation, none of these should falsely trigger Urgent (0)
        assertNotEquals(0, IntentBrain.evaluateHeuristics(friend1, null, null, null, null));
        assertNotEquals(0, IntentBrain.evaluateHeuristics(friend2, null, null, null, null));
        assertNotEquals(0, IntentBrain.evaluateHeuristics(friend3, null, null, null, null));
        assertNotEquals(0, IntentBrain.evaluateHeuristics(friend4, null, null, null, null));
        assertNotEquals(0, IntentBrain.evaluateHeuristics(friend5, null, null, null, null));

        // Under heuristic evaluation without user blocks, none should be classified as Spam (2)
        assertNotEquals(2, IntentBrain.evaluateHeuristics(friend1, null, null, null, null));
        assertNotEquals(2, IntentBrain.evaluateHeuristics(friend2, null, null, null, null));
        assertNotEquals(2, IntentBrain.evaluateHeuristics(friend3, null, null, null, null));
        assertNotEquals(2, IntentBrain.evaluateHeuristics(friend4, null, null, null, null));
        assertNotEquals(2, IntentBrain.evaluateHeuristics(friend5, null, null, null, null));

        // When detailed heuristics are evaluated:
        // Ordinary chat messages should fall through to FALLBACK (-1)
        IntentBrain.ClassificationResult res1 = IntentBrain.evaluateHeuristicsDetailed(friend1, "Ravi", true, null, null, null, null);
        IntentBrain.ClassificationResult res2 = IntentBrain.evaluateHeuristicsDetailed(friend2, "Priya", true, null, null, null, null);
        IntentBrain.ClassificationResult res3 = IntentBrain.evaluateHeuristicsDetailed(friend3, "Amit", true, null, null, null, null);

        assertEquals(-1, res1.category);
        assertEquals("FALLBACK", res1.source);
        assertEquals(-1, res2.category);
        assertEquals("FALLBACK", res2.source);
        assertEquals(-1, res3.category);
        assertEquals("FALLBACK", res3.source);

        // However, if a friend sends a true emergency keyword, it DOES elevate to Urgent (0)
        String friendEmergency = "WhatsApp. Ravi. Emergency! In the hospital, please call immediately";
        IntentBrain.ClassificationResult resEmergency = IntentBrain.evaluateHeuristicsDetailed(friendEmergency, "Ravi", true, null, null, null, null);
        assertEquals(0, resEmergency.category);
        assertEquals("SYSTEM_URGENT", resEmergency.source);
    }
}
