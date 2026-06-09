# HydrateAI — Claude Code Prompts & Dev Workflow
> Use this doc as your engineering playbook. Copy-paste each prompt into Claude Code in order.

---

## 0. Before You Start — One-Time Setup

```bash
# Install Flutter
# https://docs.flutter.dev/get-started/install

# Install Firebase CLI
npm install -g firebase-tools
firebase login

# Install Python 3.11+ and uv (fast package manager)
pip install uv

# Install Claude Code (global)
npm install -g @anthropic-ai/claude-code
```

---

## PROMPT 1 — Initialize Full Monorepo Structure

> Paste this as your first Claude Code message after `cd` into an empty project folder.

```
I'm building an Android app called HydrateAI — an AI-powered hydration accountability 
coach. Set up a monorepo with this exact structure:

hydrateai/
├── flutter_app/        ← Flutter Android app
├── functions/          ← Firebase Cloud Functions (TypeScript)
├── agent/              ← LangGraph Python AI agent
├── docs/               ← Documentation
├── firebase.json
└── .env.example

For each folder, run the appropriate init command:
- flutter_app: `flutter create . --org com.hydrateai --project-name hydrateai`
- functions: `firebase init functions` (TypeScript, ESLint on)
- agent: create a Python package with __init__.py, requirements.txt, and a basic 
  FastAPI app in main.py

Add .env.example with placeholders for: GEMINI_API_KEY, FIREBASE_PROJECT_ID, 
GCS_BUCKET_NAME, REVENUECAT_KEY

Print the final folder tree when done.
```

---

## PROMPT 2 — Flutter Dependencies & Firebase Setup

```
In the flutter_app/ directory, update pubspec.yaml to add these dependencies:
  - firebase_core: latest
  - firebase_auth: latest
  - cloud_firestore: latest
  - firebase_messaging: latest
  - firebase_storage: latest
  - purchases_flutter: latest   (RevenueCat)
  - riverpod: latest
  - flutter_riverpod: latest
  - image_picker: latest
  - http: latest
  - intl: latest

Then create this folder structure under lib/:
  lib/
  ├── main.dart                  ← Firebase init + ProviderScope
  ├── screens/
  │   ├── home_screen.dart       ← Daily progress + streak display
  │   ├── chat_screen.dart       ← iMessage-style AI coach chat
  │   ├── onboarding_screen.dart ← Goal setup + ADHD mode toggle
  │   └── settings_screen.dart
  ├── services/
  │   ├── auth_service.dart      ← Firebase Auth (email + Google)
  │   ├── firestore_service.dart ← Read/write hydration logs + streak
  │   ├── notification_service.dart ← FCM setup + local notifications
  │   └── api_service.dart       ← Calls to Firebase Cloud Functions
  ├── models/
  │   ├── user_model.dart
  │   ├── hydration_log.dart
  │   └── streak_model.dart
  └── widgets/
      ├── hydration_ring.dart    ← Circular progress indicator
      ├── streak_badge.dart
      └── chat_bubble.dart

Create each file with correct imports and empty class stubs. Add TODO comments 
for implementation. Run `flutter pub get` at the end.
```

---

## PROMPT 3 — Build the Chat Screen (Core UI)

```
In lib/screens/chat_screen.dart, build a full iMessage-style chat screen in Flutter:

Requirements:
- User messages: right-aligned, teal background (#00B4D8), white text, rounded corners
- AI messages: left-aligned, dark navy background (#0D1B2A), white text, rounded corners
- Show AI typing indicator (animated dots) while waiting for response
- Bottom input bar:
    - Text input field (hint: "Tell me what you drank...")
    - Camera icon button → opens image_picker, uploads to Firebase Storage, 
      sends photo URL to check-in API
    - Send button
- Use StreamBuilder listening to Firestore collection: 
  users/{uid}/messages ordered by timestamp desc
- Each message document has: {text, sender ('user'|'ai'), timestamp, photo_url?}
- On send: write user message to Firestore, call api_service.checkIn(), 
  write AI response to Firestore when returned
- Show date separators between messages from different days
- Auto-scroll to bottom on new message

Use Riverpod for state (loading, error states). Apply the color palette: 
navy #0D1B2A, teal #00B4D8, offwhite #F0F4F8.
```

---

## PROMPT 4 — Firebase Cloud Functions (API Layer)

```
In functions/src/, create three Firebase Cloud Functions in TypeScript:

1. checkIn (onCall):
   - Accepts: {user_id: string, message: string, photo_url?: string}
   - Calls the Python LangGraph agent via HTTP POST to AGENT_URL/run
   - Writes AI response to Firestore: users/{user_id}/messages/{auto_id}
   - Updates users/{user_id}/stats/streak document
   - Returns: {coach_reply: string, oz_logged: number, streak: number}

2. verifyPhoto (onCall):
   - Accepts: {user_id: string, photo_url: string}
   - Calls AGENT_URL/verify-photo
   - Returns: {oz_consumed: number, confidence: number, container_type: string}

3. sendReminder (onSchedule — runs every hour):
   - Queries Firestore for users whose next_reminder timestamp is within 
     the next 60 minutes
   - Sends FCM push notification to each user's device token
   - Message: "Hey [name], time to hydrate! 💧 Tap to check in."

Add Firebase Admin SDK initialization. Use environment variables for AGENT_URL.
Export all three functions from index.ts.
```

---

## PROMPT 5 — LangGraph Agent (Full Implementation)

```
In agent/, build a complete LangGraph AI agent with these files:

state.py:
  Define AgentState as TypedDict with fields:
  user_id, message, photo_url, intent, oz_logged, ai_confidence,
  coach_reply, next_reminder, streak_delta, user_context (dict)

nodes/intake_node.py:
  Parse user message to classify intent:
  - 'photo' if photo_url is provided
  - 'question' if message contains '?' or question keywords
  - 'checkin' otherwise
  Return updated state with intent field.

nodes/vision_node.py:
  Use google-generativeai (gemini-2.0-flash):
  - Download image from GCS URL
  - Send to Gemini with prompt: "Analyze this hydration container. Return JSON only:
    {container_type, total_oz, pct_remaining, oz_consumed, confidence}"
  - Parse JSON response, fallback to {oz_consumed: 8, confidence: 0.3} on parse error
  - Return oz_logged and ai_confidence

nodes/coach_node.py:
  Use gemini-2.0-flash text generation:
  System prompt: "You are a friendly, encouraging ADHD hydration coach. 
  Be brief (2-3 sentences max). Reference their streak. Never shame. 
  Use their first name. Celebrate wins warmly."
  Include in user prompt: name, current streak, oz logged today, daily goal, 
  oz just logged (if any).
  Return coach_reply.

nodes/scheduler_node.py:
  Rule-based adaptive scheduler:
  - Load user's last 7 check-in timestamps from Firestore
  - Find the 3 most common active hours
  - Schedule next reminder for next occurring active hour
  - If no pattern yet: default to +3 hours from now
  Return next_reminder as ISO timestamp.

graph.py:
  Build StateGraph with conditional routing:
  - intake_node → (if photo) vision_node → coach_node → scheduler_node → END
  - intake_node → (if text/question) coach_node → scheduler_node → END
  Compile and export as `app`.

main.py (FastAPI wrapper):
  POST /run — runs full graph, returns {coach_reply, oz_logged, next_reminder}
  POST /verify-photo — runs only vision_node, returns {oz_consumed, confidence}

Add requirements.txt: langgraph, langchain-core, google-generativeai, 
fastapi, uvicorn, google-cloud-firestore, google-cloud-storage
```

---

## PROMPT 6 — Home Screen with Hydration Ring

```
In lib/screens/home_screen.dart, build the main dashboard:

Layout (dark navy background):
  - Top: greeting "Good morning, [name] 👋" + current date
  - Center: large circular progress ring showing oz consumed / daily goal
    - Ring color: teal (#00B4D8) on dark background
    - Center text: "42 oz" (large) + "of 64 oz" (small, muted)
    - Below ring: "67% of your daily goal"
  - Below ring: streak card
    - "🔥 14-day streak" in gold (#F7C948)
    - "Your best: 21 days"
  - Floating action button: "Check In" → opens ChatScreen
  - Bottom: last 3 activity items (each showing time, oz, source icon)

Read data from Firestore using StreamBuilder on users/{uid} and 
users/{uid}/stats/streak.

Use CustomPainter for the circular progress ring. 
Color palette: navy #0D1B2A, teal #00B4D8, gold #F7C948, offwhite #F0F4F8.
```

---

## PROMPT 7 — Subscription Paywall (RevenueCat)

```
In lib/screens/settings_screen.dart, add a Premium upgrade section using RevenueCat:

1. In main.dart, initialize RevenueCat with the API key from .env
2. Create a PremiumPaywallScreen with:
   - Two cards side by side: FREE vs PREMIUM
   - FREE: manual logging, basic reminders, streak tracking
   - PREMIUM ($4.99/mo): AI photo verification, AI coach, smart reminders, 
     advanced analytics
   - "Upgrade to Premium" button → calls Purchases.purchasePackage()
   - Restore purchases link at bottom
3. In services/auth_service.dart, add a method to check subscription status:
   - Call Purchases.getCustomerInfo()
   - Return true if entitlements contains 'premium'
4. Gate these features behind isPremium check:
   - Camera button in ChatScreen
   - AI coach responses (show upgrade prompt instead)
   - Smart reminder settings
```

---

## PROMPT 8 — Push Notifications Setup

```
Set up Firebase Cloud Messaging for push notifications:

In lib/services/notification_service.dart:
1. Request notification permission on first launch (iOS-style prompt)
2. Get FCM device token and save to Firestore: users/{uid}/fcm_token
3. Handle foreground notifications: show in-app banner
4. Handle background notification tap: navigate to ChatScreen
5. Set up local notification channel for Android:
   - Channel ID: 'hydrateai_reminders'
   - Name: 'Hydration Reminders'
   - Importance: HIGH
   - Sound: default

In android/app/src/main/AndroidManifest.xml:
Add required FCM permissions and the notification service declaration.

In functions/src/index.ts (sendReminder function):
Update to send rich FCM notification with:
- title: "Time to Hydrate! 💧"
- body: "You're at [X] oz today. Tap to log your next drink."
- data: {screen: 'chat', user_id: uid}
- android: {channelId: 'hydrateai_reminders', priority: 'high'}
```

---

## PROMPT 9 — Testing & QA

```
Add tests for the three most critical paths:

1. In agent/tests/test_vision_node.py:
   - Mock Gemini API response
   - Test that a valid photo URL returns correct oz_consumed
   - Test that a malformed Gemini response falls back to default 8 oz

2. In agent/tests/test_graph.py:
   - Test that photo intent routes through vision_node
   - Test that text intent skips vision_node
   - Test that scheduler_node always returns a future timestamp

3. In flutter_app/test/chat_screen_test.dart:
   - Test that sending a message writes to Firestore mock
   - Test that AI response appears in the chat list
   - Test that camera button is hidden for free-tier users

Run: pytest agent/tests/ -v
Run: flutter test
```

---

## PROMPT 10 — Deploy to Production

```
Deploy the full stack:

1. Flutter Android build:
   flutter build apk --release
   # Output: build/app/outputs/flutter-apk/app-release.apk

2. Firebase Cloud Functions deploy:
   cd functions && npm run build
   firebase deploy --only functions

3. Python LangGraph agent — deploy to Google Cloud Run:
   cd agent
   gcloud run deploy hydrateai-agent \
     --source . \
     --region us-central1 \
     --allow-unauthenticated \
     --set-env-vars GEMINI_API_KEY=$GEMINI_API_KEY,FIREBASE_PROJECT_ID=$PROJECT_ID

4. Update AGENT_URL in Firebase Functions config:
   firebase functions:config:set agent.url="https://hydrateai-agent-xxxx.run.app"
   firebase deploy --only functions

5. Firestore security rules:
   Write rules so users can only read/write their own documents.
   Deny all other access.

Print the final deployed URLs when done.
```

---

## Scalable Doc System — How to Reuse for Other Startups

This prompt set is the template. For each new startup:

1. **Copy this file** → rename to `[ProductName]_ClaudeCode_Prompts.md`
2. **Replace PROMPT 1** with your new folder structure
3. **Replace PROMPT 2** with your app's dependencies
4. **Keep PROMPTS 7, 8, 9, 10** — they're generic (paywall, notifications, tests, deploy)
5. **Add product-specific prompts** for your unique features between 3 and 6

The business doc system scales as:
```
docs/
├── [ProductName]_Business_Deck.pptx     ← Pitch / investor / product overview
├── [ProductName]_System_Design.pdf      ← Technical reference (this pattern)
└── [ProductName]_ClaudeCode_Prompts.md  ← Dev workflow (this file)
```

Every startup gets the same three documents. Same format. Instant onboarding.

---

*HydrateAI MVP · v1.0 · Built with Flutter + LangGraph + Gemini + Firebase*
