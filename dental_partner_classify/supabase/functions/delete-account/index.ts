// 회원탈퇴: 요청자 본인의 Supabase Auth 계정을 완전히 삭제한다.
// 서비스 롤 키가 필요한 작업이라 클라이언트가 아닌 여기(Edge Function)에서만 수행한다.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "인증 정보가 없습니다." }), { status: 401 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // 요청 헤더의 JWT로 "누가" 요청했는지 검증 (본인 계정만 지울 수 있게)
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "유효하지 않은 사용자입니다." }), { status: 401 });
    }
    const user = userData.user;

    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    // Auth 계정 완전 삭제 (핵심 작업)
    const { error: deleteAuthError } = await adminClient.auth.admin.deleteUser(user.id);
    if (deleteAuthError) {
      return new Response(JSON.stringify({ error: deleteAuthError.message }), { status: 500 });
    }

    // 병원 데이터 정리 (best-effort — 실패해도 계정 삭제는 이미 완료된 상태)
    if (user.email) {
      await adminClient.from("hospitals").delete().eq("email", user.email);
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
