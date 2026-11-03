import {supabase} from '@/lib/supabase';
export async function zernio(action:string,args:Record<string,unknown>={}){
 const {data,error}=await supabase.functions.invoke('social-api',{body:{action,...args}});
 if(error){const detail=await error.context?.json?.().catch(()=>null);throw new Error(detail?.error||error.message);}
 if(data?.error)throw new Error(data.error);return data;
}
