/* CRM AI-First: anonymous analytics. No form values, IPs or full query strings collected. */
(function () {
  'use strict';
  var script = document.currentScript;
  if (!script || window.CRMTracking) return;
  var key = script.dataset.key, page = script.dataset.page, endpoint = script.dataset.endpoint;
  var crmOrigin = new URL(script.src).origin;
  var disabled = navigator.doNotTrack === '1' || navigator.globalPrivacyControl === true;
  if(disabled){window.CRMTracking={ready:Promise.resolve(false),attach:function(data){return data;},track:function(){return Promise.resolve(false);}};return;}
  var session, visitor, record, now = Date.now();
  try {
    visitor = localStorage.getItem('crm_visitor') || crypto.randomUUID();
    localStorage.setItem('crm_visitor', visitor);
    record = JSON.parse(sessionStorage.getItem('crm_session_' + page) || 'null');
  } catch (_) {}
  visitor = visitor || crypto.randomUUID();
  session = record && now - record.time < 30 * 60 * 1000 ? record.id : crypto.randomUUID();
  try { sessionStorage.setItem('crm_session_' + page, JSON.stringify({id:session,time:now})); } catch (_) {}
  var params = new URLSearchParams(location.search);
  function collect(type, label) {
    if (disabled) return Promise.resolve(false);
    var body = {key:key, session:session, visitor:visitor, event:crypto.randomUUID(), type:type, label:label,
      path:location.pathname, source:params.get('utm_source'), medium:params.get('utm_medium'), campaign:params.get('utm_campaign'), referrer:document.referrer};
    return fetch(endpoint, {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),keepalive:true,credentials:'omit'})
      .then(function(r){return r.ok;}).catch(function(){return false;});
  }
  var ready = collect('pageview');
  var active = false;
  ready.then(function(ok){active=ok;});
  window.CRMTracking = {
    ready:ready,
    attach:function(data){return active ? Object.assign({},data,{_crm_tracking:{page_id:page,session_id:session}}) : data;},
    track:function(label){return collect('click',String(label||'Botão').slice(0,100));}
  };
  function decorate() {
    if (!active) return;
    document.querySelectorAll('iframe[src],a[href]').forEach(function(el){
      var attr=el.tagName==='IFRAME'?'src':'href';
      try {
        var u=new URL(el.getAttribute(attr),location.href);
        if(u.origin!==crmOrigin || !/^\/form\/[0-9a-f-]+$/.test(u.pathname))return;
        if(u.searchParams.get('crm_session')===session)return;
        u.searchParams.set('crm_page',page);u.searchParams.set('crm_session',session);
        ['utm_source','utm_medium','utm_campaign'].forEach(function(k){if(params.get(k))u.searchParams.set(k,params.get(k));});
        el.setAttribute(attr,u.href);
      } catch(_) {}
    });
  }
  function init(){ready.then(decorate);document.addEventListener('click',function(e){var el=e.target.closest&&e.target.closest('[data-crm-track]');if(el)collect('click',el.getAttribute('data-crm-track'));},true);
    new MutationObserver(decorate).observe(document.documentElement,{childList:true,subtree:true});}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();
