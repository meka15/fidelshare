// Supabase Edge Function: send_push
//
// Expects JSON body:
// {
//   "section": "2",
//   "exclude_user_id": "uuid",
//   "title": "Sender Name",
//   "body": "Message text",
//   "type": "chat",
//   "data": { ... }
// }
//
// Requires env var in Supabase function secrets:
// - SUPABASE_URL
// - SUPABASE_SERVICE_ROLE_KEY
// - FCM_SERVER_KEY  (legacy HTTP API key)
//
// NOTE: Do NOT put FCM_SERVER_KEY in the Flutter app.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type SendPushRequest = {
  section: string;
  exclude_user_id?: string;
  title?: string;
  body?: string;
  type?: string;
  data?: Record<string, unknown>;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const fcmServerKey = Deno.env.get("FCM_SERVER_KEY") ?? "";

  if (!supabaseUrl || !serviceRoleKey) {
    return new Response(JSON.stringify({ error: "Missing Supabase env" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (!fcmServerKey) {
    return new Response(JSON.stringify({ error: "Missing FCM_SERVER_KEY" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  let payload: SendPushRequest;
  try {
    payload = (await req.json()) as SendPushRequest;
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!payload.section) {
    return new Response(JSON.stringify({ error: "Missing section" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: tokensRows, error: tokensError } = await supabase
    .from("device_tokens")
    .select("token, user_id")
    .eq("section", payload.section);

  if (tokensError) {
    return new Response(JSON.stringify({ error: tokensError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const tokens = (tokensRows ?? [])
    .filter((row) => row.token && row.user_id !== payload.exclude_user_id)
    .map((row) => row.token as string);

  const title = payload.title ?? "FidelShare";
  const body = payload.body ?? "";
  const type = payload.type ?? "general";

  const results: Array<{ token: string; ok: boolean; status: number; text?: string }> = [];

  for (const token of tokens) {
    const fcmResponse = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `key=${fcmServerKey}`,
      },
      body: JSON.stringify({
        to: token,
        priority: "high",
        notification: {
          title,
          body,
          android_channel_id: "fidel_alerts_v1",
          sound: "default",
        },
        data: {
          type,
          title,
          body,
          ...(payload.data ?? {}),
        },
        content_available: true,
      }),
    });

    const textBody = await fcmResponse.text();
    results.push({
      token,
      ok: fcmResponse.ok,
      status: fcmResponse.status,
      text: textBody,
    });
  }

  return new Response(JSON.stringify({ sent: tokens.length, results }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
