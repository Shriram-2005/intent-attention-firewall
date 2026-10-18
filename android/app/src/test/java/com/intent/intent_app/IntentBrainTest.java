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
        assertTrue(IntentBrain.isOtp("Your login OTP is 392810. Valid for 5 minutes."));
        assertTrue(IntentBrain.isOtp("Use 948123 as your authentication code"));

        // Evaluate heuristics directly
        assertEquals(0, IntentBrain.evaluateHeuristics("Your one-time password is 482913", null, null, null, null));
        assertEquals(0, IntentBrain.evaluateHeuristics("482913 is your verification code to log in. Do not share it.", null, null, null, null));
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
}
