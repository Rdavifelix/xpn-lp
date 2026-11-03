import {renderHook,act} from '@testing-library/react';
import {expect,it,vi} from 'vitest';
import {useSocialInboxRealtime} from './useSocialInboxRealtime';
const mocks=vi.hoisted(()=>({invalidateQueries:vi.fn(),removeChannel:vi.fn(),events:[] as Array<(...args:unknown[])=>unknown>,status:null as null|((s:string)=>void)}));
vi.mock('@/contexts/AuthContext',()=>({useAuth:()=>({tenantId:'tenant'})}));
vi.mock('@tanstack/react-query',()=>({useQueryClient:()=>mocks}));
vi.mock('@/lib/supabase',()=>({supabase:{removeChannel:mocks.removeChannel,channel:()=>{
 const channel={on:(_event:any,_filter:any,callback:(...args:unknown[])=>unknown)=>{mocks.events.push(callback);return channel;},subscribe:(callback:any)=>{mocks.status=callback;return channel;}};return channel;
}}}));
it('refreshes messages on push and reconnect, and cleans up when leaving',()=>{
 const view=renderHook(()=>useSocialInboxRealtime('account'));
 act(()=>mocks.status?.('SUBSCRIBED'));
 expect(view.result.current).toBe(true);
 mocks.invalidateQueries.mockClear();
 act(()=>mocks.events[1]());
 expect(mocks.invalidateQueries).toHaveBeenCalledWith({queryKey:['instagram-messages']});
 expect(mocks.invalidateQueries).toHaveBeenCalledWith({queryKey:['zernio-conversations','account']});
 act(()=>mocks.status?.('CHANNEL_ERROR'));
 expect(view.result.current).toBe(false);
 mocks.invalidateQueries.mockClear();
 act(()=>mocks.status?.('SUBSCRIBED'));
 expect(mocks.invalidateQueries).toHaveBeenCalled();
 view.unmount();expect(mocks.removeChannel).toHaveBeenCalled();
 mocks.invalidateQueries.mockClear();act(()=>mocks.events[1]());expect(mocks.invalidateQueries).not.toHaveBeenCalled();
});
