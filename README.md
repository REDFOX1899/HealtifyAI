# HydrateAI 💧

AI-powered hydration accountability coach for ADHD & fitness users.
Other apps ask if you drank water. **HydrateAI asks for proof.**

## Architecture

```
flutter_app/   Flutter Android app (chat UI, hydration ring, streaks, paywall)
functions/     Firebase Cloud Functions — TypeScript API layer
agent/         LangGraph Python AI agent (Gemini vision + coach + scheduler)
docs/          Business deck, system design, Claude Code prompt playbook
```

**Flow:** App → `checkIn` Cloud Function → LangGraph agent on Cloud Run →
Gemini 2.0 Flash (photo verification + coach reply) → Firestore → app updates
live via streams. An hourly `sendReminder` function pushes adaptive FCM
reminders.

## Quick start (local dev)

### 1. Prerequisites

```bash
# Flutter SDK: https://docs.flutter.dev/get-started/install
npm install -g firebase-tools && firebase login
pip install uv
```

### 2. Firebase project

1. Create a project at https://console.firebase.google.com
2. Enable **Auth** (Email/Password + Google), **Firestore**, **Storage**,
   **Cloud Messaging**.
3. Add an Android app with package `com.hydrateai.hydrateai` and download
   `google-services.json` into `flutter_app/android/app/`.
4. `cp .env.example .env` and fill in your keys
   (Gemini key from https://aistudio.google.com/apikey).

### 3. Run the AI agent locally

```bash
cd agent
uv venv && source .venv/bin/activate
uv pip install -r requirements.txt
export GEMINI_API_KEY=...           # from .env
uvicorn main:api --port 8080 --reload
# Smoke test:
curl -X POST localhost:8080/run -H 'Content-Type: application/json' \
  -d '{"user_id":"u1","message":"just drank 16 oz","user_context":{"name":"Sam","streak":3}}'
```

### 4. Run Functions + emulators

```bash
cd functions && npm install && cd ..
export AGENT_URL=http://localhost:8080
firebase emulators:start
```

### 5. Run the app

```bash
cd flutter_app
flutter create . --org com.hydrateai --project-name hydrateai  # generates android/ platform files (first time only)
flutter pub get
flutter run --dart-define=REVENUECAT_KEY=goog_xxx
```

> `flutter create .` only fills in missing platform scaffolding — it won't
> overwrite `lib/`, `pubspec.yaml`, or the provided `AndroidManifest.xml`
> (say "no" if prompted to overwrite).

## Tests

```bash
# Agent (9 tests — vision parsing, graph routing, scheduler)
cd agent && python -m pytest tests/ -v

# Flutter (chat screen widget tests with fake Firestore)
cd flutter_app && flutter test
```

## Deploy to production

```bash
# 1. Agent → Cloud Run
cd agent
gcloud run deploy hydrateai-agent --source . --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars GEMINI_API_KEY=$GEMINI_API_KEY,FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID

# 2. Point Functions at the agent, then deploy Functions + rules
firebase functions:secrets:set AGENT_URL   # or set as env var in functions config
firebase deploy --only functions,firestore:rules,storage

# 3. Android release build
cd flutter_app && flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

## Monetization (RevenueCat)

Free tier: manual logging, basic reminders, streaks.
Premium ($4.99/mo): AI photo verification, AI coach, smart adaptive
reminders, analytics. Configure a `premium` entitlement with a monthly
package in the RevenueCat dashboard and pass the public SDK key via
`--dart-define=REVENUECAT_KEY=...`.

## Docs

- `docs/HydrateAI_Business_Deck.pptx` — pitch / product overview
- `docs/HydrateAI_System_Design.pdf` — technical reference
- `docs/HydrateAI_ClaudeCode_Prompts.md` — the prompt playbook this repo was built from
