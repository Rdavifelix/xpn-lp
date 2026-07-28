/* =========================================================
   AGENDA CHEIA — JS compartilhado
   Configure a data do evento no <head> de cada página:
   <script>window.CFG={DATA_EVENTO:'2026-08-03T20:00:00-03:00'}</script>

   Os CTAs abrem o modal com o formulário GoHighLevel
   (WB - FORMS 01 — cdnlLxhpSqdNtSERwREy), o mesmo da /revolucao.
   ========================================================= */
(function () {
  var CFG = window.CFG || {};

  /* ---- 1. Modal de inscrição ---- */
  var modal = document.querySelector('.modal');
  var ultimoFoco = null;

  function abrir(pos) {
    if (!modal) return;
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

  /* ---- 2. Contagem regressiva ---- */
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

  /* ---- 3. Reveal on scroll ---- */
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

  /* ---- 4. Barra fixa só aparece depois do hero ---- */
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
