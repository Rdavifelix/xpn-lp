import {render,screen} from '@testing-library/react';
import {describe,it,expect} from 'vitest';
import {SocialTimelineDetail} from './SocialTimelineDetail';
describe('Instagram timeline',()=>{
 it('preserves the comment when the post is unavailable and blocks unsafe links',()=>{
 render(<SocialTimelineDetail event={{title:'Comentou no Instagram',description:'Quero participar',metadata:{social_comment:true,reference_url:'javascript:alert(1)'}}} onClose={()=>{}}/>);
 expect(screen.getByText('Quero participar')).toBeTruthy();
 expect(screen.getByText(/Os detalhes desta publicação/)).toBeTruthy();
 expect(screen.queryByRole('link')).toBeNull();
 });
});
