package com.intent.intent_app;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.regex.Pattern;

/**
 * Production unit tests verifying parser stability, keyword boundaries, and zero-drop OTP safeguards.
 */
public class IntentBrainTest {

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

    @Test
    public void testOtpPattern_MatchesAllCriticalVariations() {
        Pattern otpPattern = Pattern.compile(
            "(?i)\\b(?:one[- ]?time\\s*(?:pass(?:word)?|code|pin)|otp|verification\\s*code|auth(?:entication)?\\s*code|security\\s*(?:code|alert|pin)|login\\s*code|secret\\s*code|passcode)\\b|" +
            "(?i)\\b(?:is|code|pin|password)[:\\s]+[0-9]{4,8}\\b|" +
            "(?i)\\b[0-9]{4,8}\\s+is\\s+(?:your\\s+)?(?:verification|one[- ]?time|security|login|otp)\\b"
        );

        // Typical bank / app variations
        assertTrue(otpPattern.matcher("Your one-time password is 482913. Do not share.").find());
        assertTrue(otpPattern.matcher("Use 948123 as your login verification code.").find());
        assertTrue(otpPattern.matcher("Your OTP is: 123456").find());
        assertTrue(otpPattern.matcher("Your Chase security code is 554321").find());
        assertTrue(otpPattern.matcher("982341 is your Google verification code").find());
        assertTrue(otpPattern.matcher("Secret passcode: 4321").find());

        // Regular non-OTP messages should NOT trigger false positive
        assertFalse(otpPattern.matcher("Hey, are you free for lunch today?").find());
        assertFalse(otpPattern.matcher("50% off discount on all shoes!").find());
    }

    @Test
    public void testFinancialPattern_DetectsTransactions() {
        Pattern financialPattern = Pattern.compile(
            "(?i)\\b(?:credited|debited|transferred|withdrawn|charged|txn|transaction|card\\s*ending|acct?\\s*ending|account\\s*ending|bank\\s*alert|payment\\s*of|paid\\s*(?:rs\\.?|inr|\\$|€|£))\\b"
        );

        assertTrue(financialPattern.matcher("Your account ending in 4091 was debited for $42.50").find());
        assertTrue(financialPattern.matcher("Txn of INR 5,000 completed successfully.").find());
        assertTrue(financialPattern.matcher("Card ending 1234 was charged.").find());
        assertFalse(financialPattern.matcher("Just read a nice book on financial history.").find());
    }

    @Test
    public void testWordBoundary_PreventsFalseSubstringMatches() {
        String keyword = "ram";
        String regex = "(?i)\\b" + Pattern.quote(keyword) + "\\b";
        Pattern pattern = Pattern.compile(regex);

        // Whole word should match
        assertTrue(pattern.matcher("Hey Ram, how are you?").find());
        assertTrue(pattern.matcher("RAM is here").find());

        // Substrings inside other words MUST NOT match
        assertFalse(pattern.matcher("Check out this new computer program.").find());
        assertFalse(pattern.matcher("Please correct your grammar.").find());
        assertFalse(pattern.matcher("Sent via Telegram").find());
    }
}
