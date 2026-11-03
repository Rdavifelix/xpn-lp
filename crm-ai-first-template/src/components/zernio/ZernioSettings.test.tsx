import {render,screen,fireEvent,waitFor} from '@testing-library/react';
import {MemoryRouter} from 'react-router-dom';
import {describe,it,expect,vi} from 'vitest';
import {ZernioSettings} from './ZernioSettings';
import {zernio} from './api';
vi.mock('@/contexts/AuthContext',()=>({useAuth:()=>({tenantId:'tenant-test'})}));
vi.mock('@/lib/supabase',()=>({supabase:{channel:()=>({on:()=>({subscribe:()=>({})})}),removeChannel:vi.fn()}}));
vi.mock('./api',()=>({zernio:vi.fn()}));
vi.mock('./MetaConnection',()=>({MetaConnection:()=>null}));
const fixture=vi.hoisted(()=>({accounts:[] as any[]}));
const queryClient=vi.hoisted(()=>({invalidateQueries:vi.fn()}));
vi.mock('@tanstack/react-query',()=>({
 useQueryClient:()=>queryClient,
 useQuery:({queryKey}:any)=>({data:queryKey[0]==='zernio-status'?{configured:true,platforms:[{id:'instagram',name:'Instagram',group:'social'}]}:queryKey[0]==='zernio-profiles'?{profiles:[{_id:'profile',name:'Empresa'}]}:queryKey[0]==='zernio-options'?{}:queryKey[0]==='zernio-accounts'?fixture.accounts:[]}),
}));
describe('Autorização Zernio',()=>{
 it('mostra a autorização em uma janela visível após selecionar a rede',async()=>{
  vi.mocked(zernio).mockImplementation(async action=>action==='sync'?{synced:1}:{authUrl:'https://www.instagram.com/oauth/authorize'});
  const view=render(<MemoryRouter><ZernioSettings/></MemoryRouter>);
  await waitFor(()=>expect((screen.getByLabelText('Perfil das contas') as HTMLSelectElement).value).toBe('profile'));
  fireEvent.click(screen.getByRole('button',{name:'Conectar Instagram'}));
  expect(screen.getByRole('dialog',{name:'Conectar Instagram'})).toBeTruthy();
  await waitFor(()=>expect(screen.getByRole('link',{name:'Autorizar Instagram'}).getAttribute('href')).toBe('https://www.instagram.com/oauth/authorize'));
  expect(zernio).toHaveBeenCalledWith('sync');
  await waitFor(()=>expect(screen.getByText('Contas atualizadas · recebimento automático pronto.')).toBeTruthy());
  view.unmount();
 });
 it('mostra falha explícita quando o provedor não entrega a próxima ação',async()=>{
  vi.mocked(zernio).mockImplementation(async action=>action==='sync'?{synced:0}:{});
  const view=render(<MemoryRouter><ZernioSettings/></MemoryRouter>);
  await waitFor(()=>expect((screen.getByLabelText('Perfil das contas') as HTMLSelectElement).value).toBe('profile'));
  fireEvent.click(screen.getByRole('button',{name:'Conectar Instagram'}));
  await waitFor(()=>expect(screen.getByRole('alert').textContent).toContain('Não recebemos o link'));
  view.unmount();
 });
 it('mostra a conta conectada no card da rede',async()=>{
  fixture.accounts=[{id:'ig-1',platform:'instagram',username:'frank.costa2026',name:'Frank Costa',is_active:true}];
  vi.mocked(zernio).mockResolvedValue({synced:1});
  const view=render(<MemoryRouter><ZernioSettings/></MemoryRouter>);
  expect(screen.getByText('Conectado')).toBeTruthy();
  expect(screen.getByRole('link',{name:'@frank.costa2026'}).getAttribute('href')).toContain('account=ig-1');
  expect(screen.queryByRole('button',{name:'Conectar Instagram'})).toBeNull();
  expect(screen.getByRole('button',{name:'Adicionar outra conta'})).toBeTruthy();
  await waitFor(()=>expect(screen.getByText('Contas atualizadas · recebimento automático pronto.')).toBeTruthy());
  view.unmount();fixture.accounts=[];
 });

});
