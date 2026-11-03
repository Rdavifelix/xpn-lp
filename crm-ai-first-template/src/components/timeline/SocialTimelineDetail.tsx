import {Dialog,DialogContent,DialogHeader,DialogTitle,DialogDescription} from '@/components/ui/dialog';
function safeUrl(value:unknown){try{const u=new URL(String(value));return u.protocol==='https:'?u.href:undefined;}catch{return undefined;}}
export function SocialTimelineDetail({event,onClose}:{event:any;onClose:()=>void}){
 const m=event?.metadata,profile=m?.social_profile,post=m?.post,page=m?.page_activity;
 const link=safeUrl(page?m.page_url:profile?`https://www.instagram.com/${encodeURIComponent(m.username)}/`:post?.permalink||m?.reference_url);
 const photo=safeUrl(profile?m?.profile_picture_url_hd:post?.thumbnail_url);
 return <Dialog open={!!event} onOpenChange={open=>{if(!open)onClose();}}><DialogContent className="max-w-lg max-h-[85vh] overflow-y-auto"><DialogHeader><DialogTitle>{profile?'Perfil do Instagram':event?.title}</DialogTitle><DialogDescription>{profile?`@${m?.username}`:event?.details}</DialogDescription></DialogHeader>
 {photo&&<img src={photo} alt={profile?'Foto do perfil':'Publicação'} className={profile?'w-20 h-20 rounded-full object-cover':'max-h-72 w-full object-contain rounded-xl'} onError={e=>{e.currentTarget.style.display='none';}}/>}
 {page?<><p className="text-sm">{m.page_url}</p><p className="text-sm text-muted-foreground">{[m.label,m.source,m.medium,m.campaign].filter(Boolean).join(' · ')||'Visita direta'}</p></>:profile?<><p className="font-medium">{m?.full_name}</p><p className="whitespace-pre-wrap text-sm">{m?.biography||'Bio não disponível'}</p><p className="text-sm text-muted-foreground">{m?.follower_count?.toLocaleString('pt-BR')} seguidores · {m?.media_count} publicações</p></>:<><blockquote className="rounded-lg bg-muted p-4 whitespace-pre-wrap">{event?.description}</blockquote>{post?.content&&<p className="whitespace-pre-wrap text-sm text-muted-foreground">{post.content}</p>}{!post&&<p className="text-sm text-muted-foreground">Os detalhes desta publicação ainda não estão disponíveis. O comentário foi preservado.</p>}</>}
 {link&&<a href={link} target="_blank" rel="noopener noreferrer" className="text-sm font-medium underline">{page?"Abrir página ↗":"Abrir no Instagram ↗"}</a>}
 </DialogContent></Dialog>;
}
