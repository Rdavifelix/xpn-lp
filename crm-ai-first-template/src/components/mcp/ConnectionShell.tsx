import type { ReactNode } from 'react';
import { ArrowUpRight, Bot, Check, GitBranch, ShieldCheck, Sparkles } from 'lucide-react';
import { Link } from 'react-router-dom';

export const flowInput = 'h-12 rounded-xl border-white/15 bg-white/5 text-white placeholder:text-slate-500 focus-visible:ring-amber-400';
export const flowButton = 'h-12 w-full rounded-xl bg-amber-400 text-slate-950 hover:bg-amber-300 font-semibold';
export const flowSecondary = 'h-12 rounded-xl border-white/15 bg-transparent text-slate-300 hover:bg-white/10 hover:text-white';

export default function ConnectionShell({ step, title, description, children }: { step: number; title: string; description: string; children: ReactNode }) {
  return <main className="dark min-h-screen bg-[#090d16] text-slate-100 selection:bg-amber-400/30">
    <div className="mx-auto max-w-6xl px-5 py-7 sm:px-10">
      <header className="flex items-center justify-between border-b border-white/10 pb-6">
        <Link to="/" className="flex items-center gap-3 font-semibold tracking-tight"><span className="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-400 text-slate-950"><Sparkles size={21} /></span><span>CRM <span className="text-amber-400">AI FIRST</span></span></Link>
        <span className="flex items-center gap-2 text-xs text-slate-400"><ShieldCheck size={15} /> Conexão segura</span>
      </header>
      <div className="grid items-center gap-10 py-10 lg:min-h-[76vh] lg:grid-cols-[1fr_1.05fr] lg:gap-20 lg:py-16">
        <section className="space-y-6">
          <p className="text-xs font-semibold uppercase tracking-[.2em] text-amber-400">Sua operação. Sua inteligência.</p>
          <h1 className="max-w-lg text-4xl font-semibold leading-[1.12] tracking-tight sm:text-5xl">Da conversa<br />ao processo.<br /><span className="text-slate-500">Tudo conectado.</span></h1>
          <p className="max-w-sm text-sm leading-7 text-slate-400">Conecte sua IA ao CRM e transforme o conhecimento sobre sua empresa em funis, etapas e agentes.</p>
          <div className="hidden max-w-sm space-y-3 pt-4 lg:block">
            {[{ icon:GitBranch, title:'Um processo que faz sentido', text:'Funis e etapas construídos a partir da sua operação.' },{ icon:Bot, title:'Agentes com uma missão clara', text:'Rascunhos preparados para você revisar e configurar.' }].map(({icon:Icon,title,text})=><div key={title} className="flex gap-4 rounded-2xl border border-white/[.07] bg-white/[.025] p-4"><Icon className="mt-1 shrink-0 text-amber-400" size={20}/><div><p className="text-sm font-medium">{title}</p><p className="mt-1 text-xs leading-5 text-slate-500">{text}</p></div></div>)}
          </div>
        </section>
        <section className="rounded-3xl border border-white/10 bg-[#111722] p-6 shadow-2xl shadow-black/30 sm:p-9">
          <ol aria-label="Etapas da conexão" className="mb-9 flex gap-2">
            {['Sua conta','Sua empresa','Conexão'].map((label,i)=><li key={label} aria-current={step===i+1?'step':undefined} className="flex flex-1 flex-col gap-2"><span className={`h-1 rounded-full ${step>=i+1?'bg-amber-400':'bg-white/10'}`} /><span className={`flex items-center gap-1 text-[11px] ${step===i+1?'text-amber-400':'text-slate-500'}`}>{step>i+1?<Check size={12}/>:`${i+1}.`} {label}</span></li>)}
          </ol>
          <h2 className="text-2xl font-semibold tracking-tight">{title}</h2>
          <p className="mb-7 mt-2 text-sm leading-6 text-slate-400">{description}</p>
          <div className="space-y-5">{children}</div>
        </section>
      </div>
      <footer className="flex flex-wrap justify-between gap-3 border-t border-white/10 py-5 text-xs text-slate-500"><span>Cada empresa tem seu próprio ambiente.</span><Link to="/conectar-ia" className="flex items-center gap-1 hover:text-amber-400">Conectar minha IA <ArrowUpRight size={13}/></Link></footer>
    </div>
  </main>;
}
