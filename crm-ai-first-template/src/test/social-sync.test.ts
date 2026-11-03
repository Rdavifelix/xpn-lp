import {describe,it,expect,vi,beforeEach} from 'vitest';
import {syncSocialMetrics} from '../../supabase/functions/sync-social-zernio/worker';
import {ensureReceiving} from '../../supabase/functions/zernio-api/receiving';
import {provider} from '../../supabase/functions/zernio-api/provider';
vi.mock('../../supabase/functions/zernio-api/provider',()=>({provider:vi.fn()}));
const request=vi.mocked(provider);
function database(rows:Record<string,any>){
 const writes:any[]=[];
 return {writes,from:vi.fn((table:string)=>{
  let write:any;
  const q:any={};
  for(const method of ['eq','or','select','maybeSingle','single'])q[method]=vi.fn(()=>q);
  for(const method of ['upsert','update'])q[method]=vi.fn((value:any)=>{write=value;writes.push({table,value});return q;});
  q.then=(resolve:any)=>Promise.resolve({data:rows[table],error:null}).then(resolve);
  return q;
 })};
}
beforeEach(()=>{request.mockReset();});
describe('social setup and reporting',()=>{
 it('saves post analytics even when daily analytics are unavailable',async()=>{
  const db=database({zernio_accounts:[{id:'account',platform:'instagram',name:'Instagram'}],zernio_connections:{api_key:'test'},social_accounts:{id:'local'}});
  request.mockImplementation(async(_key,path)=>{
   if(path==='/accounts')return {accounts:[]};
   if(path.startsWith('/analytics/daily'))throw new Error('Unavailable');
   return {posts:[{_id:'post',platform:'instagram',mediaType:'image',analytics:{views:8,comments:6}}]};
  });
  const result=await syncSocialMetrics(db,'tenant');
  expect(result.posts).toBe(1);expect(result.dias).toBe(0);expect(result.warnings).toHaveLength(1);
  expect(db.writes.find(w=>w.table==='social_posts').value[0]).toMatchObject({tenant_id:'tenant',views:8,comments:6});
 });
 it('does not provision an already configured receiver',async()=>{
  expect(await ensureReceiving(database({}),'tenant',{webhook_id:'id',webhook_status:'configured'},'https://crm.test')).toEqual({receiving_ready:true});
  expect(request).not.toHaveBeenCalled();
 });
 it('repairs an existing receiver instead of creating a duplicate',async()=>{
  const db=database({zernio_connections:{tenant_id:'tenant'}});
  request.mockResolvedValueOnce({webhooks:[{_id:'existing',url:'https://crm.test/functions/v1/zernio-webhook?connection=token'}]}).mockResolvedValueOnce({webhook:{_id:'existing'}});
  expect(await ensureReceiving(db,'tenant',{key_hash:'hash',api_key:'test',webhook_token:'token',webhook_secret:'secret'},'https://crm.test')).toEqual({receiving_ready:true});
  expect(request.mock.calls[1][1]).toBe('/webhooks/settings');expect(request.mock.calls[1][2]).toBe('PUT');expect(request.mock.calls[1][3]).toMatchObject({_id:'existing',isActive:true});
 });
 it('does not claim readiness when registration fails',async()=>{
  const db=database({zernio_connections:{tenant_id:'tenant'}});request.mockRejectedValue(new Error('Unavailable'));
  expect((await ensureReceiving(db,'tenant',{key_hash:'hash'},'https://crm.test')).receiving_ready).toBe(false);
  expect(db.writes.at(-1).value.webhook_status).toBe('failed');
 });
});
