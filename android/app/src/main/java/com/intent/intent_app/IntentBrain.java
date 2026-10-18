package com.intent.intent_app;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.AssetFileDescriptor;
import android.util.Log;

import org.json.JSONObject;
import org.tensorflow.lite.Interpreter;

import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.util.HashMap;
import java.util.Iterator;

public class IntentBrain {
    private static final String TAG = "IntentBrain";
    private static final int MAX_LENGTH = 64;
    private static final int OOV_TOKEN = 1;

    private Interpreter tflite;
    private final HashMap<String, Integer> vocabulary = new HashMap<>();
    private boolean isInitialized = false;
    private Context mContext;

    public static java.util.ArrayList<String> cachedAbsoluteVip = null;
    public static java.util.ArrayList<String> cachedUrgent = null;
    public static java.util.ArrayList<String> cachedBuffer = null;
    public static java.util.ArrayList<String> cachedSpam = null;

    public void forceReloadKeywords(android.content.Intent intent) {
        if (intent.hasExtra("absolute_vip")) {
            cachedAbsoluteVip = intent.getStringArrayListExtra("absolute_vip");
        }
        if (intent.hasExtra("urgent")) {
            cachedUrgent = intent.getStringArrayListExtra("urgent");
        }
        if (intent.hasExtra("buffer")) {
            cachedBuffer = intent.getStringArrayListExtra("buffer");
        }
        if (intent.hasExtra("spam")) {
            cachedSpam = intent.getStringArrayListExtra("spam");
        }
    }

    public IntentBrain(Context context) {
        mContext = context;
        try {
            loadVocabulary(context);
            MappedByteBuffer tfliteModel = loadModelFile(context);
            
            Interpreter.Options options = new Interpreter.Options();
            options.setNumThreads(2);
            tflite = new Interpreter(tfliteModel, options);
            
            isInitialized = true;
            Log.i(TAG, "IntentBrain successfully initialized and ready for inference.");
        } catch (Exception e) {
            Log.e(TAG, "CRITICAL: Failed to initialize IntentBrain ML Engine.", e);
            isInitialized = false;
        }
    }

    private void loadVocabulary(Context context) throws Exception {
        InputStream is = context.getAssets().open("vocab.json");
        int size = is.available();
        byte[] buffer = new byte[size];
        is.read(buffer);
        is.close();

        String jsonString = new String(buffer, "UTF-8");
        JSONObject jsonObject = new JSONObject(jsonString);

        Iterator<String> keys = jsonObject.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            vocabulary.put(key, jsonObject.getInt(key));
        }
        Log.i(TAG, "Loaded vocabulary size: " + vocabulary.size());
    }

    private MappedByteBuffer loadModelFile(Context context) throws Exception {
        AssetFileDescriptor fileDescriptor = context.getAssets().openFd("lstm.tflite");
        FileInputStream inputStream = new FileInputStream(fileDescriptor.getFileDescriptor());
        FileChannel fileChannel = inputStream.getChannel();
        long startOffset = fileDescriptor.getStartOffset();
        long declaredLength = fileDescriptor.getDeclaredLength();
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength);
    }

    private float[][] tokenize(String text) {
        float[][] tokenized = new float[1][MAX_LENGTH];
        
        if (text == null || text.trim().isEmpty()) {
            return tokenized; // Return zeroes
        }

        // 1. Convert to lowercase
        String lower = text.toLowerCase();
        
        // 2. Strip basic punctuation (keeping alphanumeric and spaces)
        String stripped = lower.replaceAll("[^a-zA-Z0-9 ]", "");
        
        // 3. Split into words
        String[] words = stripped.split("\\s+");
        
        // 4. Map to integers and sequence
        int index = 0;
        for (String word : words) {
            if (word.isEmpty()) continue;
            
            // Reached max length, truncate
            if (index >= MAX_LENGTH) break;
            
            Integer token = vocabulary.get(word);
            if (token != null) {
                tokenized[0][index] = token;
            } else {
                // Out of Vocabulary
                tokenized[0][index] = OOV_TOKEN;
            }
            index++;
        }
        
        // Note: The rest of the array remains 0.0f (padding). Keras pad_sequences defaults to PRE-padding, 
        // but if post-padding is required by your model it's naturally achieved here. If pre-padding is needed,
        // we'd shift the tokens right. Assuming standard post-padding for simplicity here.

        return tokenized;
    }

    public int classifyNotification(String text) {
        try {
            // 1. Check Engine Selection from Flutter UI safely
            SharedPreferences prefs = mContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
            long engineType = 1; // Default to Neural
            try {
                Object engineObj = prefs.getAll().get("flutter.engine_type");
                if (engineObj instanceof Long) {
                    engineType = (Long) engineObj;
                } else if (engineObj instanceof Integer) {
                    engineType = ((Integer) engineObj).longValue();
                } else if (engineObj instanceof String) {
                    engineType = Long.parseLong((String) engineObj);
                }
            } catch (Exception parseE) {
                Log.w(TAG, "Could not strict-cast engine_type, defaulting to Neural.", parseE);
            }
            
            int heuristicResult = executeHeuristicMatching(text, prefs);
            
            if (heuristicResult == -2) return -2; // VIP Strict Bypass
            
            if (engineType == 0) {
                // RUN EXPLICIT HEURISTIC ENGINE ONLY
                return heuristicResult == -1 ? 1 : heuristicResult; // 1 (Buffer) is the final safe fallback if heuristic returns -1
            }

            // RUN NEURAL TFLITE HYBRID ENGINE
            // 1. If Heuristics explicitly matched ANY of the 6 core arrays, trust it and override ML!
            if (heuristicResult != -1) {
                return heuristicResult;
            }

            // 2. If Heuristics couldn't confidently place it, invoke ML inference!
            if (!isInitialized || tflite == null) {
                Log.e(TAG, "Inference attempted but LSTM is not initialized. Defaulting to Buffer (1).");
                return 1; // Failsafe to Buffer to protect data
            }

            float[][] input = tokenize(text);
            float[][] output = new float[1][3]; // [Urgent, Buffer, Spam]
            
            tflite.run(input, output);

            // Find max probability index (ArgMax)
            float maxProb = -1.0f;
            int maxIndex = -1;
            
            for (int i = 0; i < 3; i++) {
                if (output[0][i] > maxProb) {
                    maxProb = output[0][i];
                    maxIndex = i;
                }
            }
            
            
            Log.d(TAG, "Classification Result - Index: " + maxIndex + ", Confidence: " + maxProb);
            
            // Safety Check: If the Neural Engine is not highly confident, 
            // always default to Buffer so the user can see and review it manually.
            if (maxProb < 0.70f) {
                Log.d(TAG, "Neural confidence below 0.70 threshold. Defaulting to Buffer (1).");
                return 1;
            }
            
            return maxIndex;

        } catch (Exception e) {
            Log.e(TAG, "CRITICAL: Error during notification classification! Forcing BUFFER.", e);
            return 1; // Failsafe to Buffer on crash to prevent data loss
        }
    }

    /**
     * Resilient parser for Flutter SharedPreferences string lists.
     * Safely handles Collection, Flutter '!' delimiter format, JSON arrays, and comma lists.
     */
    public static java.util.ArrayList<String> parseFlutterListSafely(Object prefObj) {
        java.util.ArrayList<String> list = new java.util.ArrayList<>();
        if (prefObj == null) return list;

        if (prefObj instanceof java.util.Collection) {
            for (Object obj : (java.util.Collection<?>) prefObj) {
                if (obj != null) {
                    String s = obj.toString().toLowerCase().trim();
                    if (!s.isEmpty()) list.add(s);
                }
            }
            return list;
        }

        String raw = prefObj.toString().trim();
        if (raw.isEmpty()) return list;

        String prefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu";
        String content = raw.startsWith(prefix) ? raw.substring(prefix.length()) : raw;

        // An empty Flutter list is encoded as "!" or empty string
        if (content.isEmpty() || content.equals("!")) {
            return list;
        }

        try {
            // Flutter shared_preferences uses '!' delimiter format: "!item1!item2" or "!item"
            if (content.startsWith("!")) {
                String[] items = content.substring(1).split("!");
                for (String item : items) {
                    String trimmed = item.trim().toLowerCase();
                    if (!trimmed.isEmpty()) list.add(trimmed);
                }
                return list;
            }

            // JSON array format: ["item1", "item2"]
            if (content.startsWith("[")) {
                try {
                    org.json.JSONArray arr = new org.json.JSONArray(content);
                    for (int i = 0; i < arr.length(); i++) {
                        String s = arr.getString(i).toLowerCase().trim();
                        if (!s.isEmpty()) list.add(s);
                    }
                    return list;
                } catch (Exception ignored) {
                    String inner = content.substring(1, content.length() - (content.endsWith("]") ? 1 : 0));
                    String[] items = inner.split(",");
                    for (String item : items) {
                        String trimmed = item.trim().toLowerCase();
                        if (!trimmed.isEmpty()) list.add(trimmed);
                    }
                    return list;
                }
            }

            // Fallback comma/newline split
            if (content.contains(",") || content.contains("\n")) {
                String[] items = content.split("[,\\n]+");
                for (String item : items) {
                    String trimmed = item.trim().toLowerCase();
                    if (!trimmed.isEmpty()) list.add(trimmed);
                }
                return list;
            }

            // Single string entry
            list.add(content.toLowerCase().trim());
        } catch (Exception ignored) {}
        return list;
    }

    private static final java.util.regex.Pattern PHONE_PATTERN = 
        java.util.regex.Pattern.compile("^\\+?[0-9\\s\\-\\(\\)]{7,18}$");

    private static boolean isPhoneNumber(String str) {
        if (str == null || str.trim().isEmpty()) return false;
        String trimmed = str.trim();
        int digits = 0;
        for (char c : trimmed.toCharArray()) {
            if (Character.isDigit(c)) digits++;
        }
        return digits >= 7 && PHONE_PATTERN.matcher(trimmed).matches();
    }

    private static boolean matchesPhoneInText(String text, String targetPhone) {
        String targetDigits = targetPhone.replaceAll("[^0-9]", "");
        if (targetDigits.length() < 7) return false;
        
        java.util.regex.Matcher m = java.util.regex.Pattern.compile("\\+?[0-9]{1,4}?[-.\\s]?\\(?\\d{2,4}?\\)?[-.\\s]?\\d{3,4}[-.\\s]?\\d{3,4}").matcher(text);
        while (m.find()) {
            String candidateDigits = m.group().replaceAll("[^0-9]", "");
            if (candidateDigits.equals(targetDigits) || 
                (candidateDigits.endsWith(targetDigits) && candidateDigits.length() - targetDigits.length() <= 3) ||
                (targetDigits.endsWith(candidateDigits) && targetDigits.length() - candidateDigits.length() <= 3)) {
                return true;
            }
        }
        return false;
    }

    private static final java.util.concurrent.ConcurrentHashMap<String, java.util.regex.Pattern> sPatternCache = 
        new java.util.concurrent.ConcurrentHashMap<>();

    static java.util.regex.Pattern getWordPattern(String keyword) {
        if (keyword == null) return null;
        String trimmed = keyword.trim().toLowerCase();
        if (trimmed.isEmpty()) return null;
        return sPatternCache.computeIfAbsent(trimmed, kw -> 
            java.util.regex.Pattern.compile("(?i)\\b" + java.util.regex.Pattern.quote(kw) + "\\b")
        );
    }

    /**
     * Matches whole word boundary cleanly so 'ram' doesn't match 'program' or 'grammar'.
     * Supports keywords of length 2 and up (e.g. 'hr', 'ai', 'dr', 'ui').
     */
    static boolean containsWord(String text, String keyword) {
        if (text == null || keyword == null) return false;
        String trimmed = keyword.trim();
        if (trimmed.length() < 2) return false;
        try {
            java.util.regex.Pattern p = getWordPattern(trimmed);
            return p != null && p.matcher(text).find();
        } catch (Exception e) {
            return false;
        }
    }

    // High-confidence regex patterns with strict contextual signals
    // Requires explicit OTP terminology (one-time passcode, verification code, auth pin, etc.)
    // Does NOT match generic promotional numbers ("use code 2025") or years ("is 2024")
    private static final java.util.regex.Pattern STRICT_OTP_PATTERN = java.util.regex.Pattern.compile(
        "(?i)\\b(?:one[- ]?time\\s*(?:pass(?:word|code)?|pin)|otp|verification\\s*(?:code|pin)|auth(?:entication)?\\s*(?:code|pin)|security\\s*(?:code|pin)|login\\s*(?:code|pin)|2fa\\s*code)\\b[:\\s#\\-]*[0-9]{4,8}\\b|" +
        "(?i)\\b[0-9]{4,8}\\s+(?:is\\s+(?:your\\s+)?)?(?:one[- ]?time\\s*(?:pass(?:word|code)?|pin)|otp|verification\\s*(?:code|pin)|auth(?:entication)?\\s*(?:code|pin)|security\\s*(?:code|pin)|login\\s*(?:code|pin)|2fa\\s*code)\\b|" +
        "(?i)(?:\\b(?:otp|passcode|verification\\s*code)\\b.*?(?:\\b[0-9]{4,8}\\b).*?\\b(?:do\\s*not\\s*share|don'?t\\s*share|never\\s*share|valid\\s*for)\\b)|" +
        "(?i)(?:\\b(?:do\\s*not\\s*share|don'?t\\s*share|never\\s*share)\\b.*?(?:\\b[0-9]{4,8}\\b).*?\\b(?:otp|passcode|verification\\s*code)\\b)"
    );

    // Requires explicit transaction indicators with account/card reference or currency symbol
    // Does NOT match promotional copy like "save $20" or "book today"
    private static final java.util.regex.Pattern STRICT_FINANCIAL_PATTERN = java.util.regex.Pattern.compile(
        "(?i)\\b(?:acct?|account|card)\\s*(?:no\\.?|xx+|[x\\*]{2,}|ending\\s*(?:in|with)?)\\s*[0-9]*\\s*(?:debited|credited|charged|withdrawn)\\b|" +
        "(?i)\\b(?:debited|credited|withdrawn|charged)\\s+(?:by|for|with)?\\s*(?:rs\\.?|inr|\\$|€|£|usd)\\s*[0-9]+|" +
        "(?i)\\b(?:paid|transferred)\\s+(?:rs\\.?|inr|\\$|€|£|usd)\\s*[0-9]+(?:\\.[0-9]{1,2})?\\s+(?:to|for|via)\\b|" +
        "(?i)\\b(?:upi\\s*ref|imps\\s*ref|neft\\s*ref|txn\\s*(?:id|ref))\\s*[:\\s#]*[0-9a-zA-Z]{6,}\\b"
    );

    // Requires concrete dispatch or medical emergency context (excludes generic words like "doctor", "hospital", "appointment")
    private static final java.util.regex.Pattern STRICT_CRITICAL_SERVICE_PATTERN = java.util.regex.Pattern.compile(
        "(?i)\\b(?:driver|courier|rider)\\s+(?:is\\s+)?(?:arriving|arrived|approaching|outside)\\b|" +
        "(?i)\\b(?:out\\s+for\\s+delivery|package\\s+(?:has\\s+been\\s+)?delivered|shipment\\s+out\\s+for\\s+delivery)\\b|" +
        "(?i)\\b(?:ambulance\\s+(?:dispatched|en\\s*route|arrived)|emergency\\s+(?:sos|alert|evacuation|warning))\\b|" +
        "(?i)\\b(?:prescription\\s+(?:is\\s+)?ready\\s+for\\s+pickup|critical\\s+lab\\s+result)\\b"
    );

    static boolean isOtp(String text) {
        if (text == null) return false;
        return STRICT_OTP_PATTERN.matcher(text).find();
    }

    static boolean isFinancial(String text) {
        if (text == null) return false;
        return STRICT_FINANCIAL_PATTERN.matcher(text).find();
    }

    static boolean isCriticalService(String text) {
        if (text == null) return false;
        return STRICT_CRITICAL_SERVICE_PATTERN.matcher(text).find();
    }

    /**
     * Core heuristic evaluation with strict precedence:
     * 1. Absolute VIP (-2)
     * 2. User Block/Spam List (2) - User's explicit block takes precedence over generic patterns
     * 3. User Buffer List (1) - User's explicit buffer rules
     * 4. User Urgent List (0) - User's explicit urgent rules
     * 5. High-confidence Mission-Critical Detection (OTP, Financial, Emergency) (0)
     * 6. System Dictionaries
     * 7. Fallback (-1)
     */
    static int evaluateHeuristics(
            String text,
            java.util.List<String> rawAbsoluteVipList,
            java.util.List<String> rawUrgentList,
            java.util.List<String> rawBufferList,
            java.util.List<String> rawSpamList) {

        if (text == null || text.trim().isEmpty()) return -1;
        String rawLowerText = text.toLowerCase();

        // 1. Absolute VIP Check with Word Boundary and Phone Normalization
        if (rawAbsoluteVipList != null) {
            for (String vipContext : rawAbsoluteVipList) {
                if (vipContext.length() >= 2) {
                    if (isPhoneNumber(vipContext)) {
                        if (matchesPhoneInText(text, vipContext)) {
                            return -2; // VIP Strict Bypass
                        }
                    } else if (containsWord(text, vipContext)) {
                        return -2; // VIP Strict Bypass
                    }
                }
            }
        }

        // 2. User Explicit Block/Spam Rules - USER PREFERENCE PRECEDENCE
        // An explicit user block rule (e.g. promo keyword or package) MUST NOT be overridden by generic pattern matches!
        if (rawSpamList != null) {
            for (String spamPhrase : rawSpamList) {
                if (spamPhrase.length() >= 2 && containsWord(text, spamPhrase)) {
                    return 2; // User Block/Spam
                }
            }
        }

        // 3. User Explicit Buffer Rules
        if (rawBufferList != null) {
            for (String bufferPhrase : rawBufferList) {
                if (bufferPhrase.length() >= 2 && containsWord(text, bufferPhrase)) {
                    return 1; // User Buffer
                }
            }
        }

        // 4. User Explicit Urgent Rules
        if (rawUrgentList != null) {
            for (String urgentContext : rawUrgentList) {
                if (urgentContext.length() >= 2) {
                    if (isPhoneNumber(urgentContext)) {
                        if (matchesPhoneInText(text, urgentContext)) {
                            return 0; // User Urgent
                        }
                    } else if (containsWord(text, urgentContext)) {
                        return 0; // User Urgent
                    }
                }
            }
        }

        // 5. System Zero-Drop Protection for verified OTP, Financial transactions & Emergencies
        if (isOtp(text)) {
            return 0; // Urgent OTP
        }
        if (isFinancial(text)) {
            return 0; // Urgent Financial Alert
        }
        if (isCriticalService(text)) {
            return 0; // Urgent Delivery / Emergency Dispatch
        }

        // 6. Tokenization for System Dictionaries
        String strippedText = rawLowerText.replaceAll("[^a-zA-Z0-9 ]", " ");
        String[] notificationWords = strippedText.split("\\s+");

        // Sweep 1: Absolute Priority (URGENT)
        for (String word : notificationWords) {
            if (word.isEmpty()) continue;
            if (com.intent.intent_app.HeuristicDictionary.SYSTEM_URGENT_KEYWORDS.contains(word)) {
                return 0; // Urgent
            }
        }

        // Sweep 2: Deletion Priority (SPAM)
        for (String word : notificationWords) {
            if (word.isEmpty()) continue;
            if (com.intent.intent_app.HeuristicDictionary.SYSTEM_BLOCKED_KEYWORDS.contains(word)) {
                return 2; // Spam
            }
        }

        // Sweep 3: Explicit Buffer Routing
        for (String word : notificationWords) {
            if (word.isEmpty()) continue;
            if (com.intent.intent_app.HeuristicDictionary.SYSTEM_BUFFER_KEYWORDS.contains(word)) {
                return 1; // Buffer
            }
        }

        return -1; // Forward to ML or default safe Buffer
    }

    private int executeHeuristicMatching(String text, SharedPreferences prefs) {
        java.util.ArrayList<String> rawAbsoluteVipList = cachedAbsoluteVip != null ? cachedAbsoluteVip : parseFlutterListSafely(prefs.getAll().get("flutter.absolute_vip_keywords"));
        java.util.ArrayList<String> rawUrgentList = cachedUrgent != null ? cachedUrgent : parseFlutterListSafely(prefs.getAll().get("flutter.urgent_keywords"));
        java.util.ArrayList<String> rawBufferList = cachedBuffer != null ? cachedBuffer : parseFlutterListSafely(prefs.getAll().get("flutter.buffer_keywords"));
        java.util.ArrayList<String> rawSpamList = cachedSpam != null ? cachedSpam : parseFlutterListSafely(prefs.getAll().get("flutter.block_keywords"));

        return evaluateHeuristics(text, rawAbsoluteVipList, rawUrgentList, rawBufferList, rawSpamList);
    }
}

