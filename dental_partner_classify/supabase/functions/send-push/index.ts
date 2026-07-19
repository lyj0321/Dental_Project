// 신규 예약/리뷰 등록 시 병원 파트너 앱에 FCM 푸시 알림을 보낸다.
// Supabase Database Webhook(테이블 INSERT)에서 호출되는 것을 전제로 한다.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create as createJwt } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: Record<string, unknown>;
}

function pemToCryptoKey(pem: string): Promise<CryptoKey> {
  const contents = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binary = atob(contents);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);

  return crypto.subtle.importKey(
    "pkcs8",
    bytes.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function getAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const key = await pemToCryptoKey(serviceAccount.private_key);
  const now = Math.floor(Date.now() / 1000);

  const jwt = await createJwt(
    { alg: "RS256", typ: "JWT" },
    {
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    },
    key,
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    throw new Error(`OAuth 토큰 발급 실패: ${await res.text()}`);
  }
  const data = await res.json();
  return data.access_token as string;
}

async function sendFcm(
  projectId: string,
  accessToken: string,
  token: string,
  title: string,
  body: string,
) {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
        },
      }),
    },
  );
  if (!res.ok) {
    console.error("FCM 발송 실패:", await res.text());
  }
}

Deno.serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();

    if (payload.type !== "INSERT") {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    const record = payload.record;
    const ykiho = record.ykiho as string | undefined;
    if (!ykiho) {
      return new Response(JSON.stringify({ skipped: "no ykiho" }), { status: 200 });
    }

    let title: string;
    let body: string;
    let notifyColumn: string;

    if (payload.table === "reservations") {
      notifyColumn = "notify_new_booking";
      title = "신규 예약 신청";
      body = `${record.patient_name ?? "환자"}님이 예약을 신청했습니다.`;
    } else if (payload.table === "reviews") {
      notifyColumn = "notify_review";
      title = "새 리뷰가 등록되었습니다";
      body = `${record.patient_name ?? "환자"}님이 리뷰를 남겼습니다.`;
    } else {
      return new Response(JSON.stringify({ skipped: "unhandled table" }), { status: 200 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: hospital } = await adminClient
      .from("hospitals")
      .select(`fcm_token, ${notifyColumn}`)
      .eq("ykiho", ykiho)
      .maybeSingle();

    if (!hospital || !hospital.fcm_token || hospital[notifyColumn] === false) {
      return new Response(JSON.stringify({ skipped: "no token or notify off" }), { status: 200 });
    }

    const serviceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
    const accessToken = await getAccessToken(serviceAccount);
    await sendFcm(serviceAccount.project_id, accessToken, hospital.fcm_token as string, title, body);

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
