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
            
            
            Log.d(TAG, "Classification Result - Text: [" + text + "], Index: " + maxIndex + ", Prob: " + maxProb);
            
            // Safety Check: If the Neural Engine is not highly confident, 
            // always default to Buffer so the user can see and review it manually.
            if (maxProb < 0.70f) {
                Log.d(TAG, "Neural confidence too low. Failsafe activated. Defaulting to Buffer (1).");
                return 1;
            }
            
            return maxIndex;

        } catch (Exception e) {
            Log.e(TAG, "CRITICAL: Error during notification classification! Forcing BUFFER.", e);
            return 1; // Failsafe to Buffer on crash to prevent data loss
        }
    }

        private java.util.ArrayList<String> parseFlutterListSafely(Object prefObj) {
        java.util.ArrayList<String> list = new java.util.ArrayList<>();
        if (prefObj == null) return list;

        if (prefObj instanceof java.util.Collection) {
            for (Object obj : (java.util.Collection<?>) prefObj) {
                if (obj != null) {
                    list.add(obj.toString().toLowerCase().trim());
                }
            }
            return list;
        }

        String raw = prefObj.toString();
        String prefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu";

        try {
            if (raw.startsWith(prefix)) {
                String jsonStr = raw.substring(prefix.length());
                org.json.JSONArray arr = new org.json.JSONArray(jsonStr);
                for (int i=0; i<arr.length(); i++) {
                    list.add(arr.getString(i).toLowerCase().trim());
                }
            } else if (raw.startsWith("[")) {
                // It might be a toString() of a Collection like [item1, item2]
                String inner = raw.substring(1, raw.length() - 1);
                String[] items = inner.split(",");
                for (String item : items) {
                    String trimmed = item.trim().toLowerCase();
                    if (!trimmed.isEmpty()) {
                        list.add(trimmed);
                    }
                }
            } else {
                // Failsafe fallback parsing
                String[] words = raw.toLowerCase().split("[^a-z0-9@. ]+");
                for(String w : words) list.add(w.trim());
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed parsing Flutter List safely", e);
        }
        return list;
    }

    private boolean isPhoneNumber(String str) {
        if (str == null || str.isEmpty()) return false;
        int digits = 0;
        for (char c : str.toCharArray()) {
            if (Character.isDigit(c)) digits++;
            if (Character.isLetter(c)) return false; // Contains letters, not an isolated phone number
        }
        return digits >= 6;
    }

    private int executeHeuristicMatching(String text, SharedPreferences prefs) {
        // Safe Extraction of Flutter SharedPreferences explicitly parsing JSON arrays
        java.util.ArrayList<String> rawVipList = parseFlutterListSafely(prefs.getAll().get("flutter.vip_keywords"));
        java.util.ArrayList<String> rawBufferList = parseFlutterListSafely(prefs.getAll().get("flutter.buffer_keywords"));
        java.util.ArrayList<String> rawSpamList = parseFlutterListSafely(prefs.getAll().get("flutter.block_keywords"));

        // 0. The Raw Substring Match Matrix (For VIP Contacts, Emails, and normalized Phones)
        String rawLowerText = text.toLowerCase();
        
        for (String vipContext : rawVipList) {
            if (vipContext.length() > 2) {
                // Advanced Normalized Phone Validation
                if (isPhoneNumber(vipContext)) {
                    String numericVip = vipContext.replaceAll("[^0-9+]", "");
                    String numericText = rawLowerText.replaceAll("[^0-9+]", "");
                    if (numericVip.length() >= 6 && numericText.contains(numericVip)) {
                        Log.i(TAG, "Heuristic Matched NUMERIC VIP Context: " + numericVip);
                        return 0; // Urgent
                    }
                }

                // Standard Substring Validation
                if (rawLowerText.contains(vipContext)) {
                    Log.i(TAG, "Heuristic Matched RAW VIP Context (Email/Contact): " + vipContext);
                    return 0; // Urgent
                }
            }
        }
        
        // 0.5. User Overrides (Spam & Buffer) via exact substring phrase matching
        for (String spamPhrase : rawSpamList) {
            if (spamPhrase.length() > 2 && rawLowerText.contains(spamPhrase)) {
                Log.i(TAG, "Heuristic Matched RAW USER SPAM Phrase: " + spamPhrase);
                return 2; // Spam
            }
        }
        
        for (String bufferPhrase : rawBufferList) {
            if (bufferPhrase.length() > 2 && rawLowerText.contains(bufferPhrase)) {
                Log.i(TAG, "Heuristic Matched RAW USER BUFFER Phrase: " + bufferPhrase);
                return 1; // Buffer
            }
        }

        // 1. Rigorous Normalization & Tokenization for remaining tiers
        String strippedText = rawLowerText.replaceAll("[^a-zA-Z0-9 ]", "");
        String[] notificationWords = strippedText.split("\\s+");

        // 3. The Remaining 6-Tier Waterfall Search Matrix
        // Sweep 1: Absolute Priority (URGENT) ensures critical overrides always survive
        for (String word : notificationWords) {
            if (word.isEmpty()) continue;

            // Note: Tier 1 (User VIP Override) already executed implicitly via Raw Substrings!
            
            // Tier 2: System VIP Baseline
            if (com.intent.intent_app.HeuristicDictionary.SYSTEM_URGENT_KEYWORDS.contains(word)) {
                Log.i(TAG, "Heuristic Waterfall [Tier 2] Matched SYSTEM VIP: " + word);
                return 0; // Urgent
            }
        }

        // Sweep 2: Deletion Priority (SPAM)
        for (String word : notificationWords) {
            if (word.isEmpty()) continue;

            // Tier 4: System Spam Baseline
            if (com.intent.intent_app.HeuristicDictionary.SYSTEM_BLOCKED_KEYWORDS.contains(word)) {
                Log.i(TAG, "Heuristic Waterfall [Tier 4] Matched SYSTEM SPAM: " + word);
                return 2; // Spam
            }
        }

        // Sweep 3: Explicit Buffer Routing
        for (String word : notificationWords) {
            if (word.isEmpty()) continue;

            // Tier 6: System Buffer Baseline
            if (com.intent.intent_app.HeuristicDictionary.SYSTEM_BUFFER_KEYWORDS.contains(word)) {
                Log.i(TAG, "Heuristic Waterfall [Tier 6] Matched SYSTEM BUFFER: " + word);
                return 1; // Buffer
            }
        }

        // Tier 7: Fallback Safe Middleground (No specific semantic rules hit)
        Log.d(TAG, "Heuristic Waterfall [Tier 7] Defeated. Forwarding to ML Engine or default Buffer.");
        return -1;
    }
}

