import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

admin.initializeApp();
const db = admin.firestore();

const AGENT_URL = process.env.AGENT_URL ?? "http://localhost:8080";

interface AgentRunResponse {
  coach_reply: string;
  oz_logged: number;
  next_reminder: string | null;
}

interface VerifyPhotoResponse {
  oz_consumed: number;
  confidence: number;
  container_type?: string;
}

async function callAgent<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${AGENT_URL}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    throw new HttpsError("internal", `Agent error ${res.status}`);
  }
  return (await res.json()) as T;
}

/**
 * checkIn — main entry point from the app's chat screen.
 * Runs the LangGraph agent, persists the AI reply, updates the streak.
 */
export const checkIn = onCall(async (request) => {
  const { user_id, message, photo_url } = request.data as {
    user_id: string;
    message: string;
    photo_url?: string;
  };
  if (!user_id || (!message && !photo_url)) {
    throw new HttpsError("invalid-argument", "user_id and message or photo_url required");
  }

  const userRef = db.collection("users").doc(user_id);
  const userSnap = await userRef.get();
  const user = userSnap.data() ?? {};
  const streakRef = userRef.collection("stats").doc("streak");
  const streakSnap = await streakRef.get();
  const streak = streakSnap.data() ?? { current: 0, best: 0, last_checkin: null };

  const agent = await callAgent<AgentRunResponse>("/run", {
    user_id,
    message: message ?? "",
    photo_url: photo_url ?? null,
    user_context: {
      name: user.name ?? "friend",
      streak: streak.current ?? 0,
      oz_today: user.oz_today ?? 0,
      daily_goal: user.daily_goal ?? 64,
    },
  });

  // Persist the AI reply into the chat thread.
  await userRef.collection("messages").add({
    text: agent.coach_reply,
    sender: "ai",
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Update streak: increment once per new calendar day.
  const today = new Date().toISOString().slice(0, 10);
  let current = streak.current ?? 0;
  if (streak.last_checkin !== today) {
    const yesterday = new Date(Date.now() - 86400000).toISOString().slice(0, 10);
    current = streak.last_checkin === yesterday ? current + 1 : 1;
  }
  await streakRef.set(
    {
      current,
      best: Math.max(current, streak.best ?? 0),
      last_checkin: today,
    },
    { merge: true }
  );

  // Update today's total and the next reminder time.
  await userRef.set(
    {
      oz_today: admin.firestore.FieldValue.increment(agent.oz_logged ?? 0),
      next_reminder: agent.next_reminder
        ? admin.firestore.Timestamp.fromDate(new Date(agent.next_reminder))
        : null,
    },
    { merge: true }
  );

  return {
    coach_reply: agent.coach_reply,
    oz_logged: agent.oz_logged ?? 0,
    streak: current,
  };
});

/**
 * verifyPhoto — standalone photo verification (premium feature).
 */
export const verifyPhoto = onCall(async (request) => {
  const { user_id, photo_url } = request.data as {
    user_id: string;
    photo_url: string;
  };
  if (!user_id || !photo_url) {
    throw new HttpsError("invalid-argument", "user_id and photo_url required");
  }
  return callAgent<VerifyPhotoResponse>("/verify-photo", { user_id, photo_url });
});

/**
 * sendReminder — hourly scheduler that pushes FCM reminders to users
 * whose next_reminder falls within the next 60 minutes.
 */
export const sendReminder = onSchedule("every 1 hours", async () => {
  const now = admin.firestore.Timestamp.now();
  const inOneHour = admin.firestore.Timestamp.fromMillis(now.toMillis() + 3600000);

  const due = await db
    .collection("users")
    .where("next_reminder", ">=", now)
    .where("next_reminder", "<=", inOneHour)
    .get();

  const sends = due.docs.map(async (doc) => {
    const user = doc.data();
    if (!user.fcm_token) return;
    await admin.messaging().send({
      token: user.fcm_token,
      notification: {
        title: "Time to Hydrate! 💧",
        body: `You're at ${user.oz_today ?? 0} oz today. Tap to log your next drink.`,
      },
      data: { screen: "chat", user_id: doc.id },
      android: {
        priority: "high",
        notification: { channelId: "hydrateai_reminders" },
      },
    });
  });
  await Promise.allSettled(sends);
});
