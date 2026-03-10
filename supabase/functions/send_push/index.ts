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
// Requires env vars in Supabase function secrets:
// - SUPABASE_URL
// - SUPABASE_SERVICE_ROLE_KEY
// - FCM_PROJECT_ID          (Firebase project ID, e.g. "fidelshare")
// - FCM_SERVICE_ACCOUNT_JSON (full JSON service account key, base64 encoded)
//

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type SendPushRequest = {
  section: string;
  exclude_user_id?: string;
  title?: string;
  body?: string;
  type?: string;
  data?: Record<string, unknown>;
};

// --- OAuth2 token generation for FCM v1 ---

interface ServiceAccountKey {
  client_email: string;
  private_key: string;
  token_uri: string;
}

function base64url(data: Uint8Array): string {
  let binary = "";
  for (const byte of data) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemBody = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binaryDer = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
}

async function createSignedJwt(sa: ServiceAccountKey): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    sub: sa.client_email,
    aud: sa.token_uri,
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  const encoder = new TextEncoder();
  const headerB64 = base64url(encoder.encode(JSON.stringify(header)));
  const payloadB64 = base64url(encoder.encode(JSON.stringify(payload)));
  const signingInput = `${headerB64}.${payloadB64}`;

  const key = await importPrivateKey(sa.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(signingInput)
  );

  const signatureB64 = base64url(new Uint8Array(signature));
  return `${signingInput}.${signatureB64}`;
}

async function getAccessToken(sa: ServiceAccountKey): Promise<string> {
  const jwt = await createSignedJwt(sa);
  const response = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Token exchange failed: ${response.status} ${text}`);
  }

  const tokenData = await response.json();
  return tokenData.access_token;
}

// --- Main handler ---

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const fcmProjectId = Deno.env.get("FCM_PROJECT_ID") ?? "";
  const fcmServiceAccountB64 = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "";

  if (!supabaseUrl || !serviceRoleKey) {
    return new Response(JSON.stringify({ error: "Missing Supabase env" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (!fcmProjectId || !fcmServiceAccountB64) {
    return new Response(
      JSON.stringify({
        error: "Missing FCM_PROJECT_ID or FCM_SERVICE_ACCOUNT_JSON env vars",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  // Decode the base64-encoded service account JSON
  let serviceAccount: ServiceAccountKey;
  try {
    const decoded = atob(fcmServiceAccountB64);
    serviceAccount = JSON.parse(decoded) as ServiceAccountKey;
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid FCM_SERVICE_ACCOUNT_JSON (must be base64-encoded JSON)" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
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

  // 1. Get an OAuth2 access token for FCM v1 API
  let accessToken: string;
  try {
    accessToken = await getAccessToken(serviceAccount);
  } catch (e) {
    return new Response(
      JSON.stringify({ error: `OAuth2 token error: ${(e as Error).message}` }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  // 2. Fetch device tokens from Supabase
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

  // Build data payload (FCM v1 requires all data values to be strings)
  const dataPayload: Record<string, string> = { type, title, body };
  if (payload.data) {
    for (const [key, value] of Object.entries(payload.data)) {
      dataPayload[key] = String(value);
    }
  }

  // 3. Send to each token using FCM HTTP v1 API
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${fcmProjectId}/messages:send`;
  const results: Array<{ token: string; ok: boolean; status: number; text?: string }> = [];

  for (const token of tokens) {
    try {
      const fcmResponse = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token,
            notification: {
              title,
              body,
            },
            android: {
              priority: "HIGH",
              notification: {
                channel_id: "fidel_alerts_v1",
                sound: "default",
                default_vibrate_timings: true,
                default_light_settings: true,
              },
            },
            data: dataPayload,
          },
        }),
      });

      const textBody = await fcmResponse.text();
      results.push({
        token,
        ok: fcmResponse.ok,
        status: fcmResponse.status,
        text: textBody,
      });
    } catch (e) {
      results.push({
        token,
        ok: false,
        status: 0,
        text: (e as Error).message,
      });
    }
  }

  return new Response(JSON.stringify({ sent: tokens.length, results }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
