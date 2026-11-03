// ============================================================
// Content script v0.3 — MAIN world (acesso a React internals)
// Comunica com background via bridge.ts (ISOLATED) usando window.postMessage
// ============================================================
import type { QueueItem } from '../shared/types';

console.log('[IAP-SS] content v0.3 (MAIN world) loaded on', window.location.href);

window.addEventListener('message', (event) => {
  if (event.source !== window) return;
  const data = event.data;
  if (!data || !data.__iapss_request) return;

  // EXECUTE_ACTION (cadência)
  if (data.kind === 'EXECUTE_ACTION') {
    const reqId = data.__iapss_request;
    const item: QueueItem = data.item;
    (async () => {
      let payload: any;
      try {
        const result = await executeWithRetry(item);
        payload = { kind: 'ACTION_RESULT', local_id: item.local_id, success: result.success, error: result.error };
      } catch (e: any) {
        payload = { kind: 'ACTION_RESULT', local_id: item.local_id, success: false, error: e.message || String(e) };
      }
      window.postMessage({ __iapss_reply: reqId, payload }, '*');
    })();
    return;
  }

  // CAPTURE_STORY_CONTENT — abre story do user e extrai texto visível (legenda/sticker/mention)
  // Roda ANTES da geração da msg de responder_story pra mandar story_content real pra IA.
  if (data.kind === 'CAPTURE_STORY_CONTENT') {
    const reqId = data.__iapss_request;
    const username: string = data.username || '';
    (async () => {
      try {
        const opened = await abrirStory(username);
        if (!opened.ok) {
          window.postMessage({ __iapss_reply: reqId, payload: { kind: 'STORY_CONTENT_RESULT', ok: false, error: opened.error } }, '*');
          return;
        }
        // Captura texto visível DENTRO da seção do story (sticker, mention, location, caption sobreposta).
        // Filtra agressivamente UI do IG — só sobra o que o user postou.
        const ignoreExact = new Set([
          'Curtir', 'Like', 'Não curti', 'Liked', 'Descurtir',
          'Responder a', 'Reply to', 'Send a message', 'Mande uma mensagem', 'Direct',
          'Compartilhar', 'Share', 'Enviar', 'Send',
          'Ver perfil', 'View profile', 'Mais opções', 'More options', 'Menu',
          'Pausar', 'Pause', 'Próximo', 'Next', 'Anterior', 'Previous',
          'Avançar', 'Voltar', 'Forward', 'Back',
          'Reações rápidas', 'Quick reactions',
          'Verificado', 'Verified',
          'Ver tradução', 'See translation',
          'Story', 'Stories', 'Reels', 'Reel',
          'Alternar áudio', 'Toggle audio',
          'O áudio está silenciado', 'Audio is muted',
          'Fechar', 'Close',
          'Assistir ao reel completo', 'Watch full reel',
          'Seta para a direita', 'Seta para a esquerda',
          'Instagram',
        ]);
        const ignoreRe = [
          /^\d+\s*(h|m|s|d|sem|min|hora|hour|day|week|month)$/i,  // "13 h", "2 min", "5 d"
          /^há\s+\d+/i,                                              // "há 13 horas"
          /^\d+\s*(de\s+)?(jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)/i,
          /^@?[a-z0-9_.]{1,30}$/i,                                  // @user ou só username isolado
          /^\s*[•·\-_]\s*$/,                                         // separadores
        ];
        const isUIEmoji = (s: string): boolean => {
          // Strings que são SÓ emojis (1-3 chars de emoji) — IG quick reactions
          const noEmoji = s.replace(/[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{2300}-\u{23FF}\u{2B00}-\u{2BFF}\u{1F300}-\u{1F9FF}\u{1F100}-\u{1F1FF}\u{1F900}-\u{1F9FF}]/gu, '').trim();
          return noEmoji.length === 0 && s.length > 0;
        };
        const isIgnored = (t: string): boolean => {
          if (ignoreExact.has(t)) return true;
          if (t.toLowerCase() === username.toLowerCase()) return true;
          if (isUIEmoji(t)) return true;
          return ignoreRe.some((re) => re.test(t));
        };

        const stop = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEXTAREA', 'INPUT', 'BUTTON', 'SVG']);
        const root = document.querySelector('section') || document.body;
        const collected: string[] = [];
        const walk = (el: Element) => {
          if (stop.has(el.tagName)) return;
          for (const child of Array.from(el.childNodes)) {
            if (child.nodeType === Node.TEXT_NODE) {
              const t = (child.textContent || '').replace(/\s+/g, ' ').trim();
              if (t.length >= 3 && !isIgnored(t)) collected.push(t);
            } else if (child.nodeType === Node.ELEMENT_NODE) {
              walk(child as Element);
            }
          }
        };
        walk(root as Element);
        // Dedup mantendo ordem
        const seen = new Set<string>();
        const unique = collected.filter((t) => { if (seen.has(t)) return false; seen.add(t); return true; });
        const story_content = unique.slice(0, 15).join(' · ').slice(0, 500);
        window.postMessage({ __iapss_reply: reqId, payload: { kind: 'STORY_CONTENT_RESULT', ok: true, story_content } }, '*');
      } catch (e: any) {
        window.postMessage({ __iapss_reply: reqId, payload: { kind: 'STORY_CONTENT_RESULT', ok: false, error: e.message || String(e) } }, '*');
      }
    })();
    return;
  }

  // CAPTURE_FOLLOWERS_API — usa API privada do IG (com cookies do user logado)
  // Ordem garantida (mais recentes primeiro), dados ricos já vêm no payload
  // (is_private, is_verified, full_name, pk), sem scroll, sem virtualização.
  if (data.kind === 'CAPTURE_FOLLOWERS_API') {
    const reqId = data.__iapss_request;
    const targetUsername: string = (data.target_username || '').toLowerCase().replace(/^@/, '').trim();
    const limit: number = data.limit || 500;
    const stopOnKnown: string[] = (data.stop_on_known || []).map((u: string) => u.toLowerCase());
    (async () => {
      const result = await captureFollowersAPI(targetUsername, limit, stopOnKnown);
      window.postMessage({ __iapss_reply: reqId, payload: result }, '*');
    })();
    return;
  }

  // CAPTURE_FOLLOWERS — fallback: scroll do modal (perde itens por virtualização do IG)
  // Mantido pra caso a API privada bloqueie / rate-limit.
  if (data.kind === 'CAPTURE_FOLLOWERS') {
    const reqId = data.__iapss_request;
    const targetUsername: string = data.target_username || '';
    const limit: number = data.limit || 500;
    const stopOnKnown: string[] = data.stop_on_known || [];
    (async () => {
      const result = await captureFollowers(targetUsername, limit, stopOnKnown);
      window.postMessage({ __iapss_reply: reqId, payload: result }, '*');
    })();
    return;
  }
});

/**
 * Captura seguidores via API privada do IG (mesma usada pelo web app por baixo).
 * Vantagens vs scroll do modal:
 *   - Ordem cronológica garantida (mais recentes primeiro)
 *   - Sem virtualização → não perde itens
 *   - Vem com is_private, is_verified, full_name, pk → menos enriches depois
 *   - ~10x mais rápido
 * Paginação via max_id retornado em cada chunk de até 100.
 */
async function captureFollowersAPI(
  targetUsername: string,
  limit: number,
  stopOnKnown: string[],
): Promise<{ success: boolean; usernames: string[]; followers_data: any[]; reason?: string; iterations?: number }> {
  dbg(`captureFollowersAPI: iniciando @${targetUsername} limit=${limit} (${stopOnKnown.length} já conhecidos)`, 'step');

  // 1) Pega user_id do target via web_profile_info
  let userId: string | null = null;
  try {
    const r = await fetch(
      `https://www.instagram.com/api/v1/users/web_profile_info/?username=${encodeURIComponent(targetUsername)}`,
      { headers: { 'X-IG-App-ID': '936619743392459' }, credentials: 'include' },
    );
    if (!r.ok) {
      dbg(`captureFollowersAPI: web_profile_info http ${r.status}`, 'error');
      return { success: false, usernames: [], followers_data: [], reason: `web_profile_info_${r.status}` };
    }
    const j = await r.json();
    userId = j?.data?.user?.id || j?.data?.user?.pk || null;
  } catch (e: any) {
    return { success: false, usernames: [], followers_data: [], reason: `web_profile_info_err: ${e.message}` };
  }
  if (!userId) {
    return { success: false, usernames: [], followers_data: [], reason: 'no_user_id' };
  }
  dbg(`captureFollowersAPI: user_id=${userId}, iniciando paginação`, 'success');

  const knownSet = new Set(stopOnKnown.map((u) => u.toLowerCase()));
  const collected: any[] = [];
  let maxId: string | null = null;
  let reason = 'completed';
  let page = 0;

  for (page = 0; page < 50; page++) {  // hard limit: 50 pages × 100 = 5000 (mais que suficiente)
    const url = new URL(`https://www.instagram.com/api/v1/friendships/${userId}/followers/`);
    url.searchParams.set('count', String(Math.min(100, limit - collected.length)));
    if (maxId) url.searchParams.set('max_id', maxId);

    let r: Response;
    try {
      r = await fetch(url.toString(), {
        headers: { 'X-IG-App-ID': '936619743392459' },
        credentials: 'include',
      });
    } catch (e: any) {
      dbg(`captureFollowersAPI: fetch erro page ${page}: ${e.message}`, 'error');
      reason = `fetch_err: ${e.message}`;
      break;
    }
    if (!r.ok) {
      dbg(`captureFollowersAPI: http ${r.status} na page ${page}`, 'error');
      reason = `http_${r.status}`;
      break;
    }
    const j = await r.json();
    const users = j?.users || [];
    if (users.length === 0) { reason = 'end_of_list'; break; }

    let hitKnown = false;
    for (const u of users) {
      const username = String(u.username || '').toLowerCase();
      if (!username || username === targetUsername.toLowerCase()) continue;

      // Hit known → para AQUI (mais antigos vêm depois, todos já processados)
      if (knownSet.has(username)) {
        dbg(`captureFollowersAPI: hit_known em @${username} (page ${page}, posição ${collected.length}) — parando`, 'info');
        reason = 'hit_known';
        hitKnown = true;
        break;
      }

      collected.push({
        username,
        full_name: u.full_name || '',
        instagram_user_id: String(u.pk || u.id || ''),
        is_private: !!u.is_private,
        is_verified: !!u.is_verified,
        profile_picture_url_hd: u.profile_pic_url || null,
      });

      if (collected.length >= limit) { reason = 'limit_reached'; break; }
    }

    if (hitKnown) break;
    if (collected.length >= limit) break;

    maxId = j?.next_max_id || null;
    if (!maxId) { reason = 'end_of_list'; break; }

    // Delay anti-rate-limit (humanizar — 800-1500ms entre chunks)
    await sleep(800 + Math.random() * 700);
  }

  dbg(`captureFollowersAPI: terminou (${reason}) — ${collected.length} coletados em ${page + 1} pages`, 'success');
  return {
    success: true,
    usernames: collected.map((u) => u.username),
    followers_data: collected,
    reason,
    iterations: page + 1,
  };
}

/** Scroll modal de seguidores + coleta usernames até atingir limit OU bater em known */
async function captureFollowers(
  targetUsername: string,
  limit: number,
  stopOnKnown: string[],
): Promise<{ success: boolean; usernames: string[]; followers_data: any[]; reason?: string; iterations?: number }> {
  dbg(`captureFollowers: iniciando @${targetUsername} limit=${limit}`, 'step');

  // 1) Espera IG hidratar (poll até achar o link de seguidores)
  const target = targetUsername.toLowerCase();
  if (!window.location.pathname.toLowerCase().includes(`/${target}`)) {
    dbg(`captureFollowers: URL atual ${window.location.pathname} não bate com ${target}`, 'error');
    return { success: false, usernames: [], followers_data: [], reason: 'wrong_url' };
  }

  // Helper unificado: detecta se um dialog é o de SEGUIDORES via múltiplos sinais
  // (IG muda o DOM frequentemente — heading pode estar em h1/h2/h3, span, aria-label, ou só na URL)
  const isFollowersDialog = (d: HTMLElement): { match: boolean; label: string } => {
    // 1. Heading explícito (h1/h2/h3/role=heading)
    const heading = d.querySelector('h1,h2,h3,[role="heading"]')?.textContent?.trim() || '';
    if (/seguidor|followers/i.test(heading)) return { match: true, label: heading };
    // 2. aria-label do próprio dialog
    const ariaLabel = d.getAttribute('aria-label') || '';
    if (/seguidor|followers/i.test(ariaLabel)) return { match: true, label: `[aria]${ariaLabel}` };
    // 3. Aria-labelledby (ID referenciando elemento com o título)
    const labelledBy = d.getAttribute('aria-labelledby');
    if (labelledBy) {
      const labelEl = document.getElementById(labelledBy);
      const labelTxt = labelEl?.textContent?.trim() || '';
      if (/seguidor|followers/i.test(labelTxt)) return { match: true, label: `[labelledby]${labelTxt}` };
    }
    // 4. URL atual já é /user/followers/ E é o maior dialog visível
    const urlIsFollowers = /\/followers\/?$/i.test(window.location.pathname);
    if (urlIsFollowers) {
      // Verifica se o dialog tem links de usuário (a[href^="/"] que NÃO seja o próprio target)
      const userLinks = d.querySelectorAll('a[href^="/"]');
      if (userLinks.length >= 3) return { match: true, label: '[url-followers+userlinks]' };
    }
    // 5. Texto geral do dialog (primeiros 300 chars) menciona seguidores
    const topText = (d.textContent || '').slice(0, 300);
    if (/seguidores|followers/i.test(topText) && d.querySelectorAll('a[href^="/"]').length >= 3) {
      return { match: true, label: '[text-scan]' };
    }
    return { match: false, label: heading || ariaLabel || '(sem heading)' };
  };

  // 2) Fecha dialogs "lixo" (notas/stories/criar) antes de começar
  const closeJunkDialogs = () => {
    const dialogs = Array.from(document.querySelectorAll<HTMLElement>('[role="dialog"]'));
    for (const d of dialogs) {
      const check = isFollowersDialog(d);
      if (!check.match) {
        const closeBtn = d.querySelector<HTMLElement>('[aria-label="Fechar"], [aria-label="Close"], svg[aria-label="Fechar"], svg[aria-label="Close"]');
        if (closeBtn) {
          dbg(`captureFollowers: fechando dialog "${check.label.slice(0, 30)}"`, 'info');
          (closeBtn.closest('button, [role="button"]') as HTMLElement || closeBtn).click();
        }
      }
    }
  };
  closeJunkDialogs();
  await sleep(800);

  // 3) Tenta achar o dialog OU o link. Se nada, navega direto pra /user/followers/
  const expectedPath = `/${target}/followers/`;
  const isDialogAberto = () => Array.from(document.querySelectorAll<HTMLElement>('[role="dialog"]')).find((d) => isFollowersDialog(d).match) || null;

  const findFollowersLink = (): HTMLElement | null => {
    // Estratégia 1 (legado): <a href="/user/followers/"> — IG antigo
    const legacyAnchor = Array.from(document.querySelectorAll<HTMLAnchorElement>('a[href*="/followers"], a[href*="/seguidores"]')).find((a) => {
      try {
        const path = new URL(a.href).pathname.toLowerCase().replace(/\/+$/, '');
        return path.includes(`/${target}/`) && (path.endsWith('/followers') || path.endsWith('/seguidores'));
      } catch { return false; }
    });
    if (legacyAnchor) return legacyAnchor;

    // Estratégia 2 (IG atual ~2026): <a role="link" href="#"> envolvendo <span>X seguidores</span>
    // O IG removeu o href real — agora abre modal via JS interno. Subimos do span até o ancestor clicável.
    const span = Array.from(document.querySelectorAll<HTMLSpanElement>('span')).find((s) => {
      const txt = s.textContent || '';
      if (txt.length > 50) return false;
      return /\d[\d\s.,kmilhões]*\s*(seguidor|follower)/i.test(txt);
    });
    if (span) {
      const clickable = span.closest('a, [role="link"], [role="button"], button') as HTMLElement | null;
      if (clickable) return clickable;
    }
    return null;
  };

  let followLink: HTMLElement | null = null;
  for (let i = 0; i < 10; i++) {
    closeJunkDialogs();
    if (isDialogAberto()) { dbg('captureFollowers: dialog já aberto', 'info'); break; }
    followLink = findFollowersLink();
    if (followLink) break;
    await sleep(500);
  }

  let dialog: HTMLElement | null = isDialogAberto();

  // 4) Se ainda não tem dialog: tenta clicar no link. Se não tem link, NAVEGA DIRETO.
  if (!dialog) {
    if (followLink) {
      const linkInfo = (followLink as HTMLAnchorElement).href || `${followLink.tagName}[role=${followLink.getAttribute('role') || ''}]`;
      dbg(`captureFollowers: clicando link ${linkInfo}`, 'step');
      naturalClick(followLink);
    } else {
      // Fallback: força navegação pra /user/followers/ — IG abre o modal sozinho nessa rota
      const allLinks = Array.from(document.querySelectorAll<HTMLAnchorElement>('a[href*="follow"]')).slice(0, 5).map((a) => a.href);
      dbg(`captureFollowers: link DOM não achado, forçando URL ${expectedPath}. (anchors com 'follow' na página: [${allLinks.join(', ')}])`, 'info');
      history.pushState({}, '', expectedPath);
      window.dispatchEvent(new PopStateEvent('popstate'));
      // Se SPA não reagir, força hard navigate
      await sleep(800);
      if (!isDialogAberto() && window.location.pathname.toLowerCase() !== expectedPath) {
        dbg(`captureFollowers: SPA não abriu modal, hard navigate`, 'info');
        window.location.href = expectedPath;
        await sleep(2000); // dá tempo do IG carregar
      }
    }
  }

  // 5) Espera dialog DE SEGUIDORES aparecer (detecção multi-sinal)
  for (let i = 0; i < 30; i++) {
    dialog = Array.from(document.querySelectorAll<HTMLElement>('[role="dialog"]')).find((d) => isFollowersDialog(d).match) || null;
    if (dialog) break;
    await sleep(500);
  }
  if (!dialog) {
    const dialogs = Array.from(document.querySelectorAll<HTMLElement>('[role="dialog"]'));
    const debugInfo = dialogs.map((d) => {
      const check = isFollowersDialog(d);
      const ariaLabel = d.getAttribute('aria-label') || '';
      const heading = d.querySelector('h1,h2,h3,[role="heading"]')?.textContent?.trim() || '';
      const userLinks = d.querySelectorAll('a[href^="/"]').length;
      return `match=${check.match} aria="${ariaLabel.slice(0, 30)}" h="${heading.slice(0, 30)}" links=${userLinks}`;
    });
    dbg(`captureFollowers: dialog correto não achado. URL=${window.location.pathname}. Dialogs (${dialogs.length}): [${debugInfo.join(' | ')}]`, 'error');
    return { success: false, usernames: [], followers_data: [], reason: 'dialog_not_opened' };
  }
  const dialogCheck = isFollowersDialog(dialog);
  dbg(`captureFollowers: dialog SEGUIDORES aberto via ${dialogCheck.label.slice(0, 40)}`, 'success');

  // 5) Espera lista popular — encontra scrollable A PARTIR de um user link real
  //    (estratégia: pega primeiro <a> com img, sobe na hierarquia até achar overflow scroll)
  const findScrollableFromUserLink = (): HTMLElement | null => {
    // Acha um link de usuário (a[href^="/"] com img dentro, NÃO sendo o próprio target)
    const userLinks = Array.from(dialog!.querySelectorAll<HTMLAnchorElement>('a[href^="/"]')).filter((a) => {
      try {
        const path = new URL(a.href).pathname;
        if (!/^\/[a-zA-Z0-9_.]+\/?$/.test(path)) return false;
        if (path.toLowerCase().replace(/\//g, '') === target) return false;
        return !!a.querySelector('img');
      } catch { return false; }
    });
    if (userLinks.length === 0) return null;
    // Sobe na hierarquia até achar elemento scrollable
    let el: HTMLElement | null = userLinks[0];
    while (el && el !== dialog) {
      const s = getComputedStyle(el);
      if ((s.overflowY === 'auto' || s.overflowY === 'scroll') && el.scrollHeight > el.clientHeight + 50) {
        return el;
      }
      el = el.parentElement;
    }
    // Fallback: maior scrollable do dialog (em scrollHeight)
    const allScrollables = Array.from(dialog!.querySelectorAll<HTMLElement>('*')).filter((el) => {
      const s = getComputedStyle(el);
      return (s.overflowY === 'auto' || s.overflowY === 'scroll') && el.scrollHeight > el.clientHeight + 50;
    });
    allScrollables.sort((a, b) => b.scrollHeight - a.scrollHeight);
    return allScrollables[0] || null;
  };

  let scrollable: HTMLElement | null = null;
  let initialUsers = 0;
  for (let i = 0; i < 30; i++) {
    scrollable = findScrollableFromUserLink();
    if (scrollable) {
      initialUsers = Array.from(dialog.querySelectorAll<HTMLAnchorElement>('a[href^="/"]')).filter((a) => {
        try { return /^\/[a-zA-Z0-9_.]+\/?$/.test(new URL(a.href).pathname) && !!a.querySelector('img'); }
        catch { return false; }
      }).length;
      if (initialUsers > 2) break; // tem usuários carregados
    }
    await sleep(500);
  }
  if (!scrollable) {
    const allScrollableInfo = Array.from(dialog.querySelectorAll<HTMLElement>('*')).filter((el) => {
      const s = getComputedStyle(el);
      return (s.overflowY === 'auto' || s.overflowY === 'scroll');
    }).map((el) => `${el.tagName}(${el.scrollHeight}/${el.clientHeight})`);
    dbg(`captureFollowers: scrollable não achado. ${initialUsers} user-links no dialog. Scrollables: [${allScrollableInfo.slice(0, 5).join(', ')}]`, 'error');
    return { success: false, usernames: [], followers_data: [], reason: 'no_scrollable' };
  }
  dbg(`captureFollowers: scrollable achado (${scrollable.scrollHeight}px, ${initialUsers} users iniciais)`, 'success');

  const knownSet = new Set(stopOnKnown.map((u) => u.toLowerCase()));
  const collected = new Map<string, any>();
  let lastSize = 0;
  let stable = 0;
  let iterations = 0;
  let reason = 'completed';
  const targetLc = targetUsername.toLowerCase();

  for (iterations = 0; iterations < 500; iterations++) {
    // Coleta atual (IG virtualiza — vai removendo do DOM, então coletamos antes de cada scroll)
    const userLinks = Array.from(dialog.querySelectorAll<HTMLAnchorElement>('a[href^="/"]'));
    for (const a of userLinks) {
      try {
        const path = new URL(a.href).pathname;
        if (!/^\/[a-zA-Z0-9_.]+\/?$/.test(path)) continue;
        const username = path.replace(/\//g, '').toLowerCase();
        if (!username || username === targetLc) continue;
        if (collected.has(username)) continue;
        if (!a.querySelector('img')) continue;
        // Se já tá em known_followers (qualificado antes), PARA aqui — não coleta nem enriquece de novo.
        // IG ordena mais recentes primeiro, então hit_known = "alcancei onde eu parei na última captura".
        if (knownSet.has(username)) {
          reason = 'hit_known';
          break;
        }
        const spans = a.querySelectorAll('span');
        const fullName = spans[1]?.textContent?.trim() || '';
        collected.set(username, { username, full_name: fullName });
      } catch {}
    }

    if (collected.size >= limit) { reason = 'limit_reached'; break; }
    // Hit_known SEMPRE para (mesmo size=0 = todos já conhecidos do topo, sem novos seguidores)
    if (reason === 'hit_known') break;

    // Scroll INCREMENTAL (90% da viewport) — não pula pro fim (perde itens virtualizados)
    // + dispatch de eventos pra simular scroll humano (IG só fetch network com scroll real)
    const prevTop = scrollable.scrollTop;
    scrollable.scrollTop = prevTop + scrollable.clientHeight * 0.9;
    scrollable.dispatchEvent(new Event('scroll', { bubbles: true }));
    await sleep(1200);

    // Detecta fim: se chegamos no bottom E 3 iterações sem novos itens coletados
    const sizeNow = collected.size;
    const reachedBottom = scrollable.scrollTop + scrollable.clientHeight >= scrollable.scrollHeight - 10;
    if (sizeNow === lastSize) {
      stable++;
      if (stable >= 3 && reachedBottom) { reason = 'end_of_list'; break; }
      if (stable >= 6) { reason = 'no_progress'; break; }
    } else {
      stable = 0;
      lastSize = sizeNow;
    }
  }
  dbg(`captureFollowers: terminou (${reason}) — ${collected.size} coletados em ${iterations} iterações`, 'success');

  const arr = Array.from(collected.values()).slice(0, limit);
  return {
    success: true,
    usernames: arr.map((u) => u.username),
    followers_data: arr,
    reason,
    iterations,
  };
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// Manda debug log pro painel da extensão
function dbg(message: string, level: 'info' | 'success' | 'error' | 'step' = 'info', context?: any) {
  try {
    window.postMessage({ __iapss_log: true, level, message: `🔍 ${message}`, context }, '*');
  } catch {}
}

async function waitForVisible<T extends Element>(
  selectors: string[],
  timeoutMs = 12000,
  intervalMs = 250,
): Promise<T> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    for (const sel of selectors) {
      const els = Array.from(document.querySelectorAll<T>(sel));
      const visible = els.find((el) => (el as any).offsetParent !== null);
      if (visible) return visible;
    }
    await sleep(intervalMs);
  }
  throw new Error(`element_not_found:${selectors.join('|').slice(0, 80)}`);
}

function isBlocked(): string | null {
  const text = document.body.innerText.toLowerCase();
  const indicators: [string, string][] = [
    ['suspicious activity', 'suspicious_activity'],
    ['we detected', 'challenge_detected'],
    ['verifique sua identidade', 'identity_check'],
    ['temporarily blocked', 'temporary_block'],
    ['checkpoint required', 'checkpoint'],
    ['please wait a few minutes', 'rate_limit'],
    ['try again later', 'rate_limit'],
  ];
  for (const [needle, code] of indicators) {
    if (text.includes(needle)) return code;
  }
  if (window.location.href.includes('/challenge/')) return 'url_challenge';
  if (window.location.href.includes('/accounts/suspended/')) return 'suspended';
  return null;
}

function naturalClick(el: HTMLElement) {
  el.scrollIntoView({ block: 'center', behavior: 'instant' as any });
  const rect = el.getBoundingClientRect();
  const x = rect.left + rect.width / 2;
  const y = rect.top + rect.height / 2;
  for (const type of ['mouseover', 'mousedown', 'mouseup', 'click']) {
    el.dispatchEvent(
      new MouseEvent(type, { view: window, bubbles: true, cancelable: true, clientX: x, clientY: y, button: 0 }),
    );
  }
}

function findClickable(el: Element | null): HTMLElement | null {
  if (!el) return null;
  return (el.closest('[role="button"], button, a') as HTMLElement | null) || (el as HTMLElement);
}

/**
 * typeText — React-aware. Roda em MAIN world (acessa _valueTracker).
 * Para <textarea>/<input>: 1 set único (validado funciona com IG). Char-by-char quebra.
 * Para contenteditable: execCommand insertText.
 */
async function typeText(el: HTMLElement, text: string) {
  el.focus();
  await sleep(200);
  // Estratégia 1: execCommand insertText — funciona em TEXTAREA + contenteditable
  // Dispara beforeinput + input + change na ordem que o React espera.
  let strategy = 'execCommand';
  let valueAfter = '';
  try {
    if (el instanceof HTMLTextAreaElement || el instanceof HTMLInputElement) {
      // Limpa primeiro selecionando tudo + deletando
      el.select?.();
      document.execCommand('delete', false);
      const ok = document.execCommand('insertText', false, text);
      valueAfter = el.value;
      if (!ok || !valueAfter) {
        // Fallback: _valueTracker + setter
        strategy = 'tracker_setter';
        const tracker = (el as any)._valueTracker;
        if (tracker) tracker.setValue('');
        const proto = el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
        const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
        setter?.call(el, text);
        el.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text }));
        valueAfter = el.value;
      }
    } else {
      // contenteditable
      document.execCommand('selectAll', false);
      document.execCommand('delete', false);
      document.execCommand('insertText', false, text);
      valueAfter = (el.innerText || '').trim();
    }
  } catch (e: any) {
    dbg(`typeText: erro ${e.message}`, 'error');
  }
  await sleep(400);
  dbg(`typeText: strategy=${strategy} value="${valueAfter.slice(0, 60)}"`);
  // Re-foca pra forçar React a reagir (botão Postar pode esconder se perdeu foco)
  el.focus();
  await sleep(200);
}

// ------------------------------------------------------------
// Dispatcher com retry (1 retry em caso de timeout)
// ------------------------------------------------------------
async function executeWithRetry(item: QueueItem): Promise<{ success: boolean; error?: string }> {
  const r1 = await execute(item);
  if (r1.success) return r1;
  // Retry só se for timeout/element not found
  if (r1.error && /element_not_found|Timeout/i.test(r1.error)) {
    console.log('[IAP-SS] Retry após falha:', r1.error);
    await sleep(3000);
    return await execute(item);
  }
  return r1;
}

async function execute(item: QueueItem): Promise<{ success: boolean; error?: string }> {
  await sleep(1500);
  const blocked = isBlocked();
  if (blocked) return { success: false, error: `blocked:${blocked}` };

  switch (item.action_type) {
    case 'curtir_posts':
      return curtir();
    case 'comentar_post':
      return comentar(item.edited_message || item.generated_message || '');
    case 'reagir_story':
      return reagirStory(item.instagram_username);
    case 'responder_story':
      return responderStory(item.instagram_username, item.edited_message || item.generated_message || '');
    case 'enviar_dm':
      return enviarDM(item.instagram_username, item.edited_message || item.generated_message || '');
    case 'followup_story':
      return reagirStory(item.instagram_username);
    case 'verificar_resposta':
      return verificarResposta();
    default:
      return { success: false, error: `unknown_action:${item.action_type}` };
  }
}

// ------------------------------------------------------------
// CURTIR — pega o botão grande (do POST, não do comentário)
// Post like = svg 24x24, comment like = svg 12x12. Filtra por tamanho ≥ 20.
// ------------------------------------------------------------
function findPostLikeSvg(): SVGElement | null {
  // Já curtiu o POST? (filtro por tamanho)
  const allUnlike = Array.from(document.querySelectorAll<SVGElement>(
    'svg[aria-label="Descurtir"], svg[aria-label="Unlike"], svg[aria-label="Não curti"], svg[aria-label="Liked"]'
  ));
  const postUnlike = allUnlike.find((s) => s.getBoundingClientRect().width >= 20);
  if (postUnlike) return postUnlike; // marker pra "já curtiu"

  // Acha botão grande de curtir
  const allLike = Array.from(document.querySelectorAll<SVGElement>(
    'svg[aria-label="Curtir"], svg[aria-label="Like"]'
  ));
  const postLike = allLike.find((s) => {
    const r = s.getBoundingClientRect();
    return r.width >= 20 && r.height >= 20;
  });
  return postLike || null;
}

async function curtir(): Promise<{ success: boolean; error?: string }> {
  // Espera carregar
  let postLike: SVGElement | null = null;
  for (let i = 0; i < 20; i++) {
    postLike = findPostLikeSvg();
    if (postLike) break;
    await sleep(500);
  }
  if (!postLike) return { success: false, error: 'post_like_button_not_found' };

  // Se já é Descurtir/Unlike → já curtiu (missão cumprida)
  const aria = postLike.getAttribute('aria-label') || '';
  if (/descurtir|unlike|não curti|liked/i.test(aria)) {
    dbg('curtir: post já curtido', 'info');
    return { success: true };
  }

  const btn = findClickable(postLike);
  if (!btn) return { success: false, error: 'like_button_not_clickable' };

  dbg(`curtir: clicando botão do post (size=${Math.round(postLike.getBoundingClientRect().width)}px)`, 'info');
  naturalClick(btn);
  await sleep(1500);

  // Confirma: agora deve ter um SVG GRANDE de "Descurtir"
  const confirmed = Array.from(document.querySelectorAll<SVGElement>(
    'svg[aria-label="Descurtir"], svg[aria-label="Unlike"], svg[aria-label="Não curti"]'
  )).some((s) => s.getBoundingClientRect().width >= 20);
  return confirmed ? { success: true } : { success: false, error: 'like_not_confirmed' };
}

// ------------------------------------------------------------
// COMENTAR — selector PT/EN com fallback
// ------------------------------------------------------------
async function comentar(message: string): Promise<{ success: boolean; error?: string }> {
  if (!message) return { success: false, error: 'empty_message' };
  dbg(`comentar: msg="${message.slice(0, 40)}"`, 'step');

  let textarea: HTMLTextAreaElement;
  try {
    textarea = await waitForVisible<HTMLTextAreaElement>(
      [
        'textarea[aria-label="Adicione um comentário..."]',
        'textarea[aria-label="Add a comment..."]',
        'textarea[aria-label*="oment" i]',
        'textarea[placeholder*="oment" i]',
      ],
      12000,
    );
    dbg(`comentar: textarea achado aria="${textarea.getAttribute('aria-label')}"`, 'success');
  } catch (e: any) {
    dbg(`comentar: textarea NÃO encontrado`, 'error');
    return { success: false, error: e.message };
  }

  textarea.scrollIntoView({ block: 'center' });
  textarea.focus();
  await sleep(500);
  await typeText(textarea, message);
  await sleep(1000);

  // Lista todos botões visíveis pra debug
  const visibleBtns = Array.from(document.querySelectorAll<HTMLElement>('button, div[role="button"]'))
    .filter((b) => b.offsetParent !== null && b.innerText && b.innerText.length < 30 && b.innerText.length > 0)
    .map((b) => b.innerText.trim());
  dbg(`comentar: botões visíveis após digitar = [${visibleBtns.slice(0, 15).join(', ')}]`);

  const postBtn = await waitForButtonText([/^postar$/i, /^post$/i, /^publicar$/i], 12000);
  if (!postBtn) {
    dbg(`comentar: botão Postar NÃO encontrado em 12s`, 'error');
    return { success: false, error: 'post_button_not_found' };
  }
  dbg(`comentar: clicando "${postBtn.innerText.trim()}"`, 'step');
  naturalClick(postBtn);
  await sleep(2500);

  const ok = document.body.innerText.includes(message.slice(0, Math.min(15, message.length)));
  if (ok) dbg(`comentar: ✅ confirmado visualmente`, 'success');
  else dbg(`comentar: texto NÃO apareceu no body após click`, 'error');
  return ok ? { success: true } : { success: false, error: 'comment_not_confirmed_visually' };
}

async function waitForButtonText(patterns: RegExp[], timeoutMs: number): Promise<HTMLElement | null> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const buttons = Array.from(document.querySelectorAll<HTMLElement>('button, div[role="button"]'));
    for (const b of buttons) {
      if (b.offsetParent === null) continue;
      const txt = (b.innerText || '').trim();
      if (txt.length > 0 && txt.length < 30 && patterns.some((p) => p.test(txt))) return b;
    }
    await sleep(250);
  }
  return null;
}

// ------------------------------------------------------------
// STORY
// ------------------------------------------------------------

/** Pausa o story atual — IG auto-avança a cada 5-7s.
 * Procura o SVG/button com aria-label "Pausar" / "Pause" e clica.
 * Idempotente: se já estiver pausado (botão vira "Reproduzir"), não faz nada.
 */
async function pausarStory(): Promise<void> {
  // Tenta achar o botão de pausa via SVG com aria-label
  const selectors = ['svg[aria-label="Pausar"]', 'svg[aria-label="Pause"]'];
  for (const sel of selectors) {
    const svg = document.querySelector<SVGElement>(sel);
    if (svg) {
      const btn = findClickable(svg);
      if (btn) {
        naturalClick(btn);
        dbg(`pausarStory: ✅ story pausado (${sel})`, 'success');
        await sleep(400);
        return;
      }
    }
  }
  // Fallback: tecla espaço (IG usa shortcut "space" pra pausar/play stories)
  try {
    document.dispatchEvent(new KeyboardEvent('keydown', { key: ' ', code: 'Space', bubbles: true }));
    dbg(`pausarStory: tentou tecla espaço (fallback)`, 'step');
    await sleep(400);
  } catch {}
}

async function abrirStory(username: string): Promise<{ ok: boolean; error?: string }> {
  dbg(`abrirStory: URL=${window.location.href}`, 'step');

  // Modal "Ver como X?" — só aparece em alguns casos
  const verBtn = await waitForButtonText([/^ver story$/i, /^view story$/i], 5000).catch(() => null);
  if (verBtn) {
    dbg(`abrirStory: clicando "${verBtn.innerText.trim()}"`, 'step');
    naturalClick(verBtn);
    await sleep(2500);
  } else {
    dbg(`abrirStory: sem botão "Ver story" — provavelmente já abriu direto`);
  }

  // Espera story renderizar (até 12s)
  // Seletores cobrindo PT/EN + variações novas que o IG introduziu
  const selectors = [
    'textarea[placeholder*="esponder" i]',
    'textarea[placeholder*="Responder a" i]',
    'textarea[placeholder*="reply" i]',
    'textarea[aria-label*="esponder" i]',
    'textarea[aria-label*="reply" i]',
    'svg[aria-label="Curtir"]',
    'svg[aria-label="Like"]',
    'svg[aria-label="Não curti"]',
    'svg[aria-label="Liked"]',
  ];
  try {
    await waitForVisible<Element>(selectors, 12000);
    dbg(`abrirStory: ✅ story renderizou`, 'success');
    // Pausa o story IMEDIATAMENTE — IG auto-avança em 5-7s (foto) ou no fim do vídeo.
    // Sem pausa, screenshot pode ser do story #1 e digitação pode acontecer no #2.
    // O botão Pausar tem aria-label="Pausar" (pt) ou "Pause" (en).
    await pausarStory();
    return { ok: true };
  } catch {
    // Debug profundo: lista o que apareceu na página
    const allTextareas = Array.from(document.querySelectorAll<HTMLTextAreaElement>('textarea'))
      .filter((t) => t.offsetParent !== null)
      .map((t) => `placeholder="${t.placeholder}" aria="${t.getAttribute('aria-label')}"`);
    const allSvgsAria = Array.from(document.querySelectorAll<SVGElement>('svg[aria-label]'))
      .slice(0, 15)
      .map((s) => s.getAttribute('aria-label'));
    const urlNow = window.location.href;
    const bodySnippet = document.body.innerText.slice(0, 200).replace(/\s+/g, ' ');
    dbg(`abrirStory ❌ no_active_story | URL agora=${urlNow}`, 'error');
    dbg(`textareas visíveis: [${allTextareas.join(' | ') || 'nenhum'}]`, 'error');
    dbg(`svg aria-labels: [${allSvgsAria.join(', ')}]`, 'error');
    dbg(`body: "${bodySnippet}"`, 'error');

    // Se redirecionou pro perfil, é sinal que não tem story
    if (urlNow.includes(`/${username}/`) && !urlNow.includes('/stories/')) {
      return { ok: false, error: 'redirected_to_profile (sem story ativo OU bloqueado)' };
    }
    return { ok: false, error: 'no_active_story' };
  }
}

async function reagirStory(username: string): Promise<{ success: boolean; error?: string }> {
  const opened = await abrirStory(username);
  if (!opened.ok) return { success: false, error: opened.error };

  // Se já tá curtido (Descurtir/Liked), considera success — não precisa clicar de novo
  // Vi no Playwright que o IG mostra "Descurtir" qd já foi reagido antes
  const alreadyLiked = document.querySelector<SVGElement>('svg[aria-label="Descurtir"], svg[aria-label="Liked"], svg[aria-label="Não curti"]');
  if (alreadyLiked) {
    dbg(`reagirStory: ✅ story já tava curtido (${alreadyLiked.getAttribute('aria-label')}) — skip`, 'success');
    return { success: true };
  }

  const likeSvg = await waitForVisible<SVGElement>(
    ['svg[aria-label="Curtir"]', 'svg[aria-label="Like"]'],
    5000,
  ).catch(() => null);
  if (!likeSvg) {
    // Debug: lista os aria-labels visíveis pra entender o que tá renderizado
    const labels = Array.from(document.querySelectorAll<SVGElement>('svg[aria-label]'))
      .slice(0, 15)
      .map((s) => s.getAttribute('aria-label'));
    dbg(`reagirStory ❌ Curtir não achado | labels visíveis: [${labels.join(', ')}]`, 'error');
    return { success: false, error: 'story_like_button_not_found' };
  }
  const btn = findClickable(likeSvg);
  if (!btn) return { success: false, error: 'story_like_not_clickable' };
  naturalClick(btn);
  await sleep(1500);
  return { success: true };
}

async function responderStory(username: string, message: string): Promise<{ success: boolean; error?: string }> {
  if (!message) return { success: false, error: 'empty_message' };

  // STORY-AWARE: se o textarea de resposta já tá visível, significa que a captura
  // anterior já abriu o story e ele continua aberto+pausado. NÃO re-abre.
  // Sem isso, IG pode ter avançado pro próximo story e a msg seria digitada no errado.
  const existingInput = document.querySelector<HTMLElement>(
    'textarea[placeholder*="esponder" i], textarea[aria-label*="esponder" i], textarea[placeholder*="reply" i]'
  );
  if (existingInput && existingInput.offsetParent !== null) {
    dbg(`responderStory: story já aberto (textarea visível) — pula abrirStory`, 'success');
  } else {
    dbg(`responderStory: nenhum textarea visível — abrindo story do zero`, 'step');
    const opened = await abrirStory(username);
    if (!opened.ok) return { success: false, error: opened.error };
  }

  const input = await waitForVisible<HTMLElement>(
    [
      'textarea[placeholder*="esponder" i]',
      'textarea[aria-label*="esponder" i]',
      'textarea[placeholder*="reply" i]',
    ],
    5000,
  );
  input.focus();
  await sleep(300);
  await typeText(input, message);
  await sleep(1200);

  // Botão "Enviar" / "Send" aparece após digitar (button TEXTO, não SVG)
  const sendBtn = await waitForButtonText([/^enviar$/i, /^send$/i], 5000);
  if (sendBtn) {
    naturalClick(sendBtn);
    await sleep(2500);
    return { success: true };
  }
  // Fallback: Enter
  input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true }));
  await sleep(2000);
  return { success: true };
}

// ------------------------------------------------------------
// DM
// ------------------------------------------------------------
async function dismissModals(): Promise<void> {
  // IG mostra modais tipo "Ativar notificações?", "Save your login info?" etc.
  const dismissPatterns = [
    /^agora não$/i,
    /^agora nao$/i,
    /^not now$/i,
    /^não agora$/i,
    /^cancelar$/i,
    /^cancel$/i,
    /^dispense$/i,
    /^dispensar$/i,
    /^talvez depois$/i,
    /^maybe later$/i,
    /^skip$/i,
    /^pular$/i,
  ];
  // Tenta até 3x — modais às vezes encadeiam
  for (let attempt = 0; attempt < 3; attempt++) {
    const btn = await waitForButtonText(dismissPatterns, 1500).catch(() => null);
    if (btn) {
      dbg(`dismissModal[${attempt}]: clicando "${btn.innerText.trim()}"`, 'step');
      naturalClick(btn);
      await sleep(1500);
    } else {
      // Loga estrutura do que tá visível pra debug
      if (attempt === 0) {
        const dialogs = Array.from(document.querySelectorAll<HTMLElement>('[role="dialog"]')).filter((d) => d.offsetParent !== null);
        if (dialogs.length > 0) {
          dbg(`dismissModal: ${dialogs.length} dialog(s) visíveis MAS sem botão dispensar reconhecido`, 'error');
          for (const d of dialogs.slice(0, 2)) {
            const heading = d.querySelector('h1,h2,h3,[role="heading"]')?.textContent?.trim() || '';
            const buttons = Array.from(d.querySelectorAll<HTMLElement>('button, [role="button"]'))
              .filter((b) => b.offsetParent !== null && b.innerText.trim().length > 0 && b.innerText.length < 50)
              .map((b) => b.innerText.trim());
            dbg(`  dialog heading="${heading.slice(0, 80)}" botões=[${buttons.join(' | ')}]`, 'error');
          }
        }
      }
      break;
    }
  }
}

async function enviarDM(_username: string, message: string): Promise<{ success: boolean; error?: string }> {
  if (!message) return { success: false, error: 'empty_message' };

  await dismissModals();

  const msgBtn = await waitForButtonText([/^enviar mensagem$/i, /^message$/i], 8000);
  if (!msgBtn) return { success: false, error: 'message_button_not_found' };
  naturalClick(msgBtn);
  await sleep(4500);

  // Modal "Enviando mensagem para X" aparece quando o lead não te segue
  // → opção paga ("Enviar mensagem prioritária") vs grátis ("Enviar solicitação de contato")
  // SEMPRE escolhemos solicitação de contato (DM frio).
  const requestBtn = await waitForButtonText(
    [/^enviar solicitação de contato$/i, /^send message request$/i, /^solicitação de contato$/i],
    3000,
  ).catch(() => null);
  if (requestBtn) {
    dbg(`enviarDM: lead não segue — clicando "${requestBtn.innerText.trim()}"`, 'step');
    naturalClick(requestBtn);
    await sleep(3000);
  }

  await dismissModals();
  await sleep(500);

  // Textbox de DM (validado: aria-label="Mensagem"/"Message" + role=textbox)
  const dmBox = await waitForVisible<HTMLElement>(
    [
      '[aria-label="Mensagem"][contenteditable="true"]',
      '[aria-label="Message"][contenteditable="true"]',
      'div[role="textbox"][contenteditable="true"]',
    ],
    8000,
  );
  dmBox.focus();
  await sleep(500);
  await typeText(dmBox, message);
  await sleep(1200);

  // Tenta clicar no botão Send (SVG avião) — mais confiável que Enter
  const sendSvg = document.querySelector<SVGElement>('svg[aria-label="Send"], svg[aria-label*="nviar" i]');
  if (sendSvg) {
    const sendBtn = findClickable(sendSvg);
    if (sendBtn) {
      naturalClick(sendBtn);
      await sleep(2500);
      return { success: true };
    }
  }

  // Fallback: Enter
  dmBox.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true }));
  dmBox.dispatchEvent(new KeyboardEvent('keypress', { key: 'Enter', bubbles: true, cancelable: true }));
  await sleep(2500);
  return { success: true };
}

async function verificarResposta(): Promise<{ success: boolean; error?: string }> {
  if (!window.location.href.includes('/direct/inbox/')) {
    window.location.href = 'https://www.instagram.com/direct/inbox/';
    await sleep(3000);
  }
  return { success: true };
}
