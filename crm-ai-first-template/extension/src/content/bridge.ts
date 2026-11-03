// ============================================================
// Bridge content script (ISOLATED world)
// Roda em isolated world: tem acesso a chrome.runtime mas NÃO a propriedades
// internas do React do Instagram (ex: _valueTracker).
// O instagram.ts roda em MAIN world: vê React mas não tem chrome.runtime.
// Bridge faz ponte via window.postMessage.
// ============================================================

console.log('[IAP-SS] bridge (isolated) loaded on', window.location.href);

// MAIN world → background (debug logs em tempo real)
window.addEventListener('message', (event) => {
  if (event.source !== window) return;
  const data = event.data;
  if (data?.__iapss_log) {
    chrome.runtime.sendMessage({ kind: 'CONTENT_LOG', level: data.level || 'info', message: data.message, context: data.context });
  }
});

// ENRICH_PROFILES: chama API interna do IG no contexto do user logado.
// Funciona porque content script ISOLATED tem cookies do origin instagram.com.
async function enrichProfiles(usernames: string[]): Promise<any[]> {
  const results: any[] = [];
  for (let i = 0; i < usernames.length; i += 5) {
    const batch = usernames.slice(i, i + 5);
    const batchResults = await Promise.all(
      batch.map(async (u) => {
        try {
          const r = await fetch(
            `https://www.instagram.com/api/v1/users/web_profile_info/?username=${encodeURIComponent(u)}`,
            { headers: { 'X-IG-App-ID': '936619743392459' }, credentials: 'include' },
          );
          if (!r.ok) return { username: u, fetch_error: `http_${r.status}` };
          const j = await r.json();
          const usr = j?.data?.user;
          if (!usr) return { username: u, fetch_error: 'no_user' };
          return {
            username: u,
            instagram_user_id: usr.id || usr.pk || null,
            full_name: usr.full_name || null,
            biography: usr.biography || null,
            follower_count: usr.edge_followed_by?.count ?? null,
            following_count: usr.edge_follow?.count ?? null,
            media_count: usr.edge_owner_to_timeline_media?.count ?? null,
            is_verified: !!usr.is_verified,
            is_private: !!usr.is_private,
            is_business_account: !!usr.is_business_account,
            profile_picture_url_hd: usr.profile_pic_url_hd || usr.profile_pic_url || null,
            external_url: usr.external_url || null,
            category: usr.category_name || null,
          };
        } catch (e: any) {
          return { username: u, fetch_error: e?.message || String(e) };
        }
      }),
    );
    results.push(...batchResults);
    // Delay anti-rate-limit entre batches (0.8-1.8s)
    if (i + 5 < usernames.length) {
      await new Promise((r) => setTimeout(r, 800 + Math.random() * 1000));
    }
  }
  return results;
}

// Background → MAIN world (forward)
chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  // Handler novo: ENRICH_PROFILES (não passa pelo MAIN, roda direto no ISOLATED)
  if (msg?.kind === 'ENRICH_PROFILES') {
    enrichProfiles(msg.usernames || []).then((results) => {
      try { sendResponse({ ok: true, results }); } catch {}
    });
    return true; // async
  }

  if (msg?.kind !== 'EXECUTE_ACTION' && msg?.kind !== 'CAPTURE_FOLLOWERS' && msg?.kind !== 'CAPTURE_FOLLOWERS_API' && msg?.kind !== 'CAPTURE_STORY_CONTENT') return;

  const reqId = `iapss_${Math.random().toString(36).slice(2)}`;
  const onReply = (event: MessageEvent) => {
    if (event.source !== window) return;
    const data = event.data;
    if (!data || data.__iapss_reply !== reqId) return;
    window.removeEventListener('message', onReply);
    sendResponse(data.payload);
  };
  window.addEventListener('message', onReply);

  if (msg.kind === 'EXECUTE_ACTION') {
    window.postMessage({ __iapss_request: reqId, kind: 'EXECUTE_ACTION', item: msg.item }, '*');
    setTimeout(() => {
      window.removeEventListener('message', onReply);
      try { sendResponse({ kind: 'ACTION_RESULT', local_id: msg.item?.local_id, success: false, error: 'main_world_timeout' }); } catch {}
    }, 60000);
  } else if (msg.kind === 'CAPTURE_STORY_CONTENT') {
    window.postMessage({
      __iapss_request: reqId,
      kind: 'CAPTURE_STORY_CONTENT',
      username: msg.username,
    }, '*');
    setTimeout(() => {
      window.removeEventListener('message', onReply);
      try { sendResponse({ kind: 'STORY_CONTENT_RESULT', ok: false, error: 'story_capture_timeout' }); } catch {}
    }, 20000);
  } else if (msg.kind === 'CAPTURE_FOLLOWERS_API') {
    window.postMessage({
      __iapss_request: reqId,
      kind: 'CAPTURE_FOLLOWERS_API',
      target_username: msg.target_username,
      limit: msg.limit,
      stop_on_known: msg.stop_on_known || [],
    }, '*');
    setTimeout(() => {
      window.removeEventListener('message', onReply);
      try { sendResponse({ success: false, error: 'api_capture_timeout', usernames: [], followers_data: [] }); } catch {}
    }, 120000); // 2min
  } else if (msg.kind === 'CAPTURE_FOLLOWERS') {
    window.postMessage({
      __iapss_request: reqId,
      kind: 'CAPTURE_FOLLOWERS',
      target_username: msg.target_username,
      limit: msg.limit,
      stop_on_known: msg.stop_on_known || [],
    }, '*');
    // Captura pode demorar — timeout 10min
    setTimeout(() => {
      window.removeEventListener('message', onReply);
      try { sendResponse({ success: false, error: 'capture_timeout', usernames: [], followers_data: [] }); } catch {}
    }, 600000);
  }

  return true; // async
});
