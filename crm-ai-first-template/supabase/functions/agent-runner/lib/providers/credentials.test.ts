import {callOpenAI} from './openai.ts';
import {callAnthropic} from './anthropic.ts';
Deno.test('API adapters use supplied credential and reject missing credentials',async()=>{
 const original=globalThis.fetch;
 let expected='';let calls=0;
 globalThis.fetch=async(_url,init)=>{
  const h=new Headers(init?.headers);if((h.get('authorization')??h.get('x-api-key'))!==expected)throw new Error('Wrong key');
  calls++;return new Response('data: [DONE]\n\n',{status:200});
 };
 try{
  const base:any={agent:{model:'test',settings:{max_tokens:256}},systemPrompt:'test',tools:[],history:[],newUserMessage:'hello',onTextDelta:()=>{}};
  expected='Bearer own-key';await callOpenAI({...base,credential:{auth_data:{api_key:'own-key'}}});
  expected='sponsored-key';await callAnthropic({...base,credential:{auth_data:{api_key:'sponsored-key'}}});
  for(const fn of [callOpenAI,callAnthropic]){
   let rejected=false;try{await fn(base);}catch{rejected=true;}if(!rejected)throw new Error('Missing key used global fallback');
  }
  if(calls!==2)throw new Error('Unexpected external call');
 }finally{globalThis.fetch=original;}
});
