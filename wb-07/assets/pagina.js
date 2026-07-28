/* =========================================================
   AGENDA CHEIA — JS compartilhado
   Configure a data do evento no <head> de cada página:
   <script>window.CFG={DATA_EVENTO:'2026-08-03T20:00:00-03:00'}</script>

   Os CTAs abrem o modal com o form do CRM XPN
   ([WB] Cadastro Webinar — 591c52c0-3217-4708-a477-8da0edf40ba7),
   embedado via FormEmbed como em lp2 / lp2-d / fap01.
   ========================================================= */
(function () {
  var CFG = window.CFG || {};

  /* ---- 1. Modal de inscrição ---- */
  var modal = document.querySelector('.modal');
  var ultimoFoco = null;

  function abrir(pos) {
    if (!modal) return;
    carregarForm();          // iframe só carrega quando o modal abre (ver bloco 2)
    ultimoFoco = document.activeElement;
    modal.classList.add('aberto');
    modal.setAttribute('aria-hidden', 'false');
    document.body.classList.add('travado');

    var x = modal.querySelector('.modal__x');
    if (x) x.focus();

    /* rastreio: qual seção da página gerou a abertura do form */
    if (window.fbq) fbq('track', 'Lead', { content_name: 'form-webinar', position: pos });
    if (window.gtag) gtag('event', 'abriu_form', { posicao: pos });
    if (window.dataLayer) window.dataLayer.push({ event: 'abriu_form', posicao: pos });
  }

  function fechar() {
    if (!modal) return;
    modal.classList.remove('aberto');
    modal.setAttribute('aria-hidden', 'true');
    document.body.classList.remove('travado');
    if (ultimoFoco) ultimoFoco.focus();
  }

  document.querySelectorAll('[data-cta]').forEach(function (el) {
    el.addEventListener('click', function (e) {
      e.preventDefault();
      abrir(el.getAttribute('data-cta') || 'desconhecido');
    });
  });

  if (modal) {
    modal.querySelectorAll('[data-fechar]').forEach(function (el) {
      el.addEventListener('click', fechar);
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && modal.classList.contains('aberto')) fechar();
    });
  }

  /* ---- 2. Form do CRM XPN (FormEmbed) ----
     Mesmo contrato usado em lp2 / lp2-d / fap01:
     - repassa UTMs + gclid/fbclid + url da LP e referrer pro iframe
     - ajusta altura via postMessage 'np-form-height' / 'crm-form-height'
     - obedece redirect pós-envio via 'crm-form-redirect'

     O src fica em data-src e só é aplicado quando o modal abre. Se o iframe
     carregar escondido ele se mede como 0px de altura, manda height:0 e nunca
     mais remede — o form ficava espremido com scroll interno.                */
  var form = document.getElementById('nf-crm-wb-cadastro');

  function carregarForm() {
    if (!form || form.getAttribute('src')) return;   // já carregado
    var base = form.getAttribute('data-src');
    if (!base) return;

    var par = new URLSearchParams(window.location.search);
    var chaves = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term',
                  'gclid', 'fbclid', '_gl', 'ttclid', 'msclkid', 'li_fat_id'];
    var q = [];
    chaves.forEach(function (k) {
      var v = par.get(k);
      if (v) q.push(k + '=' + encodeURIComponent(v));
    });
    q.push('_lp=' + encodeURIComponent(window.location.href));
    q.push('_ref=' + encodeURIComponent(document.referrer || ''));
    q.push('_t=' + Date.now());

    form.src = base + (base.indexOf('?') > -1 ? '&' : '?') + q.join('&');
  }

  if (form) {
    window.addEventListener('message', function (e) {
      if (!e.data) return;
      if (e.data.type === 'np-form-height' || e.data.type === 'crm-form-height') {
        var h = parseInt(e.data.height, 10);
        if (h > 0) form.style.height = h + 'px';     // ignora o 0 do estado escondido
      }
      if (e.data.type === 'crm-form-redirect' &&
          typeof e.data.url === 'string' && e.data.url.indexOf('https://') === 0) {
        window.location.href = e.data.url;
      }
    });
  }

  /* ---- 3. Contagem regressiva ---- */
  var alvo = CFG.DATA_EVENTO ? new Date(CFG.DATA_EVENTO).getTime() : null;
  var box = document.querySelector('[data-contagem]');
  if (alvo && box) {
    var campos = {
      d: box.querySelector('[data-d]'),
      h: box.querySelector('[data-h]'),
      m: box.querySelector('[data-m]'),
      s: box.querySelector('[data-s]')
    };
    var pad = function (n) { return String(n).padStart(2, '0'); };
    var tick = function () {
      var falta = alvo - Date.now();
      if (falta <= 0) {
        box.innerHTML = '<div style="min-width:auto;padding:16px 24px"><b style="font-size:1.1rem">AO VIVO AGORA</b></div>';
        return;
      }
      var s = Math.floor(falta / 1000);
      campos.d.textContent = pad(Math.floor(s / 86400));
      campos.h.textContent = pad(Math.floor(s % 86400 / 3600));
      campos.m.textContent = pad(Math.floor(s % 3600 / 60));
      campos.s.textContent = pad(s % 60);
    };
    tick();
    setInterval(tick, 1000);
  }

  /* ---- 4. Reveal on scroll ---- */
  var alvos = document.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window && alvos.length) {
    var io = new IntersectionObserver(function (ents) {
      ents.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add('on'); io.unobserve(e.target); }
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
    alvos.forEach(function (el) { io.observe(el); });
  } else {
    alvos.forEach(function (el) { el.classList.add('on'); });
  }

  /* ---- 5. Barra fixa só aparece depois do hero ---- */
  var fixa = document.querySelector('.fixa');
  var hero = document.querySelector('.hero');
  if (fixa && hero && 'IntersectionObserver' in window) {
    fixa.style.transform = 'translateY(110%)';
    fixa.style.transition = 'transform .3s ease';
    new IntersectionObserver(function (ents) {
      fixa.style.transform = ents[0].isIntersecting ? 'translateY(110%)' : 'translateY(0)';
    }, { threshold: 0 }).observe(hero);
  }
})();
