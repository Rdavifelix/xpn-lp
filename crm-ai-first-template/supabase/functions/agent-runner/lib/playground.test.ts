import {parsePlayground,matchesPlayground} from './playground.ts';
const lead='11111111-1111-4111-8111-111111111111';const deal='22222222-2222-4222-8222-222222222222';
Deno.test('playground: seleção estrita e sessão vinculada',()=>{
 const x=parsePlayground({lead_id:lead,deal_id:deal});
 if(!matchesPlayground(x,x))throw Error('sessão deveria corresponder');
 if(matchesPlayground(x,{lead_id:deal,deal_id:deal})||matchesPlayground(x,null)||matchesPlayground(null,x))throw Error('sessão cruzada permitida');
 for(const bad of [{lead_id:'texto'},{lead_id:lead,tenant_id:deal},{lead_id:lead,deal_id:'errado'}]){
  let rejected=false;try{parsePlayground(bad);}catch{rejected=true;}if(!rejected)throw Error('seleção inválida aceita');
 }
});
