// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

// Requires env var FCM_SERVER_KEY to be set in Edge Functions
const FCM_KEY = Deno.env.get("FCM_SERVER_KEY");

async function sendToToken(token: string, title: string, body: string) {
  const res = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `key=${FCM_KEY}`,
    },
    body: JSON.stringify({
      to: token,
      notification: { title, body },
      data: { kind: "announcement" },
      priority: "high",
    }),
  });
  if (!res.ok) {
    console.error("FCM error", await res.text());
  }
}

serve(async (req) => {
  if (!FCM_KEY) return new Response("Missing FCM_SERVER_KEY", { status: 500 });
  const { tokens, title, body } = await req.json();
  if (!Array.isArray(tokens)) {
    return new Response("tokens must be array", { status: 400 });
  }
  await Promise.all(tokens.map((t: string) => sendToToken(t, title ?? "BlessedFam", body ?? "")));
  return new Response(JSON.stringify({ sent: tokens.length }), { headers: { "content-type": "application/json" } });
});


