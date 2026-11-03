import {readFileSync} from 'node:fs';
import {beforeEach,afterEach,describe,it,expect,vi} from 'vitest';
const code=readFileSync('public/crm-tracker.js','utf8');
describe('landing page tracker',()=>{
 beforeEach(()=>{
  delete (window as any).CRMTracking;localStorage.clear();sessionStorage.clear();
  const s=document.createElement('script');s.src='https://crm.example/crm-tracker.js';s.dataset.key='key';s.dataset.page='page';s.dataset.endpoint='https://backend.example/web-track';
  Object.defineProperty(document,'currentScript',{configurable:true,value:s});
  Object.defineProperty(navigator,'doNotTrack',{configurable:true,value:'0'});
  vi.stubGlobal('fetch',vi.fn().mockResolvedValue({ok:true}));
 });
 afterEach(()=>vi.unstubAllGlobals());
 it('only attaches a session after the visit is accepted and preserves form data',async()=>{
  new Function(code)();const api=(window as any).CRMTracking;
  const payload={nome:'Teste',email:'test@example.invalid'};
  expect(api.attach(payload)).toEqual(payload);
  await api.ready;
  expect(api.attach(payload)).toMatchObject({...payload,_crm_tracking:{page_id:'page'}});
  expect((payload as any)._crm_tracking).toBeUndefined();
  const sent=JSON.parse((fetch as any).mock.calls[0][1].body);
  expect(sent.type).toBe('pageview');expect(sent.email).toBeUndefined();expect(sent.path).not.toContain('?');
 });
 it('respects Do Not Track without identifiers or network calls',async()=>{
  Object.defineProperty(navigator,'doNotTrack',{configurable:true,value:'1'});
  new Function(code)();await (window as any).CRMTracking.ready;
  expect(fetch).not.toHaveBeenCalled();expect(localStorage.length).toBe(0);
 });
});
