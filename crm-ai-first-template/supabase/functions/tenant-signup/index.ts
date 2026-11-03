// Compatibilidade com clientes antigos: toda a criação é uma RPC transacional.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2.91.0";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, "Content-Type": "application/json" },
});
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const authorization = req.headers.get("Authorization") ?? "";
  if (!/^Bearer [^\s]+$/i.test(authorization)) return json({ error: "Entre com sua conta." }, 401);
  try {
    const client = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: authError } = await client.auth.getUser(authorization.replace(/^Bearer /i, ""));
    if (authError || !user) return json({ error: "Sessão inválida." }, 401);
    const raw = await req.text();
    if (raw.length > 2048) return json({ error: "Dados muito longos." }, 413);
    let body;
    try { body = JSON.parse(raw); } catch { return json({ error: "Dados inválidos." }, 400); }
    if (typeof body?.organization_name !== "string") return json({ error: "Informe o nome da empresa." }, 400);
    const { data, error } = await client.rpc("tenant_onboard", { p_organization_name: body.organization_name });
    if (error) return json({ error: error.code === "42501" ? "Cadastro não autorizado. Confira a liberação e o vínculo da conta." : "Não foi possível preparar a empresa. Tente novamente." }, error.code === "42501" ? 403 : 400);
    return json({ ...data, message: "Empresa preparada. Atualize sua sessão." });
  } catch {
    return json({ error: "Falha temporária ao preparar a empresa." }, 500);
  }
});
