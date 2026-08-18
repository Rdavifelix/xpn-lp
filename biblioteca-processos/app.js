/* ============================================================
   Biblioteca de Processos · Máquina de Reuniões
   App estático (sem build): estado local (localStorage) + seed
   publicado via seed-data.js. RBAC: ADMINISTRADOR (CRUD) e
   MEMBRO (somente leitura de conteúdo publicado).
   ============================================================ */
(() => {
  'use strict';

  /* ================= Configuração ================= */

  // SHA-256 da senha de administrador (padrão: "xpn2026").
  // Para trocar: gere o hash de uma nova senha (ex.: `printf 'nova' | sha256sum`)
  // e substitua abaixo. Atenção: proteção client-side — controla a interface,
  // não é segurança de servidor.
  const ADMIN_PASSWORD_SHA256 =
    '2a4b6ac01bfbd93156a83c761dde285697cdf63b0bb1fdc76a2fece3bdc2d8f8';

  const LS_KEYS = {
    data: 'xpnbp:data',
    role: 'xpnbp:role',
    expanded: 'xpnbp:expanded'
  };

  /* ================= Utilidades ================= */

  const $ = (sel, root) => (root || document).querySelector(sel);

  const uid = () =>
    (window.crypto && crypto.randomUUID)
      ? crypto.randomUUID()
      : 'id-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10);

  const esc = (s) =>
    String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[c]));

  const nowISO = () => new Date().toISOString();

  const fmtDate = (iso) => {
    if (!iso) return '';
    try {
      return new Date(iso).toLocaleString('pt-BR', {
        day: '2-digit', month: 'short', year: 'numeric',
        hour: '2-digit', minute: '2-digit'
      });
    } catch (_) { return ''; }
  };

  const norm = (s) =>
    String(s || '')
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '');

  async function sha256Hex(text) {
    if (!(window.crypto && crypto.subtle)) return null; // exige HTTPS/localhost
    const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
    return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join('');
  }

  const htmlToText = (html) => {
    const doc = new DOMParser().parseFromString(html || '', 'text/html');
    return doc.body.textContent || '';
  };

  /* ================= Sanitização de HTML ================= */

  const ALLOWED_TAGS = new Set([
    'P', 'H1', 'H2', 'H3', 'B', 'STRONG', 'I', 'EM', 'U', 'S', 'STRIKE', 'DEL',
    'UL', 'OL', 'LI', 'A', 'BR', 'HR', 'BLOCKQUOTE', 'DIV', 'SPAN', 'CODE'
  ]);
  const DROP_TAGS = new Set([
    'SCRIPT', 'STYLE', 'IFRAME', 'OBJECT', 'EMBED', 'FORM', 'INPUT', 'BUTTON',
    'TEXTAREA', 'SELECT', 'LINK', 'META', 'VIDEO', 'AUDIO', 'CANVAS', 'SVG'
  ]);
  const SAFE_HREF = /^(https?:|mailto:|tel:|#|\/)/i;

  function sanitizeNode(node) {
    let child = node.firstChild;
    while (child) {
      if (child.nodeType === Node.COMMENT_NODE) {
        const next = child.nextSibling; child.remove(); child = next; continue;
      }
      if (child.nodeType !== Node.ELEMENT_NODE) { child = child.nextSibling; continue; }

      const tag = child.tagName.toUpperCase();

      if (DROP_TAGS.has(tag)) {
        const next = child.nextSibling; child.remove(); child = next; continue;
      }

      if (!ALLOWED_TAGS.has(tag)) {
        // desfaz a tag preservando o conteúdo; reprocessa os nós içados
        const first = child.firstChild;
        while (child.firstChild) node.insertBefore(child.firstChild, child);
        const next = first || child.nextSibling;
        child.remove();
        child = next;
        continue;
      }

      // remove atributos perigosos; preserva apenas href seguro em <a>
      for (const attr of Array.from(child.attributes)) {
        const name = attr.name.toLowerCase();
        if (tag === 'A' && name === 'href' && SAFE_HREF.test(attr.value.trim())) continue;
        child.removeAttribute(attr.name);
      }
      if (tag === 'A') {
        child.setAttribute('target', '_blank');
        child.setAttribute('rel', 'noopener noreferrer');
      }

      sanitizeNode(child);
      child = child.nextSibling;
    }
  }

  function sanitizeHTML(html) {
    const doc = new DOMParser().parseFromString(html || '', 'text/html');
    sanitizeNode(doc.body);
    return doc.body.innerHTML;
  }

  /* ================= Estado ================= */

  const seed = (window.XPN_BIBLIOTECA_SEED && typeof window.XPN_BIBLIOTECA_SEED === 'object')
    ? window.XPN_BIBLIOTECA_SEED
    : { version: 0, categories: [] };

  let state = null;          // { seedVersion, hasLocalEdits, categories }
  let isAdmin = false;
  let expanded = {};         // { [id]: bool }
  let searchQuery = '';
  let currentFileId = null;
  let renderedFileId = undefined; // controla re-render do editor
  let seedUpdatePending = false;
  let saveTimer = null;
  let titleTimer = null;

  function defaultState(fromSeed) {
    return {
      seedVersion: Number(fromSeed.version) || 0,
      hasLocalEdits: false,
      categories: JSON.parse(JSON.stringify(fromSeed.categories || []))
    };
  }

  function loadState() {
    let stored = null;
    try { stored = JSON.parse(localStorage.getItem(LS_KEYS.data) || 'null'); } catch (_) { stored = null; }

    if (!stored || !Array.isArray(stored.categories)) {
      state = defaultState(seed);
      persist();
      return;
    }

    state = stored;
    const seedV = Number(seed.version) || 0;
    if (seedV > (Number(state.seedVersion) || 0)) {
      if (!state.hasLocalEdits) {
        state = defaultState(seed);
        persist();
      } else {
        seedUpdatePending = true; // admin decide na interface
      }
    }
  }

  function persist() {
    try { localStorage.setItem(LS_KEYS.data, JSON.stringify(state)); }
    catch (_) { toast('Não foi possível salvar no navegador (armazenamento cheio?).', 'error'); }
  }

  function markEdited() {
    state.hasLocalEdits = true;
    persist();
  }

  function loadExpanded() {
    try { expanded = JSON.parse(localStorage.getItem(LS_KEYS.expanded) || '{}') || {}; }
    catch (_) { expanded = {}; }
  }

  function persistExpanded() {
    try { localStorage.setItem(LS_KEYS.expanded, JSON.stringify(expanded)); } catch (_) {}
  }

  function isExpanded(id, type) {
    if (Object.prototype.hasOwnProperty.call(expanded, id)) return !!expanded[id];
    return type === 'category'; // categorias abertas por padrão
  }

  /* ================= Consultas ================= */

  function findCategory(id) { return state.categories.find((c) => c.id === id) || null; }

  function findFolder(id) {
    for (const cat of state.categories) {
      const folder = (cat.folders || []).find((f) => f.id === id);
      if (folder) return { cat, folder };
    }
    return null;
  }

  function findFile(id) {
    for (const cat of state.categories) {
      for (const folder of (cat.folders || [])) {
        const file = (folder.files || []).find((a) => a.id === id);
        if (file) return { cat, folder, file };
      }
    }
    return null;
  }

  const fileVisible = (file) => isAdmin || !!file.published;
  const folderVisible = (folder) => isAdmin || (folder.files || []).some((f) => f.published);
  const categoryVisible = (cat) => isAdmin || (cat.folders || []).some(folderVisible);

  function stats() {
    let cats = 0, folders = 0, files = 0;
    for (const cat of state.categories) {
      if (!categoryVisible(cat)) continue;
      cats++;
      for (const folder of (cat.folders || [])) {
        if (!folderVisible(folder)) continue;
        folders++;
        for (const file of (folder.files || [])) if (fileVisible(file)) files++;
      }
    }
    return { cats, folders, files };
  }

  /* ================= Ícones / templates ================= */

  const icon = (name, cls) =>
    `<svg class="icon${cls ? ' ' + cls : ''}" aria-hidden="true"><use href="#${name}"/></svg>`;

  /* ================= Toast ================= */

  function toast(msg, type) {
    const root = $('#toastRoot');
    const el = document.createElement('div');
    el.className = 'toast' + (type === 'error' ? ' toast--error' : '');
    el.innerHTML = icon(type === 'error' ? 'i-x' : 'i-check') + `<span>${esc(msg)}</span>`;
    root.appendChild(el);
    setTimeout(() => {
      el.classList.add('is-leaving');
      setTimeout(() => el.remove(), 300);
    }, 3200);
  }

  /* ================= Menu popover ================= */

  let openMenuCleanup = null;

  function closeMenu() {
    if (openMenuCleanup) { openMenuCleanup(); openMenuCleanup = null; }
  }

  function openMenu(anchor, items) {
    closeMenu();
    const root = $('#menuRoot');
    const menu = document.createElement('div');
    menu.className = 'popmenu';
    menu.setAttribute('role', 'menu');

    for (const item of items) {
      if (item === 'sep') {
        menu.insertAdjacentHTML('beforeend', '<div class="popmenu-sep"></div>');
        continue;
      }
      if (item.type === 'label') {
        menu.insertAdjacentHTML('beforeend', `<div class="popmenu-label">${esc(item.label)}</div>`);
        continue;
      }
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'popmenu-item' + (item.danger ? ' popmenu-item--danger' : '');
      btn.setAttribute('role', 'menuitem');
      btn.innerHTML = (item.icon ? icon(item.icon) : '') + `<span>${esc(item.label)}</span>`;
      btn.addEventListener('click', () => { closeMenu(); item.onClick && item.onClick(); });
      menu.appendChild(btn);
    }

    root.appendChild(menu);

    // posicionamento com ajuste às bordas da janela
    const rect = anchor.getBoundingClientRect();
    const mw = menu.offsetWidth, mh = menu.offsetHeight;
    let left = Math.min(rect.left, window.innerWidth - mw - 8);
    let top = rect.bottom + 4;
    if (top + mh > window.innerHeight - 8) top = Math.max(8, rect.top - mh - 4);
    menu.style.left = Math.max(8, left) + 'px';
    menu.style.top = top + 'px';

    const onDocClick = (e) => { if (!menu.contains(e.target)) closeMenu(); };
    const onKey = (e) => { if (e.key === 'Escape') closeMenu(); };
    const onScroll = () => closeMenu();
    setTimeout(() => {
      document.addEventListener('mousedown', onDocClick);
      document.addEventListener('keydown', onKey);
      window.addEventListener('resize', onScroll);
      document.addEventListener('scroll', onScroll, true);
    }, 0);

    openMenuCleanup = () => {
      document.removeEventListener('mousedown', onDocClick);
      document.removeEventListener('keydown', onKey);
      window.removeEventListener('resize', onScroll);
      document.removeEventListener('scroll', onScroll, true);
      menu.remove();
    };
  }

  /* ================= Modal genérico ================= */

  let modalCleanup = null;

  function closeModal() {
    if (modalCleanup) { modalCleanup(); modalCleanup = null; }
  }

  /**
   * openModal({ title, desc, fields, confirmLabel, confirmClass, onConfirm })
   * fields: [{ name, label, type: 'text'|'password'|'url'|'select', value,
   *            placeholder, options: [{value,label}], onChange }]
   * onConfirm(values, api) → retorna string de erro para manter aberto,
   * ou Promise; api = { setError, close }
   */
  function openModal(cfg) {
    closeModal();
    closeMenu();
    const root = $('#modalRoot');
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay';

    const fieldsHTML = (cfg.fields || []).map((f) => {
      if (f.type === 'select') {
        const opts = (f.options || []).map((o) =>
          `<option value="${esc(o.value)}"${o.value === f.value ? ' selected' : ''}>${esc(o.label)}</option>`
        ).join('');
        return `<div class="field"><label for="mf-${esc(f.name)}">${esc(f.label)}</label>
          <select id="mf-${esc(f.name)}" data-name="${esc(f.name)}">${opts}</select></div>`;
      }
      return `<div class="field"><label for="mf-${esc(f.name)}">${esc(f.label)}</label>
        <input id="mf-${esc(f.name)}" data-name="${esc(f.name)}" type="${esc(f.type || 'text')}"
          value="${esc(f.value || '')}" placeholder="${esc(f.placeholder || '')}" autocomplete="off"></div>`;
    }).join('');

    overlay.innerHTML = `
      <div class="modal" role="dialog" aria-modal="true" aria-label="${esc(cfg.title)}">
        <div class="modal-head">
          <h2>${esc(cfg.title)}</h2>
          <button class="iconbtn" data-close aria-label="Fechar">${icon('i-x')}</button>
        </div>
        <div class="modal-body">
          ${cfg.desc ? `<p class="modal-desc">${cfg.desc}</p>` : ''}
          ${fieldsHTML}
          <p class="field-error" data-error></p>
        </div>
        <div class="modal-foot">
          <button class="btn btn-ghost" data-close>Cancelar</button>
          <button class="btn ${cfg.confirmClass || 'btn-primary'}" data-confirm>${esc(cfg.confirmLabel || 'Confirmar')}</button>
        </div>
      </div>`;

    root.appendChild(overlay);

    const errorEl = $('[data-error]', overlay);
    const setError = (msg) => {
      errorEl.textContent = msg || '';
      errorEl.classList.toggle('is-visible', !!msg);
    };

    const getValues = () => {
      const values = {};
      overlay.querySelectorAll('[data-name]').forEach((el) => { values[el.dataset.name] = el.value; });
      return values;
    };

    (cfg.fields || []).forEach((f) => {
      if (f.onChange) {
        const el = $(`#mf-${CSS.escape(f.name)}`, overlay);
        el && el.addEventListener('change', () => f.onChange(getValues(), overlay));
      }
    });

    const confirm = async () => {
      setError('');
      const result = cfg.onConfirm ? await cfg.onConfirm(getValues(), { setError, close: closeModal }) : null;
      if (typeof result === 'string' && result) { setError(result); return; }
      if (result !== false) closeModal();
    };

    overlay.addEventListener('click', (e) => {
      if (e.target === overlay || e.target.closest('[data-close]')) closeModal();
    });
    $('[data-confirm]', overlay).addEventListener('click', confirm);
    overlay.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && e.target.tagName === 'INPUT') { e.preventDefault(); confirm(); }
    });

    const onKey = (e) => { if (e.key === 'Escape') closeModal(); };
    document.addEventListener('keydown', onKey);

    modalCleanup = () => {
      document.removeEventListener('keydown', onKey);
      overlay.remove();
    };

    const firstInput = overlay.querySelector('input, select');
    firstInput && firstInput.focus();
  }

  /* ================= Autenticação (RBAC) ================= */

  function loadRole() {
    isAdmin = localStorage.getItem(LS_KEYS.role) === 'admin';
  }

  function openLoginModal() {
    openModal({
      title: 'Acesso de administrador',
      desc: 'Digite a senha de administrador para liberar a criação e edição de conteúdo.',
      fields: [{ name: 'password', label: 'Senha', type: 'password', placeholder: '••••••••' }],
      confirmLabel: 'Entrar',
      onConfirm: async (values) => {
        const pwd = (values.password || '').trim();
        if (!pwd) return 'Informe a senha.';
        const hash = await sha256Hex(pwd);
        if (hash === null) return 'Este recurso exige HTTPS (ou localhost).';
        if (hash !== ADMIN_PASSWORD_SHA256) return 'Senha incorreta.';
        isAdmin = true;
        localStorage.setItem(LS_KEYS.role, 'admin');
        toast('Bem-vindo, Administrador. Acesso total liberado.');
        renderAll();
      }
    });
  }

  function logout() {
    isAdmin = false;
    localStorage.removeItem(LS_KEYS.role);
    // se estava lendo um rascunho, volta para a página inicial
    const ctx = currentFileId ? findFile(currentFileId) : null;
    if (ctx && !ctx.file.published) {
      currentFileId = null;
      if (location.hash && location.hash !== '#/') location.hash = '#/';
    }
    toast('Sessão encerrada. Modo leitura ativado.');
    renderAll();
  }

  /* ================= CRUD ================= */

  function categoryOptions() {
    return state.categories.map((c) => ({ value: c.id, label: c.name }));
  }

  function currentContext() {
    if (currentFileId) {
      const ctx = findFile(currentFileId);
      if (ctx) return { catId: ctx.cat.id, folderId: ctx.folder.id };
    }
    const cat = state.categories[0];
    return { catId: cat ? cat.id : null, folderId: cat && cat.folders[0] ? cat.folders[0].id : null };
  }

  function openNewCategoryModal() {
    openModal({
      title: 'Nova Categoria',
      desc: 'Categorias são o nível mais alto da hierarquia (ex.: Comercial, Operações, RH).',
      fields: [{ name: 'name', label: 'Nome da categoria', placeholder: 'Ex.: Processos Comerciais' }],
      confirmLabel: 'Criar categoria',
      onConfirm: (v) => {
        const name = (v.name || '').trim();
        if (!name) return 'Dê um nome para a categoria.';
        const cat = { id: uid(), name, folders: [] };
        state.categories.push(cat);
        expanded[cat.id] = true; persistExpanded();
        markEdited();
        renderTree(); renderMain(true); updateAdminButtons();
        toast(`Categoria “${name}” criada.`);
      }
    });
  }

  function openNewFolderModal(presetCatId) {
    if (!state.categories.length) {
      toast('Crie uma categoria antes de criar pastas.', 'error');
      openNewCategoryModal();
      return;
    }
    const ctx = currentContext();
    openModal({
      title: 'Nova Pasta',
      desc: 'A pasta agrupa arquivos dentro de uma categoria.',
      fields: [
        { name: 'catId', label: 'Categoria', type: 'select', options: categoryOptions(), value: presetCatId || ctx.catId },
        { name: 'name', label: 'Nome da pasta', placeholder: 'Ex.: Scripts de Ligação' }
      ],
      confirmLabel: 'Criar pasta',
      onConfirm: (v) => {
        const cat = findCategory(v.catId);
        if (!cat) return 'Selecione uma categoria.';
        const name = (v.name || '').trim();
        if (!name) return 'Dê um nome para a pasta.';
        const folder = { id: uid(), name, files: [] };
        cat.folders = cat.folders || [];
        cat.folders.push(folder);
        expanded[cat.id] = true; expanded[folder.id] = true; persistExpanded();
        markEdited();
        renderTree(); renderMain(true); updateAdminButtons();
        toast(`Pasta “${name}” criada em “${cat.name}”.`);
      }
    });
  }

  function folderOptionsFor(catId) {
    const cat = findCategory(catId);
    return ((cat && cat.folders) || []).map((f) => ({ value: f.id, label: f.name }));
  }

  function openNewFileModal(presetFolderId) {
    const hasFolder = state.categories.some((c) => (c.folders || []).length);
    if (!hasFolder) {
      toast('Crie uma pasta antes de criar arquivos.', 'error');
      openNewFolderModal();
      return;
    }
    const ctx = currentContext();
    let catId = ctx.catId, folderId = presetFolderId || ctx.folderId;
    if (presetFolderId) {
      const hit = findFolder(presetFolderId);
      if (hit) catId = hit.cat.id;
    }
    if (!folderId || !findFolder(folderId)) {
      const firstWithFolder = state.categories.find((c) => (c.folders || []).length);
      catId = firstWithFolder.id;
      folderId = firstWithFolder.folders[0].id;
    }

    openModal({
      title: 'Novo Arquivo',
      desc: 'O arquivo é o documento em si, aberto no editor de texto.',
      fields: [
        {
          name: 'catId', label: 'Categoria', type: 'select',
          options: categoryOptions().filter((o) => folderOptionsFor(o.value).length),
          value: catId,
          onChange: (values, overlay) => {
            const sel = $('#mf-folderId', overlay);
            sel.innerHTML = folderOptionsFor(values.catId)
              .map((o) => `<option value="${esc(o.value)}">${esc(o.label)}</option>`).join('');
          }
        },
        { name: 'folderId', label: 'Pasta', type: 'select', options: folderOptionsFor(catId), value: folderId },
        { name: 'title', label: 'Título do arquivo', placeholder: 'Ex.: Processo de Follow-up' }
      ],
      confirmLabel: 'Criar arquivo',
      onConfirm: (v) => {
        const hit = findFolder(v.folderId);
        if (!hit) return 'Selecione uma pasta.';
        const title = (v.title || '').trim();
        if (!title) return 'Dê um título para o arquivo.';
        const file = {
          id: uid(), title, content: '',
          published: false,
          createdAt: nowISO(), updatedAt: nowISO()
        };
        hit.folder.files = hit.folder.files || [];
        hit.folder.files.push(file);
        expanded[hit.cat.id] = true; expanded[hit.folder.id] = true; persistExpanded();
        markEdited();
        toast(`Arquivo “${title}” criado como rascunho.`);
        location.hash = '#/arquivo/' + file.id;
        renderTree();
      }
    });
  }

  function openRenameModal(type, id) {
    let label, current, apply;
    if (type === 'category') {
      const cat = findCategory(id); if (!cat) return;
      label = 'Nome da categoria'; current = cat.name;
      apply = (name) => { cat.name = name; };
    } else if (type === 'folder') {
      const hit = findFolder(id); if (!hit) return;
      label = 'Nome da pasta'; current = hit.folder.name;
      apply = (name) => { hit.folder.name = name; };
    } else {
      const hit = findFile(id); if (!hit) return;
      label = 'Título do arquivo'; current = hit.file.title;
      apply = (name) => { hit.file.title = name; hit.file.updatedAt = nowISO(); };
    }
    openModal({
      title: 'Renomear',
      fields: [{ name: 'name', label, value: current }],
      confirmLabel: 'Salvar',
      onConfirm: (v) => {
        const name = (v.name || '').trim();
        if (!name) return 'O nome não pode ficar vazio.';
        apply(name);
        markEdited();
        renderTree(); renderMain(true);
        toast('Renomeado com sucesso.');
      }
    });
  }

  function openDeleteModal(type, id) {
    let title, desc, apply;
    if (type === 'category') {
      const cat = findCategory(id); if (!cat) return;
      const nFolders = (cat.folders || []).length;
      const nFiles = (cat.folders || []).reduce((n, f) => n + (f.files || []).length, 0);
      title = 'Excluir categoria';
      desc = `A categoria <b>${esc(cat.name)}</b> será excluída junto com <b>${nFolders} pasta(s)</b> e <b>${nFiles} arquivo(s)</b>. Essa ação não pode ser desfeita.`;
      apply = () => {
        if (currentFileId && (cat.folders || []).some((f) => (f.files || []).some((a) => a.id === currentFileId))) goHome();
        state.categories = state.categories.filter((c) => c.id !== id);
      };
    } else if (type === 'folder') {
      const hit = findFolder(id); if (!hit) return;
      const nFiles = (hit.folder.files || []).length;
      title = 'Excluir pasta';
      desc = `A pasta <b>${esc(hit.folder.name)}</b> será excluída junto com <b>${nFiles} arquivo(s)</b>. Essa ação não pode ser desfeita.`;
      apply = () => {
        if (currentFileId && (hit.folder.files || []).some((a) => a.id === currentFileId)) goHome();
        hit.cat.folders = hit.cat.folders.filter((f) => f.id !== id);
      };
    } else {
      const hit = findFile(id); if (!hit) return;
      title = 'Excluir arquivo';
      desc = `O arquivo <b>${esc(hit.file.title)}</b> será excluído. Essa ação não pode ser desfeita.`;
      apply = () => {
        if (currentFileId === id) goHome();
        hit.folder.files = hit.folder.files.filter((a) => a.id !== id);
      };
    }
    openModal({
      title, desc,
      confirmLabel: 'Excluir',
      confirmClass: 'btn-danger',
      onConfirm: () => {
        apply();
        markEdited();
        renderTree(); renderMain(true); updateAdminButtons();
        toast('Excluído com sucesso.');
      }
    });
  }

  function togglePublish(fileId) {
    const hit = findFile(fileId);
    if (!hit) return;
    hit.file.published = !hit.file.published;
    hit.file.updatedAt = nowISO();
    markEdited();
    renderTree(); renderMain(true);
    toast(hit.file.published
      ? `“${hit.file.title}” publicado — visível para todos.`
      : `“${hit.file.title}” voltou para rascunho.`);
  }

  function goHome() {
    currentFileId = null;
    if (location.hash && location.hash !== '#/') location.hash = '#/';
  }

  /* ================= Exportar / importar seed ================= */

  function exportSeed() {
    const payload = {
      version: (Number(state.seedVersion) || 0) + 1,
      categories: state.categories
    };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'biblioteca-seed.json';
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 4000);
    toast('Seed exportado. Substitua o conteúdo de seed-data.js para publicar a todos.');
  }

  function importSeedFile() {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'application/json,.json';
    input.addEventListener('change', () => {
      const file = input.files && input.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        let data;
        try { data = JSON.parse(String(reader.result)); }
        catch (_) { toast('Arquivo inválido: não é um JSON válido.', 'error'); return; }
        if (!data || !Array.isArray(data.categories)) {
          toast('JSON inválido: esperado { version, categories: [...] }.', 'error');
          return;
        }
        openModal({
          title: 'Importar dados',
          desc: `Isso substituirá <b>toda a estrutura atual</b> deste navegador por ${data.categories.length} categoria(s) do arquivo importado.`,
          confirmLabel: 'Importar e substituir',
          confirmClass: 'btn-danger',
          onConfirm: () => {
            state.categories = data.categories;
            if (data.version) state.seedVersion = Number(data.version) || state.seedVersion;
            state.hasLocalEdits = true;
            persist();
            goHome();
            renderAll();
            toast('Dados importados com sucesso.');
          }
        });
      };
      reader.readAsText(file);
    });
    input.click();
  }

  function restoreSeed() {
    openModal({
      title: 'Restaurar dados publicados',
      desc: 'Suas edições locais neste navegador serão descartadas e os dados publicados (seed) serão recarregados.',
      confirmLabel: 'Restaurar',
      confirmClass: 'btn-danger',
      onConfirm: () => {
        state = defaultState(seed);
        persist();
        seedUpdatePending = false;
        goHome();
        renderAll();
        toast('Dados publicados restaurados.');
      }
    });
  }

  /* ================= Árvore (sidebar interna) ================= */

  function treeRow({ type, id, label, iconName, open, hasChildren, active, badges, actions, depthClass }) {
    return `
      <div class="tree-row tree-row--${type} ${open ? 'is-open' : ''} ${active ? 'is-active' : ''} ${depthClass || ''}"
           data-type="${type}" data-id="${esc(id)}" tabindex="0" role="treeitem"
           ${hasChildren !== undefined ? `aria-expanded="${open}"` : ''}>
        ${hasChildren !== undefined
          ? `<span class="twisty" data-action="toggle" aria-hidden="true">${icon('i-chevron')}</span>`
          : '<span class="twisty" aria-hidden="true"></span>'}
        <span class="tree-ico">${icon(iconName)}</span>
        <span class="tree-label">${esc(label)}</span>
        ${badges || ''}
        ${actions || ''}
      </div>`;
  }

  function adminRowActions(type, id, extra) {
    if (!isAdmin) return '';
    let plus = '';
    if (extra && extra.plus) {
      plus = `<button class="iconbtn" data-action="${extra.plus.action}" data-id="${esc(id)}"
        aria-label="${esc(extra.plus.label)}" title="${esc(extra.plus.label)}">${icon('i-plus')}</button>`;
    }
    return `<span class="row-actions">
      ${plus}
      <button class="iconbtn" data-action="menu" data-type="${type}" data-id="${esc(id)}"
        aria-label="Mais opções" title="Mais opções">${icon('i-more')}</button>
    </span>`;
  }

  function renderTree() {
    const tree = $('#tree');
    const q = norm(searchQuery.trim());

    let html = '';

    if (seedUpdatePending && isAdmin) {
      html += `
        <div class="seed-banner">
          <strong>Dados publicados atualizados (v${esc(seed.version)})</strong>
          Você tem edições locais neste navegador. O que deseja fazer?
          <div class="seed-banner-actions">
            <button class="btn btn-sm btn-primary" data-action="seed-adopt">Usar publicados</button>
            <button class="btn btn-sm btn-ghost" data-action="seed-keep">Manter edições</button>
          </div>
        </div>`;
    }

    if (q) {
      const results = [];
      for (const cat of state.categories) {
        for (const folder of (cat.folders || [])) {
          for (const file of (folder.files || [])) {
            if (!fileVisible(file)) continue;
            if (norm(file.title).includes(q) || norm(htmlToText(file.content)).includes(q)) {
              results.push({ cat, folder, file });
            }
          }
        }
      }
      html += `<div class="tree-search-meta">${results.length} resultado(s) para “${esc(searchQuery.trim())}”</div>`;
      if (!results.length) {
        html += `<div class="tree-blank">${icon('i-search')}<p>Nenhum documento encontrado.<br>Tente outra palavra-chave.</p></div>`;
      } else {
        for (const r of results) {
          html += treeRow({
            type: 'file', id: r.file.id,
            label: r.file.title || 'Sem título',
            iconName: 'i-file',
            active: r.file.id === currentFileId,
            badges: isAdmin && !r.file.published ? '<span class="badge badge--draft">Rascunho</span>' : '',
            actions: ''
          });
          html += `<div class="tree-empty-hint">${esc(r.cat.name)} / ${esc(r.folder.name)}</div>`;
        }
      }
      tree.innerHTML = html;
      return;
    }

    const visibleCats = state.categories.filter(categoryVisible);

    if (!visibleCats.length) {
      if (isAdmin) {
        html += `
          <div class="tree-blank">
            ${icon('i-inbox')}
            <p><b>Estrutura vazia.</b><br>Crie a primeira categoria para começar a montar a biblioteca.</p>
            <button class="btn btn-primary btn-sm" data-action="new-category">${icon('i-plus')} Nova Categoria</button>
          </div>`;
      } else {
        html += `
          <div class="tree-blank">
            ${icon('i-inbox')}
            <p>Nenhum conteúdo publicado ainda.<br>Volte em breve.</p>
          </div>`;
      }
      tree.innerHTML = html;
      return;
    }

    for (const cat of visibleCats) {
      const catOpen = isExpanded(cat.id, 'category');
      const folders = (cat.folders || []).filter(folderVisible);

      html += `<div class="tree-group">`;
      html += treeRow({
        type: 'category', id: cat.id, label: cat.name, iconName: 'i-inbox',
        open: catOpen, hasChildren: true,
        actions: adminRowActions('category', cat.id, { plus: { action: 'new-folder-in', label: 'Nova pasta nesta categoria' } })
      });

      html += `<div class="tree-children ${catOpen ? '' : 'is-collapsed'}">`;

      if (!folders.length) {
        html += isAdmin
          ? `<button class="tree-add-inline" data-action="new-folder-in" data-id="${esc(cat.id)}">${icon('i-plus')} Nova pasta</button>`
          : `<div class="tree-empty-hint">Sem pastas publicadas</div>`;
      }

      for (const folder of folders) {
        const folderOpen = isExpanded(folder.id, 'folder');
        const files = (folder.files || []).filter(fileVisible);

        html += treeRow({
          type: 'folder', id: folder.id, label: folder.name, iconName: 'i-folder',
          open: folderOpen, hasChildren: true,
          actions: adminRowActions('folder', folder.id, { plus: { action: 'new-file-in', label: 'Novo arquivo nesta pasta' } })
        });

        html += `<div class="tree-children ${folderOpen ? '' : 'is-collapsed'}">`;

        if (!files.length) {
          html += isAdmin
            ? `<button class="tree-add-inline" data-action="new-file-in" data-id="${esc(folder.id)}">${icon('i-plus')} Novo arquivo</button>`
            : `<div class="tree-empty-hint">Sem arquivos publicados</div>`;
        }

        for (const file of files) {
          html += treeRow({
            type: 'file', id: file.id,
            label: file.title || 'Sem título',
            iconName: 'i-file',
            active: file.id === currentFileId,
            badges: isAdmin && !file.published ? '<span class="badge badge--draft">Rascunho</span>' : '',
            actions: adminRowActions('file', file.id)
          });
        }

        if (files.length && isAdmin) {
          html += `<button class="tree-add-inline" data-action="new-file-in" data-id="${esc(folder.id)}">${icon('i-plus')} Novo arquivo</button>`;
        }

        html += `</div>`; // children files
      }

      if (folders.length && isAdmin) {
        html += `<button class="tree-add-inline" data-action="new-folder-in" data-id="${esc(cat.id)}">${icon('i-plus')} Nova pasta</button>`;
      }

      html += `</div></div>`; // children folders, group
    }

    tree.innerHTML = html;
  }

  function onTreeClick(e) {
    const actionEl = e.target.closest('[data-action]');
    if (actionEl) {
      const action = actionEl.dataset.action;
      const id = actionEl.dataset.id || (actionEl.closest('.tree-row') || {}).dataset?.id;

      if (action === 'toggle') {
        const row = actionEl.closest('.tree-row');
        toggleRow(row);
        return;
      }
      if (action === 'menu') {
        openTreeMenu(actionEl, actionEl.dataset.type, actionEl.dataset.id);
        return;
      }
      if (action === 'new-category') { openNewCategoryModal(); return; }
      if (action === 'new-folder-in') { openNewFolderModal(id); return; }
      if (action === 'new-file-in') { openNewFileModal(id); return; }
      if (action === 'seed-adopt') {
        state = defaultState(seed);
        persist();
        seedUpdatePending = false;
        goHome(); renderAll();
        toast('Dados publicados aplicados.');
        return;
      }
      if (action === 'seed-keep') {
        state.seedVersion = Number(seed.version) || state.seedVersion;
        persist();
        seedUpdatePending = false;
        renderTree();
        toast('Mantendo suas edições locais.');
        return;
      }
    }

    const row = e.target.closest('.tree-row');
    if (!row) return;
    if (row.dataset.type === 'file') {
      location.hash = '#/arquivo/' + row.dataset.id;
      closeDrawer();
    } else {
      toggleRow(row);
    }
  }

  function toggleRow(row) {
    if (!row) return;
    const id = row.dataset.id;
    const type = row.dataset.type;
    expanded[id] = !isExpanded(id, type);
    persistExpanded();
    row.classList.toggle('is-open', expanded[id]);
    row.setAttribute('aria-expanded', String(expanded[id]));
    const children = row.nextElementSibling;
    if (children && children.classList.contains('tree-children')) {
      children.classList.toggle('is-collapsed', !expanded[id]);
    }
  }

  function openTreeMenu(anchor, type, id) {
    if (type === 'category') {
      openMenu(anchor, [
        { label: 'Renomear', icon: 'i-pencil', onClick: () => openRenameModal('category', id) },
        { label: 'Nova Pasta', icon: 'i-plus', onClick: () => openNewFolderModal(id) },
        'sep',
        { label: 'Excluir categoria', icon: 'i-trash', danger: true, onClick: () => openDeleteModal('category', id) }
      ]);
    } else if (type === 'folder') {
      openMenu(anchor, [
        { label: 'Renomear', icon: 'i-pencil', onClick: () => openRenameModal('folder', id) },
        { label: 'Novo Arquivo', icon: 'i-plus', onClick: () => openNewFileModal(id) },
        'sep',
        { label: 'Excluir pasta', icon: 'i-trash', danger: true, onClick: () => openDeleteModal('folder', id) }
      ]);
    } else {
      const hit = findFile(id);
      const published = hit && hit.file.published;
      openMenu(anchor, [
        { label: 'Renomear', icon: 'i-pencil', onClick: () => openRenameModal('file', id) },
        {
          label: published ? 'Despublicar (voltar a rascunho)' : 'Publicar',
          icon: published ? 'i-eye-off' : 'i-globe',
          onClick: () => togglePublish(id)
        },
        'sep',
        { label: 'Excluir arquivo', icon: 'i-trash', danger: true, onClick: () => openDeleteModal('file', id) }
      ]);
    }
  }

  /* ================= Área principal ================= */

  function renderMain(force) {
    const container = $('#mainContent');

    if (!currentFileId) {
      renderedFileId = null;
      renderHome(container);
      return;
    }

    const hit = findFile(currentFileId);
    if (!hit || !fileVisible(hit.file)) {
      renderedFileId = null;
      currentFileId = null;
      renderHome(container);
      return;
    }

    if (!force && renderedFileId === currentFileId) return; // preserva o cursor do editor
    renderedFileId = currentFileId;

    const { cat, folder, file } = hit;
    const safeContent = sanitizeHTML(file.content || '');

    const badge = file.published
      ? '<span class="badge badge--published">Publicado</span>'
      : '<span class="badge badge--draft">Rascunho</span>';

    const adminTopActions = isAdmin ? `
      <div class="doc-topline-actions">
        <span class="savestate" id="saveState">Salvo</span>
        <button class="btn btn-sm ${file.published ? 'btn-ghost' : 'btn-primary'}" id="btnPublish">
          ${icon(file.published ? 'i-eye-off' : 'i-globe')}
          ${file.published ? 'Despublicar' : 'Publicar'}
        </button>
        <button class="iconbtn" id="btnDocMenu" aria-label="Mais opções">${icon('i-more')}</button>
      </div>` : '';

    const toolbar = isAdmin ? `
      <div class="toolbar" id="toolbar" role="toolbar" aria-label="Formatação de texto">
        <button class="tb-btn" data-block="P" title="Texto normal">T</button>
        <button class="tb-btn" data-block="H1" title="Título 1">H1</button>
        <button class="tb-btn" data-block="H2" title="Título 2">H2</button>
        <button class="tb-btn" data-block="H3" title="Título 3">H3</button>
        <span class="tb-sep"></span>
        <button class="tb-btn" data-cmd="bold" title="Negrito (Ctrl+B)"><b>B</b></button>
        <button class="tb-btn" data-cmd="italic" title="Itálico (Ctrl+I)"><span class="tb-i">I</span></button>
        <button class="tb-btn" data-cmd="underline" title="Sublinhado (Ctrl+U)"><span class="tb-u">U</span></button>
        <button class="tb-btn" data-cmd="strikeThrough" title="Tachado"><span class="tb-s">S</span></button>
        <span class="tb-sep"></span>
        <button class="tb-btn" data-cmd="insertUnorderedList" title="Lista com marcadores">${icon('i-list')}</button>
        <button class="tb-btn" data-cmd="insertOrderedList" title="Lista numerada">${icon('i-list-ol')}</button>
        <button class="tb-btn" data-block="BLOCKQUOTE" title="Citação">${icon('i-quote')}</button>
        <span class="tb-sep"></span>
        <button class="tb-btn" data-special="link" title="Inserir link">${icon('i-link')}</button>
        <button class="tb-btn" data-cmd="insertHorizontalRule" title="Divisor">${icon('i-minus')}</button>
        <button class="tb-btn" data-special="clear" title="Limpar formatação">${icon('i-eraser')}</button>
      </div>` : '';

    container.innerHTML = `
      <div class="doc-wrap">
        <div class="doc-topline">
          <nav class="breadcrumb" aria-label="Localização">
            <span class="crumb">${icon('i-inbox')} ${esc(cat.name)}</span>
            <span class="crumb-sep">/</span>
            <span class="crumb">${icon('i-folder')} ${esc(folder.name)}</span>
            <span class="crumb-sep">/</span>
            <span class="crumb crumb--current">${esc(file.title || 'Sem título')}</span>
          </nav>
          ${adminTopActions}
        </div>

        ${toolbar}

        <h1 class="doc-title" id="docTitle" ${isAdmin ? 'contenteditable="true" spellcheck="false"' : ''}>${esc(file.title || '')}</h1>
        <p class="doc-meta">Atualizado em ${esc(fmtDate(file.updatedAt))} ${isAdmin ? badge : ''}</p>

        <div class="doc-content ${!safeContent.trim() ? 'is-blank' : ''}" id="docContent"
             data-placeholder="${isAdmin ? 'Escreva o processo aqui… Use a barra acima para formatar.' : 'Este documento ainda não tem conteúdo.'}"
             ${isAdmin ? 'contenteditable="true"' : ''} spellcheck="false">${safeContent}</div>
      </div>`;

    if (isAdmin) bindEditor(file);
  }

  function renderHome(container) {
    const s = stats();
    const empty = s.files === 0;

    let cta = '';
    let note = '';

    if (isAdmin) {
      if (!state.categories.length) {
        cta = `<div class="hero-cta">
          <button class="btn btn-primary" data-home-action="new-category">${icon('i-plus')} Nova Categoria</button>
        </div>`;
        note = `<div class="hero-note">${icon('i-database')}
          <span><b>Estrutura pronta para o seed.</b> Monte categorias, pastas e arquivos pela interface (ou importe um JSON no menu <b>Dados</b>, no rodapé da barra lateral). Depois use <b>Exportar seed</b> para publicar o conteúdo a todos de uma só vez.</span></div>`;
      } else {
        cta = `<div class="hero-cta">
          <button class="btn btn-primary" data-home-action="new-file">${icon('i-plus')} Novo Arquivo</button>
          <button class="btn btn-ghost" data-home-action="new-folder">${icon('i-plus')} Nova Pasta</button>
        </div>`;
      }
    } else if (empty) {
      note = `<div class="hero-note">${icon('i-inbox')}
        <span>Ainda não há documentos publicados. Assim que a equipe publicar os primeiros processos, eles aparecerão aqui.</span></div>`;
    }

    container.innerHTML = `
      <div class="doc-wrap">
        <div class="hero">
          <span class="hero-ico">${icon('i-book')}</span>
          <h1>Biblioteca de Processos</h1>
          <p>Central de conhecimento da Máquina de Reuniões. Navegue pelas categorias e pastas na barra lateral para abrir um documento${isAdmin ? ', ou crie novos conteúdos' : ''}.</p>
          <div class="hero-stats">
            <div class="stat"><b>${s.cats}</b><span>Categorias</span></div>
            <div class="stat"><b>${s.folders}</b><span>Pastas</span></div>
            <div class="stat"><b>${s.files}</b><span>Documentos</span></div>
          </div>
          ${cta}
          ${note}
        </div>
      </div>`;
  }

  function onMainClick(e) {
    const homeBtn = e.target.closest('[data-home-action]');
    if (homeBtn) {
      const a = homeBtn.dataset.homeAction;
      if (a === 'new-category') openNewCategoryModal();
      if (a === 'new-folder') openNewFolderModal();
      if (a === 'new-file') openNewFileModal();
      return;
    }
    const publish = e.target.closest('#btnPublish');
    if (publish && currentFileId) { togglePublish(currentFileId); return; }

    const docMenu = e.target.closest('#btnDocMenu');
    if (docMenu && currentFileId) {
      const id = currentFileId;
      openMenu(docMenu, [
        { label: 'Renomear', icon: 'i-pencil', onClick: () => openRenameModal('file', id) },
        'sep',
        { label: 'Excluir arquivo', icon: 'i-trash', danger: true, onClick: () => openDeleteModal('file', id) }
      ]);
    }
  }

  /* ================= Editor ================= */

  let savedRange = null;

  function setSaveState(text, saving) {
    const el = $('#saveState');
    if (!el) return;
    el.textContent = text;
    el.classList.toggle('is-saving', !!saving);
  }

  function bindEditor(file) {
    const editor = $('#docContent');
    const titleEl = $('#docTitle');
    const toolbar = $('#toolbar');
    if (!editor) return;

    try { document.execCommand('defaultParagraphSeparator', false, 'p'); } catch (_) {}

    const commitContent = () => {
      const hit = findFile(file.id);
      if (!hit) return;
      hit.file.content = sanitizeHTML(editor.innerHTML);
      hit.file.updatedAt = nowISO();
      markEdited();
      setSaveState('Salvo às ' + new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }));
    };

    editor.addEventListener('input', () => {
      editor.classList.toggle('is-blank', !editor.textContent.trim() && !editor.querySelector('hr, li'));
      setSaveState('Salvando…', true);
      clearTimeout(saveTimer);
      saveTimer = setTimeout(commitContent, 700);
    });

    editor.addEventListener('blur', () => { clearTimeout(saveTimer); commitContent(); });

    // cola sempre como texto simples (mantém o documento limpo)
    editor.addEventListener('paste', (e) => {
      e.preventDefault();
      const text = (e.clipboardData || window.clipboardData).getData('text/plain');
      document.execCommand('insertText', false, text);
    });

    // ---- título ----
    if (titleEl) {
      const commitTitle = () => {
        const hit = findFile(file.id);
        if (!hit) return;
        const t = titleEl.textContent.trim();
        hit.file.title = t || 'Sem título';
        hit.file.updatedAt = nowISO();
        markEdited();
        renderTree();
        setSaveState('Salvo às ' + new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }));
      };
      titleEl.addEventListener('input', () => {
        setSaveState('Salvando…', true);
        clearTimeout(titleTimer);
        titleTimer = setTimeout(commitTitle, 700);
      });
      titleEl.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') { e.preventDefault(); editor.focus(); }
      });
      titleEl.addEventListener('paste', (e) => {
        e.preventDefault();
        const text = (e.clipboardData || window.clipboardData).getData('text/plain').replace(/\n+/g, ' ');
        document.execCommand('insertText', false, text);
      });
      titleEl.addEventListener('blur', () => { clearTimeout(titleTimer); commitTitle(); });
    }

    // ---- barra de formatação ----
    if (toolbar) {
      toolbar.addEventListener('mousedown', (e) => e.preventDefault()); // preserva a seleção
      // (listener global de selectionchange é registrado uma única vez no init)

      toolbar.addEventListener('click', (e) => {
        const btn = e.target.closest('.tb-btn');
        if (!btn) return;
        editor.focus();

        if (btn.dataset.cmd) {
          document.execCommand(btn.dataset.cmd, false, null);
        } else if (btn.dataset.block) {
          const target = btn.dataset.block;
          const cur = (document.queryCommandValue('formatBlock') || '').toUpperCase();
          document.execCommand('formatBlock', false, cur === target ? 'P' : target);
        } else if (btn.dataset.special === 'link') {
          openLinkModal(editor);
          return;
        } else if (btn.dataset.special === 'clear') {
          document.execCommand('removeFormat', false, null);
          document.execCommand('unlink', false, null);
          document.execCommand('formatBlock', false, 'P');
        }
        updateToolbarState();
        editor.dispatchEvent(new Event('input'));
      });

    }

    updateToolbarState();
  }

  function onSelectionChange() {
    const editor = $('#docContent');
    if (!editor || !isAdmin) return;
    const sel = document.getSelection();
    if (!sel || !sel.anchorNode || !editor.contains(sel.anchorNode)) return;
    updateToolbarState();
  }

  function updateToolbarState() {
    const toolbar = $('#toolbar');
    if (!toolbar) return;
    const block = (function () {
      try { return (document.queryCommandValue('formatBlock') || '').toUpperCase(); }
      catch (_) { return ''; }
    })();
    toolbar.querySelectorAll('.tb-btn').forEach((btn) => {
      let on = false;
      try {
        if (btn.dataset.cmd && ['bold', 'italic', 'underline', 'strikeThrough', 'insertUnorderedList', 'insertOrderedList'].includes(btn.dataset.cmd)) {
          on = document.queryCommandState(btn.dataset.cmd);
        } else if (btn.dataset.block) {
          on = block === btn.dataset.block || (btn.dataset.block === 'P' && (block === 'P' || block === 'DIV' || block === ''));
        }
      } catch (_) {}
      btn.classList.toggle('is-on', !!on);
    });
  }

  function openLinkModal(editor) {
    const sel = document.getSelection();
    savedRange = (sel && sel.rangeCount) ? sel.getRangeAt(0).cloneRange() : null;
    const hasSelection = savedRange && !savedRange.collapsed;

    openModal({
      title: 'Inserir link',
      desc: hasSelection ? 'O link será aplicado ao texto selecionado.' : 'Informe o texto e o endereço do link.',
      fields: [
        ...(hasSelection ? [] : [{ name: 'text', label: 'Texto do link', placeholder: 'Ex.: Playbook comercial' }]),
        { name: 'url', label: 'URL', type: 'url', placeholder: 'https://…' }
      ],
      confirmLabel: 'Inserir',
      onConfirm: (v) => {
        let url = (v.url || '').trim();
        if (!url) return 'Informe a URL.';
        if (!/^(https?:|mailto:|tel:|#|\/)/i.test(url)) url = 'https://' + url;

        editor.focus();
        if (savedRange) {
          const s = document.getSelection();
          s.removeAllRanges();
          s.addRange(savedRange);
        }
        if (hasSelection) {
          document.execCommand('createLink', false, url);
        } else {
          const text = (v.text || '').trim() || url;
          document.execCommand('insertHTML', false,
            `<a href="${esc(url)}" target="_blank" rel="noopener noreferrer">${esc(text)}</a>&nbsp;`);
        }
        editor.dispatchEvent(new Event('input'));
      }
    });
  }

  /* ================= Chrome (rail, botões admin, rodapé) ================= */

  function renderRailUser() {
    const el = $('#railUser');
    if (isAdmin) {
      el.innerHTML = `
        <button class="rail-user" id="railUserBtn" title="Conta">
          <span class="rail-avatar is-admin">${icon('i-user')}</span>
          <span class="rail-user-info">
            <span class="rail-user-name">Administrador</span>
            <span class="rail-user-role">Acesso total (CRUD)</span>
          </span>
          ${icon('i-more')}
        </button>`;
      $('#railUserBtn').addEventListener('click', (e) => {
        openMenu(e.currentTarget, [
          { type: 'label', label: 'Administrador' },
          { label: 'Exportar seed (JSON)', icon: 'i-download', onClick: exportSeed },
          { label: 'Importar JSON…', icon: 'i-upload', onClick: importSeedFile },
          { label: 'Restaurar dados publicados', icon: 'i-restore', onClick: restoreSeed },
          'sep',
          { label: 'Sair (modo leitura)', icon: 'i-logout', onClick: logout }
        ]);
      });
    } else {
      el.innerHTML = `
        <button class="rail-user" id="railUserBtn" title="Entrar como administrador">
          <span class="rail-avatar">${icon('i-user')}</span>
          <span class="rail-user-info">
            <span class="rail-user-name">Visitante</span>
            <span class="rail-user-role">Somente leitura</span>
          </span>
          ${icon('i-login')}
        </button>`;
      $('#railUserBtn').addEventListener('click', openLoginModal);
    }
  }

  function renderFoot() {
    const el = $('#libnavFoot');
    if (isAdmin) {
      el.innerHTML = `<button class="foot-btn" id="footData">${icon('i-database')} Dados · exportar, importar, sair</button>`;
      $('#footData').addEventListener('click', (e) => {
        openMenu(e.currentTarget, [
          { type: 'label', label: 'Dados da biblioteca' },
          { label: 'Exportar seed (JSON)', icon: 'i-download', onClick: exportSeed },
          { label: 'Importar JSON…', icon: 'i-upload', onClick: importSeedFile },
          { label: 'Restaurar dados publicados', icon: 'i-restore', onClick: restoreSeed },
          'sep',
          { label: 'Sair (modo leitura)', icon: 'i-logout', onClick: logout }
        ]);
      });
    } else {
      el.innerHTML = `<button class="foot-btn" id="footLogin">${icon('i-lock')} Acesso de administrador</button>`;
      $('#footLogin').addEventListener('click', openLoginModal);
    }
  }

  function updateAdminButtons() {
    $('#adminActions').hidden = !isAdmin;
  }

  /* ================= Drawer mobile ================= */

  function openDrawer() {
    $('#libnav').classList.add('is-open');
    $('#backdrop').hidden = false;
  }

  function closeDrawer() {
    $('#libnav').classList.remove('is-open');
    $('#backdrop').hidden = true;
  }

  /* ================= Roteamento ================= */

  function onRoute() {
    const m = location.hash.match(/^#\/arquivo\/([\w-]+)/);
    if (m) {
      const hit = findFile(m[1]);
      if (hit && fileVisible(hit.file)) {
        currentFileId = m[1];
      } else {
        currentFileId = null;
        toast('Documento não encontrado ou não publicado.', 'error');
        history.replaceState(null, '', location.pathname + '#/');
      }
    } else {
      currentFileId = null;
    }
    renderTree();
    renderMain();
    const scroll = $('#mainScroll');
    if (scroll) scroll.scrollTop = 0;
  }

  /* ================= Render geral / init ================= */

  function renderAll() {
    renderRailUser();
    renderFoot();
    updateAdminButtons();
    renderTree();
    renderMain(true);
  }

  function init() {
    loadRole();
    loadState();
    loadExpanded();

    // eventos fixos
    $('#tree').addEventListener('click', onTreeClick);
    $('#tree').addEventListener('keydown', (e) => {
      if ((e.key === 'Enter' || e.key === ' ') && e.target.classList.contains('tree-row')) {
        e.preventDefault();
        e.target.click();
      }
    });
    $('#mainContent').addEventListener('click', onMainClick);

    $('#btnNewCategory').addEventListener('click', () => openNewCategoryModal());
    $('#btnNewFolder').addEventListener('click', () => openNewFolderModal());
    $('#btnNewFile').addEventListener('click', () => openNewFileModal());

    $('#searchInput').addEventListener('input', (e) => {
      searchQuery = e.target.value;
      renderTree();
    });

    $('#btnOpenNav').addEventListener('click', openDrawer);
    $('#libnavClose').addEventListener('click', closeDrawer);
    $('#backdrop').addEventListener('click', closeDrawer);

    window.addEventListener('hashchange', onRoute);
    document.addEventListener('selectionchange', onSelectionChange);

    renderRailUser();
    renderFoot();
    updateAdminButtons();
    onRoute(); // já chama renderTree + renderMain
  }

  document.readyState === 'loading'
    ? document.addEventListener('DOMContentLoaded', init)
    : init();
})();
