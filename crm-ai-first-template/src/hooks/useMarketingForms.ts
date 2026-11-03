import {useQuery,useMutation,useQueryClient} from '@tanstack/react-query';
import {supabase} from '@/lib/supabase';
import {useAuth} from '@/contexts/AuthContext';
import type {MarketingForm} from '@/types/marketing-form.types';
export async function formsAdmin(action:string,id?:string,data:unknown={},revision?:number){
 const {data:result,error}=await (supabase as any).rpc('forms_admin',{p_action:action,p_id:id??null,p_data:data,p_revision:revision??null});
 if(error)throw error;return result;
}
export function useMarketingForms(){const {tenantId}=useAuth();return useQuery({queryKey:['marketing-forms',tenantId],enabled:!!tenantId,queryFn:async()=>{let items:MarketingForm[]=[];let offset=0;do{const {data,error}=await (supabase as any).rpc('forms_admin',{p_action:'list',p_limit:100,p_offset:offset});if(error)throw error;items=items.concat(data.items);offset=data.next_offset;}while(offset!==null);return items;}});}
export function useMarketingForm(id:string|undefined){const {tenantId}=useAuth();return useQuery({queryKey:['marketing-form',id,tenantId],enabled:!!id&&!!tenantId,queryFn:()=>formsAdmin('get',id)});}
function useFormWrite(fn:(arg:any)=>Promise<any>){const qc=useQueryClient();return useMutation({mutationFn:fn,onSuccess:()=>{qc.invalidateQueries({queryKey:['marketing-forms']});qc.invalidateQueries({queryKey:['marketing-form']});}});}
export function useCreateMarketingForm(){return useFormWrite(({publish,...data})=>formsAdmin(publish?'save_publish':'save',undefined,data));}
export function useUpdateMarketingForm(){return useFormWrite(({id,revision,publish,...data})=>formsAdmin(publish?'save_publish':'save',id,data,revision));}
export function useToggleMarketingForm(){return useFormWrite(async({id,is_active})=>{const form=await formsAdmin('get',id);return formsAdmin(is_active?'publish':'unpublish',id,{},form.revision);});}
export function useDeleteMarketingForm(){return useFormWrite(async(id:string)=>{const form=await formsAdmin('get',id);return formsAdmin('unpublish',id,{},form.revision);});}
export function useFormLeads(id:string|null){const {tenantId}=useAuth();return useQuery({queryKey:['form-leads',id,tenantId],enabled:!!id&&!!tenantId,queryFn:async()=>{const result=await formsAdmin('submissions',id!);return result.items.map((s:any)=>({id:s.id,lead_id:s.lead_id,deal_id:s.deal_id,answers:s.answers,lead_name:s.lead_name,lead_email:s.lead_email,lead_phone:s.lead_phone,status:'success',created_at:s.created_at,raw_payload:{...s.payload.values,...s.payload.tracking}}));}});}
export async function fetchPublicForm(id:string):Promise<MarketingForm|null>{const r=await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/public-form?id=${encodeURIComponent(id)}`);if(!r.ok)return null;return r.json();}
