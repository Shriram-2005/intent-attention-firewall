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

    /**
     * Matches word boundary cleanly so 'ram' doesn't match 'program' or 'grammar'.
     */
    private static boolean containsWord(String text, String keyword) {
        if (text == null || keyword == null || keyword.isEmpty()) return false;
        String trimmed = keyword.trim();
        if (trimmed.length() <= 2) return false;
        String regex = "(?i)\\b" + java.util.regex.Pattern.quote(trimmed) + "\\b";
        try {
            return java.util.regex.Pattern.compile(regex).matcher(text).find();
        } catch (Exception e) {
            return text.toLowerCase().contains(trimmed.toLowerCase());
        }
    }

    // High-confidence regex patterns for mission-critical alerts
    private static final java.util.regex.Pattern OTP_PATTERN = java.util.regex.Pattern.compile(
        "(?i)\\b(?:one[- ]?time\\s*(?:pass(?:word)?|code|pin)|otp|verification\\s*code|auth(?:entication)?\\s*code|security\\s*(?:code|alert|pin)|login\\s*code|secret\\s*code|passcode)\\b|" +
        "(?i)\\b(?:is|code|pin|password)[:\\s]+[0-9]{4,8}\\b|" +
        "(?i)\\b[0-9]{4,8}\\s+is\\s+(?:your\\s+)?(?:verification|one[- ]?time|security|login|otp)\\b"
    );

    private static final java.util.regex.Pattern FINANCIAL_PATTERN = java.util.regex.Pattern.compile(
        "(?i)\\b(?:credited|debited|transferred|withdrawn|charged|txn|transaction|card\\s*ending|acct?\\s*ending|account\\s*ending|bank\\s*alert|payment\\s*of|paid\\s*(?:rs\\.?|inr|\\$|€|£))\\b"
    );

    private static final java.util.regex.Pattern CRITICAL_SERVICE_PATTERN = java.util.regex.Pattern.compile(
        "(?i)\\b(?:driver\\s*(?:arriving|arrived)|out\\s*for\\s*delivery|package\\s*delivered|courier|doctor|hospital|clinic|prescription|appointment|ambulance|emergency)\\b"
    );

    private int executeHeuristicMatching(String text, SharedPreferences prefs) {
        java.util.ArrayList<String> rawAbsoluteVipList = cachedAbsoluteVip != null ? cachedAbsoluteVip : parseFlutterListSafely(prefs.getAll().get("flutter.absolute_vip_keywords"));
        java.util.ArrayList<String> rawUrgentList = cachedUrgent != null ? cachedUrgent : parseFlutterListSafely(prefs.getAll().get("flutter.urgent_keywords"));
        java.util.ArrayList<String> rawBufferList = cachedBuffer != null ? cachedBuffer : parseFlutterListSafely(prefs.getAll().get("flutter.buffer_keywords"));
        java.util.ArrayList<String> rawSpamList = cachedSpam != null ? cachedSpam : parseFlutterListSafely(prefs.getAll().get("flutter.block_keywords"));

        String rawLowerText = text.toLowerCase();

        // 0. Absolute VIP Check with Word Boundary and Phone Normalization
        for (String vipContext : rawAbsoluteVipList) {
            if (vipContext.length() > 2) {
                if (isPhoneNumber(vipContext)) {
                    if (matchesPhoneInText(text, vipContext)) {
                        Log.i(TAG, "Heuristic Matched NUMERIC VIP Contact");
                        return -2; // VIP Strict Bypass
                    }
                } else if (containsWord(text, vipContext)) {
                    Log.i(TAG, "Heuristic Matched WORD VIP Contact");
                    return -2; // VIP Strict Bypass
                }
            }
        }

        // 0.1 Strict OTP, Financial & Mission-Critical Delivery/Medical Alert Patterns (Zero-Drop)
        if (OTP_PATTERN.matcher(text).find()) {
            Log.i(TAG, "Heuristic Matched Pattern: High-Priority OTP / Security Code");
            return 0; // Urgent
        }

        if (FINANCIAL_PATTERN.matcher(text).find()) {
            Log.i(TAG, "Heuristic Matched Pattern: Critical Financial Transaction");
            return 0; // Urgent
        }

        if (CRITICAL_SERVICE_PATTERN.matcher(text).find()) {
            Log.i(TAG, "Heuristic Matched Pattern: Delivery / Medical / Emergency Alert");
            return 0; // Urgent
        }

        // 0.25 Urgent Keyword Overrides with Word Boundaries
        for (String urgentContext : rawUrgentList) {
            if (urgentContext.length() > 2) {
                if (isPhoneNumber(urgentContext)) {
                    if (matchesPhoneInText(text, urgentContext)) {
                        Log.i(TAG, "Heuristic Matched NUMERIC URGENT Context");
                        return 0; // Urgent
                    }
                } else if (containsWord(text, urgentContext)) {
                    Log.i(TAG, "Heuristic Matched WORD URGENT Context");
                    return 0; // Urgent
                }
            }
        }

        // 0.5. User Overrides (Spam & Buffer) via Word Boundaries
        for (String spamPhrase : rawSpamList) {
            if (spamPhrase.length() > 2 && containsWord(text, spamPhrase)) {
                Log.i(TAG, "Heuristic Matched USER SPAM Phrase");
                return 2; // Spam
            }
        }

        for (String bufferPhrase : rawBufferList) {
            if (bufferPhrase.length() > 2 && containsWord(text, bufferPhrase)) {
                Log.i(TAG, "Heuristic Matched USER BUFFER Phrase");
                return 1; // Buffer
            }
        }

        // 1. Tokenization for System Dictionaries
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
}

