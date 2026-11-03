import {render,screen} from '@testing-library/react';
import {expect,it,vi} from 'vitest';
import {LeadInstagramChat} from './LeadInstagramChat';
vi.mock('@/hooks/useInstagram',()=>({useLeadInstagramConversation:()=>({data:undefined,isLoading:false}),useLinkConversationToLead:()=>({mutate:vi.fn()}),useSendInstagramDMToUsername:()=>({})}));
vi.mock('./InstagramChat',()=>({InstagramChat:()=>null}));
it('does not crash before a conversation exists',()=>{
 const view=render(<LeadInstagramChat leadId="lead"/>);
 expect(screen.getByText('Nenhuma conversa no Instagram ainda')).toBeTruthy();view.unmount();
});
