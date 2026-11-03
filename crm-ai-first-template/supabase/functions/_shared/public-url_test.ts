import {crmPublicUrl} from './public-url.ts';
Deno.test('public origin must be configured and cannot redirect to arbitrary paths',()=>{
 const previous=Deno.env.get('CRM_PUBLIC_URL');
 try {
  for(const value of ['', 'http://crm.test','https://user:pass@crm.test','https://crm.test/other','https://crm.test/?x=1']){
   Deno.env.set('CRM_PUBLIC_URL',value);let rejected=false;try{crmPublicUrl();}catch{rejected=true;}if(!rejected)throw new Error('Unsafe origin accepted');
  }
  Deno.env.set('CRM_PUBLIC_URL','https://crm.test/');if(crmPublicUrl()!=='https://crm.test')throw new Error('Origin mismatch');
 }finally{if(previous===undefined)Deno.env.delete('CRM_PUBLIC_URL');else Deno.env.set('CRM_PUBLIC_URL',previous);}
});
